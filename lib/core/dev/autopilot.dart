import 'dart:math' as math;

import 'package:flutter/foundation.dart';

import '../../features/gameplay/engine/collision_system.dart';
import '../../features/gameplay/engine/game_engine.dart';
import '../../features/gameplay/engine/simulation.dart';
import '../constants/game_constants.dart';
import '../enums/game_enums.dart';
import '../utils/angle_utils.dart';

/// QA-only bot, enabled with `--dart-define=SP_AUTOPILOT=true`. Drives the real input path (no state
/// shortcuts) so device runs can exercise gameplay and log performance without touch automation.
abstract final class Autopilot {
  static const bool enabled = bool.fromEnvironment('SP_AUTOPILOT');

  /// QA: open this route right after Home (e.g. `/shop`). Empty = stay on Home.
  static const String startRoute = String.fromEnvironment('SP_START_ROUTE');

  /// QA: force the control mode (`spin` | `smash`). Empty = use the saved setting.
  static const String forceMode = String.fromEnvironment('SP_MODE');

  /// Optional deliberate miss rate to exercise the game-over path.
  static const double sloppiness = 0.0;

  static double _logTimer = 0;

  /// Called once per engine frame.
  static void drive(GameEngine engine, double dt) {
    if (!enabled) return;
    final sim = engine.sim;
    _logTimer += dt;
    if (_logTimer > 4) {
      _logTimer = 0;
      debugPrint('[PERF] level=${engine.level.levelId} phase=${engine.phase.name} '
          'frameAvg=${engine.averageFrameMs.toStringAsFixed(2)}ms worst=${engine.worstFrameMs.toStringAsFixed(1)}ms '
          'render=${engine.renderer.stats.milliseconds.toStringAsFixed(2)}ms tris=${engine.renderer.stats.drawn} '
          'floor=${sim.floor}/${engine.level.floorCount} score=${sim.score}');
    }
    if (sim.over || sim.floor >= engine.level.floorCount) return;
    if (engine.level.mode == InputMode.smash) {
      _smash(engine);
      return;
    }
    final step = plan(sim, dt);
    if (step != 0) engine.input.injectRotation(step);
  }

  /// Rotation (rad) for this frame: head for the nearest gap along a hazard-free arc, and never swing
  /// a hazard under the ball while it is about to land.
  static double plan(Simulation sim, double dt) {
    final spec = sim.level.floors[sim.floor];
    final state = sim.floorStates[sim.floor];
    final local = CollisionSystem.localAngle(sim.rotation.angle, spec);
    bool hazard(int s) {
      final t = CollisionSystem.effectiveType(spec, state, s);
      return t == SegmentType.danger || t == SegmentType.blink;
    }

    int slotOf(double a) => CollisionSystem.slotIndex(AngleUtils.wrap(a));
    double? best;
    for (var s = 0; s < spec.slots.length; s++) {
      if (CollisionSystem.effectiveType(spec, state, s) != SegmentType.gap) continue;
      final centre = (s + 0.5) * GameConstants.slotAngle;
      for (final dir in [1.0, -1.0]) {
        var d = AngleUtils.wrap(dir > 0 ? centre - local : local - centre) * dir;
        // reject arcs that cross a hazard
        var clear = true;
        for (var k = 1; k <= 32 && clear; k++) {
          if (hazard(slotOf(local + d * k / 32))) clear = false;
        }
        if (clear && (best == null || d.abs() < best.abs())) best = d;
      }
    }
    final height = sim.ball.y - sim.level.floorTop(sim.floor);
    if (best == null) {
      // Every route crosses a hazard: only start if the ball stays airborne long enough to finish.
      for (var s = 0; s < spec.slots.length; s++) {
        if (CollisionSystem.effectiveType(spec, state, s) != SegmentType.gap) continue;
        final d = AngleUtils.delta((s + 0.5) * GameConstants.slotAngle, local);
        if (best == null || d.abs() < best.abs()) best = d;
      }
      if (best == null) return 0;
      final g = sim.level.gravity, h = height - GameConstants.ballRadius, v = sim.ball.vy;
      final tLand = (v + math.sqrt(math.max(0, v * v + 2 * g * h))) / g;
      if (!hazard(slotOf(local)) && tLand < best.abs() / 7.0 + 0.06) return 0;
    }
    final nearFloor = sim.ball.vy < 0 && height < 0.9;
    final maxStep = 7.0 * dt;
    final move = best.clamp(-maxStep, maxStep);
    if (nearFloor && !hazard(slotOf(local)) && hazard(slotOf(local + move))) return 0;
    // local = ball − angle − offset ⇒ increasing local needs a negative rotation.
    return -move;
  }

  static void _smash(GameEngine engine) {
    final sim = engine.sim;
    final spec = engine.level.floors[sim.floor];
    final hit = CollisionSystem().resolve(spec, sim.floorStates[sim.floor], sim.rotation.angle, sim.time);
    final lethal = hit.kind == CollisionKind.danger || hit.hazardDistance < 0.25;
    engine.input.injectHold(!lethal || sim.fireball || math.Random().nextDouble() < sloppiness);
  }
}
