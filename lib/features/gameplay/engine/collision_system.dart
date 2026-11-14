import 'dart:math' as math;

import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/angle_utils.dart';
import '../domain/level_config.dart';

enum CollisionKind { safe, gap, danger, breakable, bonus }

class CollisionResult {
  CollisionResult();

  CollisionKind kind = CollisionKind.safe;
  int slot = 0;

  /// Angular distance (rad) from the ball to the nearest live hazard edge on this floor (∞ if none).
  double hazardDistance = double.infinity;

  /// Hazard source when [kind] is danger: 'danger' | 'blink' | 'sweeper'.
  String cause = '';
}

/// Mutable per-floor runtime state (destroyed segments, collected bonuses).
class FloorState {
  FloorState() : destroyed = List<bool>.filled(GameConstants.slotsPerFloor, false);

  final List<bool> destroyed;
  final Set<int> collectedBonus = {};
  bool broken = false;
}

/// Logical (not mesh-based) collision for circular floors. Pure and deterministic.
///
/// The tower is a rigid body rotated by `towerAngle`; the ball sits at a fixed world angle. The slot under the
/// ball is found in floor-local space: `local = wrap(ballWorldAngle − towerAngle − floor.offset)`; a boundary
/// angle belongs to the higher slot (floor()).
class CollisionSystem {
  final CollisionResult _result = CollisionResult();

  static double localAngle(double towerAngle, FloorSpec floor) =>
      AngleUtils.wrap(GameConstants.ballWorldAngle - towerAngle - floor.offset);

  static int slotIndex(double local) =>
      (local / GameConstants.slotAngle).floor().clamp(0, GameConstants.slotsPerFloor - 1);

  /// Effective type of slot [s] at [time] considering destruction and collection.
  static SegmentType effectiveType(FloorSpec floor, FloorState state, int s) {
    if (state.destroyed[s]) return SegmentType.gap;
    final t = floor.slots[s];
    if (t == SegmentType.bonus && state.collectedBonus.contains(s)) return SegmentType.safe;
    return t;
  }

  /// Resolves what the ball touches on [floor] given the tower angle and the simulation time.
  /// The returned object is reused; copy fields you need to keep.
  CollisionResult resolve(FloorSpec floor, FloorState state, double towerAngle, double time) {
    final r = _result;
    final local = localAngle(towerAngle, floor);
    final s = slotIndex(local);
    r.slot = s;
    r.cause = '';
    final blinkOn = floor.blink?.isDangerAt(time) ?? false;
    final type = effectiveType(floor, state, s);
    switch (type) {
      case SegmentType.gap:
        r.kind = CollisionKind.gap;
      case SegmentType.danger:
        r.kind = CollisionKind.danger;
        r.cause = 'danger';
      case SegmentType.blink:
        r.kind = blinkOn ? CollisionKind.danger : CollisionKind.safe;
        if (blinkOn) r.cause = 'blink';
      case SegmentType.breakable:
        r.kind = CollisionKind.breakable;
      case SegmentType.bonus:
        r.kind = CollisionKind.bonus;
      case SegmentType.safe:
        r.kind = CollisionKind.safe;
    }

    // nearest hazard edge (for near-miss scoring)
    var nearest = double.infinity;
    const d = GameConstants.slotAngle;
    for (var k = 0; k < floor.slots.length; k++) {
      final tk = effectiveType(floor, state, k);
      final lethal = tk == SegmentType.danger || (tk == SegmentType.blink && blinkOn);
      if (!lethal) continue;
      final a0 = k * d, a1 = a0 + d;
      if (AngleUtils.inArc(local, a0, d)) {
        nearest = 0;
        break;
      }
      nearest = math.min(nearest, math.min(AngleUtils.delta(local, a0).abs(), AngleUtils.delta(local, a1).abs()));
    }

    final sw = floor.sweeper;
    if (sw != null) {
      final start = sw.angleAt(time);
      if (AngleUtils.inArc(local, start, sw.width)) {
        nearest = 0;
        if (r.kind != CollisionKind.gap) {
          r.kind = CollisionKind.danger;
          r.cause = 'sweeper';
        }
      } else {
        nearest = math.min(
          nearest,
          math.min(AngleUtils.delta(local, start).abs(), AngleUtils.delta(local, start + sw.width).abs()),
        );
      }
    }
    r.hazardDistance = nearest;
    return r;
  }
}
