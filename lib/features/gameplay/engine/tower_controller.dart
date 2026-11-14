import 'dart:math' as math;

import '../../../app/theme/colors.dart';
import '../../../core/render3d/mesh_instance.dart';
import '../domain/level_config.dart';
import 'collision_system.dart';
import 'platform_controller.dart';

/// Render objects of one floor.
class FloorView {
  FloorView(this.index);

  final int index;
  MeshInstance? solid, hazard, bonus, blink, sweeper;
  late MeshInstance pillar;
  late MeshInstance ring;
  bool hidden = false;

  Iterable<MeshInstance> get platformObjects sync* {
    if (solid != null) yield solid!;
    if (hazard != null) yield hazard!;
    if (bonus != null) yield bonus!;
    if (blink != null) yield blink!;
    if (sweeper != null) yield sweeper!;
  }
}

/// Keeps meshes only for floors near the ball (sliding window), rebuilds dirty floors and applies
/// the tower rotation to every floor each frame.
class TowerController {
  TowerController({required this.level, required this.platforms, required this.theme, required this.floorStates});

  final LevelConfig level;
  final PlatformController platforms;
  final GameTheme theme;
  final List<FloorState> floorStates;
  final Map<int, FloorView> _views = {};
  final Set<int> _dirty = {};

  late final MeshInstance pillarTop = MeshInstance(platforms.pillarTop());
  late final MeshInstance base = MeshInstance(platforms.base());

  int _windowStart = 0, _windowEnd = -1;

  Iterable<FloorView> get views => _views.values;

  void markDirty(int floor) => _dirty.add(floor);

  /// Ensures floors in [current-2, current+ahead] have meshes and disposes the rest.
  void ensureWindow(int current, int ahead) {
    final start = math.max(0, current - 2);
    final end = math.min(level.floorCount - 1, current + ahead);
    if (start != _windowStart || end != _windowEnd) {
      _views.removeWhere((i, _) => i < start || i > end);
      _windowStart = start;
      _windowEnd = end;
    }
    for (var i = start; i <= end; i++) {
      if (!_views.containsKey(i) || _dirty.contains(i)) {
        _views[i] = _build(i);
      }
    }
    _dirty.clear();
  }

  FloorView _build(int i) {
    final spec = level.floors[i];
    final meshes = platforms.build(spec, floorStates[i]);
    final v = FloorView(i)
      ..pillar = MeshInstance(meshes.pillar)
      ..ring = (MeshInstance(meshes.ring)
        // Pillar triangles are tall, so their average depth would sort them over the thin ring.
        ..depthBias = -0.6);
    if (meshes.solid != null) v.solid = MeshInstance(meshes.solid!);
    if (meshes.hazard != null) v.hazard = MeshInstance(meshes.hazard!);
    if (meshes.bonus != null) v.bonus = MeshInstance(meshes.bonus!);
    if (meshes.blink != null) v.blink = MeshInstance(meshes.blink!)..tintAmount = 1;
    if (meshes.sweeper != null) v.sweeper = MeshInstance(meshes.sweeper!);
    v.hidden = floorStates[i].broken;
    return v;
  }

  /// Applies rotation, blink colours and sweeper motion.
  void update(double towerAngle, double time) {
    for (final v in _views.values) {
      final spec = level.floors[v.index];
      final y = level.floorTop(v.index);
      final rot = towerAngle + spec.offset;
      v.hidden = floorStates[v.index].broken;
      v.pillar
        ..setPosition(0, y, 0)
        ..setRotationY(towerAngle);
      v.ring
        ..setPosition(0, y, 0)
        ..setRotationY(towerAngle);
      for (final o in v.platformObjects) {
        o.visible = !v.hidden;
        o
          ..setPosition(0, y, 0)
          ..setRotationY(rot);
      }
      final blink = v.blink;
      if (blink != null && spec.blink != null) {
        final on = spec.blink!.isDangerAt(time);
        final cyc = spec.blink!.cycle(time);
        // Warn shortly before turning lethal: fast flicker during the last 22% of the safe phase.
        final warn = !on && cyc > 0.78 && (time * 14).floor().isEven;
        blink.tint = on ? theme.dangerRim : (warn ? 0xFFFF9FB2 : theme.safeB);
        blink.emissiveBoost = on ? 0.35 : 0;
      }
      final sw = v.sweeper;
      if (sw != null && spec.sweeper != null) {
        sw.setRotationY(rot + spec.sweeper!.angleAt(time));
      }
    }
    pillarTop
      ..setPosition(0, level.floorTop(0), 0)
      ..setRotationY(towerAngle);
    base
      ..setPosition(0, level.floorTop(level.floorCount), 0)
      ..setRotationY(towerAngle);
  }

  void addTo(List<MeshInstance> out, int currentFloor) {
    if (currentFloor <= 3) out.add(pillarTop);
    for (final v in _views.values) {
      out
        ..add(v.pillar)
        ..add(v.ring);
      if (!v.hidden) out.addAll(v.platformObjects);
    }
    if (_windowEnd >= level.floorCount - 3) out.add(base);
  }
}
