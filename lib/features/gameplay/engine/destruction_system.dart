import 'dart:math' as math;

import '../../../app/theme/colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/render3d/color_math.dart';
import '../../../core/render3d/mesh.dart';
import '../../../core/render3d/mesh_factory.dart';
import '../../../core/render3d/mesh_instance.dart';
import '../domain/level_config.dart';
import 'collision_system.dart';
import 'platform_controller.dart';

class _Fragment {
  _Fragment(this.obj);

  final MeshInstance obj;
  bool active = false;
  double vx = 0, vy = 0, vz = 0;
  double pitch = 0, yaw = 0, roll = 0;
  double wp = 0, wy = 0, wr = 0;
  double age = 0, life = 1;
  double scale = 1;
}

class _Ring {
  _Ring(this.obj);

  final MeshInstance obj;
  bool active = false;
  double age = 0, life = 0.5, grow = 3;
}

/// Shatters floors/segments into pooled, physically animated 3D shards and shockwave rings.
class DestructionSystem {
  DestructionSystem({required this.platforms, required this.theme, int poolSize = 72}) {
    final placeholder = platforms.shard(theme.safeA);
    for (var i = 0; i < poolSize; i++) {
      _fragments.add(_Fragment(MeshInstance(placeholder)..visible = false));
    }
    final ringMesh = () {
      final b = MeshBuilder();
      MeshFactory.annulus(b, 0.82, 1.0, 0, 28, 0xFFFFFFFF);
      return b.build(MeshMaterial.decal);
    }();
    for (var i = 0; i < 4; i++) {
      _rings.add(_Ring(MeshInstance(ringMesh)..visible = false));
    }
  }

  final PlatformController platforms;
  final GameTheme theme;
  final List<_Fragment> _fragments = [];
  final List<_Ring> _rings = [];
  final math.Random _rng = math.Random(11);
  int _next = 0;
  double density = 1;

  int get activeFragments => _fragments.where((f) => f.active).length;

  _Fragment _take() {
    // Recycle the oldest slot when the pool is exhausted.
    final f = _fragments[_next];
    _next = (_next + 1) % _fragments.length;
    return f;
  }

  int _slotColor(FloorSpec f, int s) => switch (f.slots[s]) {
    SegmentType.danger => theme.danger,
    SegmentType.blink => theme.dangerRim,
    SegmentType.bonus => theme.bonus,
    SegmentType.breakable => ColorMath.lerp(s.isEven ? theme.safeA : theme.safeB, 0xFFFFFFFF, 0.5),
    _ => s.isEven ? theme.safeA : theme.safeB,
  };

  /// Shatters every live segment of a floor. [power] > 1 for smashes (bigger, faster, upward blast).
  void shatterFloor(LevelConfig level, FloorSpec spec, FloorState state, double towerAngle, double power) {
    final y = level.floorTop(spec.index) - level.platformThickness / 2;
    final step = density < 0.7 ? 2 : 1;
    for (var s = 0; s < spec.slots.length; s += step) {
      if (spec.slots[s] == SegmentType.gap || state.destroyed[s]) continue;
      _spawnShard(spec, s, towerAngle, y, power, _slotColor(spec, s));
    }
    _ring(y + level.platformThickness / 2 + 0.05, power > 1 ? 0xFFFFF2B0 : theme.accent, power > 1 ? 3.6 : 2.6);
  }

  /// Breaks a single segment (breakable slots).
  void breakSegment(LevelConfig level, FloorSpec spec, int slot, double towerAngle) {
    final y = level.floorTop(spec.index) - level.platformThickness / 2;
    for (var k = 0; k < 2; k++) {
      _spawnShard(spec, slot, towerAngle, y, 0.8, _slotColor(spec, slot), scale: 0.7);
    }
  }

  void _spawnShard(FloorSpec spec, int s, double towerAngle, double y, double power, int color, {double scale = 1}) {
    final f = _take();
    final a = towerAngle + spec.offset + (s + 0.5) * GameConstants.slotAngle;
    final dirX = math.sin(a), dirZ = math.cos(a);
    const r = GameConstants.ballOrbitRadius;
    f.obj
      ..mesh = platforms.shard(color)
      ..visible = true
      ..alpha = 1
      ..setPosition(dirX * r, y, dirZ * r)
      ..setScale(scale);
    final sp = (2.4 + _rng.nextDouble() * 3.0) * power;
    f
      ..active = true
      ..vx = dirX * sp
      ..vz = dirZ * sp
      ..vy = power > 1 ? 3 + _rng.nextDouble() * 3 : -1.5 + _rng.nextDouble() * 2.5
      ..yaw = a
      ..pitch = 0
      ..roll = 0
      ..wp = (_rng.nextDouble() - 0.5) * 9
      ..wy = (_rng.nextDouble() - 0.5) * 5
      ..wr = (_rng.nextDouble() - 0.5) * 9
      ..age = 0
      ..scale = scale
      ..life = power > 1 ? 1.0 + _rng.nextDouble() * 0.4 : 0.7 + _rng.nextDouble() * 0.35;
  }

  void _ring(double y, int color, double grow) {
    final ring = _rings.firstWhere((r) => !r.active, orElse: () => _rings.first);
    ring
      ..active = true
      ..age = 0
      ..life = 0.45
      ..grow = grow;
    ring.obj
      ..visible = true
      ..tint = color
      ..tintAmount = 1
      ..setPosition(0, y, 0)
      ..setScale(1);
  }

  void update(double dt) {
    for (final f in _fragments) {
      if (!f.active) continue;
      f.age += dt;
      final t = f.age / f.life;
      if (t >= 1) {
        f.active = false;
        f.obj.visible = false;
        continue;
      }
      f.vy -= 26 * dt;
      f.obj.x += f.vx * dt;
      f.obj.y += f.vy * dt;
      f.obj.z += f.vz * dt;
      f.pitch += f.wp * dt;
      f.yaw += f.wy * dt;
      f.roll += f.wr * dt;
      f.obj.setEuler(f.pitch, f.yaw, f.roll);
      f.obj.alpha = t < 0.65 ? 1 : (1 - (t - 0.65) / 0.35);
      f.obj.setScale(f.scale * (1 - t * 0.35));
    }
    for (final r in _rings) {
      if (!r.active) continue;
      r.age += dt;
      final t = r.age / r.life;
      if (t >= 1) {
        r.active = false;
        r.obj.visible = false;
        continue;
      }
      final s = 1 + (r.grow - 1) * (1 - math.pow(1 - t, 3));
      r.obj
        ..sx = s
        ..sz = s
        ..sy = 1
        ..alpha = 0.85 * (1 - t);
    }
  }

  void addTo(List<MeshInstance> out) {
    for (final f in _fragments) {
      if (f.active) out.add(f.obj);
    }
    for (final r in _rings) {
      if (r.active) out.add(r.obj);
    }
  }

  void clear() {
    for (final f in _fragments) {
      f.active = false;
      f.obj.visible = false;
    }
    for (final r in _rings) {
      r.active = false;
      r.obj.visible = false;
    }
  }
}
