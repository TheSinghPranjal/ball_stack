import 'dart:math' as math;

import '../../../core/render3d/color_math.dart';
import '../../../core/render3d/mesh_instance.dart';

/// Fixed-size pool of GPU-cheap billboard particles (sparks, dust, flames, ambient motes).
/// Nothing is allocated after construction.
class ParticleSystem {
  ParticleSystem({this.capacity = 360}) {
    for (var i = 0; i < capacity; i++) {
      billboards.add(Billboard());
    }
    _vx = List.filled(capacity, 0);
    _vy = List.filled(capacity, 0);
    _vz = List.filled(capacity, 0);
    _life = List.filled(capacity, 0);
    _age = List.filled(capacity, 0);
    _size0 = List.filled(capacity, 0);
    _gravity = List.filled(capacity, 0);
    _color = List.filled(capacity, 0);
  }

  final int capacity;
  final List<Billboard> billboards = [];
  late final List<double> _vx, _vy, _vz, _life, _age, _size0, _gravity;
  late final List<int> _color;
  final math.Random _rng = math.Random(7);
  int _next = 0;

  /// Global density multiplier from graphics quality.
  double density = 1;

  int get activeCount => billboards.where((b) => b.active).length;

  void _spawn(
    double x,
    double y,
    double z,
    double vx,
    double vy,
    double vz,
    double size,
    int color,
    double life,
    double gravity,
  ) {
    final i = _next;
    _next = (_next + 1) % capacity;
    final b = billboards[i]
      ..active = true
      ..x = x
      ..y = y
      ..z = z
      ..size = size
      ..color = color;
    _vx[i] = vx;
    _vy[i] = vy;
    _vz[i] = vz;
    _life[i] = life;
    _age[i] = 0;
    _size0[i] = size;
    _gravity[i] = gravity;
    _color[i] = color;
    b.active = true;
  }

  /// Spherical burst.
  void burst(
    double x,
    double y,
    double z, {
    required int count,
    required int color,
    double speed = 4,
    double size = 0.12,
    double life = 0.7,
    double gravity = 14,
    double upBias = 2,
  }) {
    final n = (count * density).round();
    for (var k = 0; k < n; k++) {
      final th = _rng.nextDouble() * math.pi * 2;
      final ph = math.acos(2 * _rng.nextDouble() - 1);
      final sp = speed * (0.35 + _rng.nextDouble() * 0.8);
      _spawn(
        x,
        y,
        z,
        math.sin(ph) * math.cos(th) * sp,
        math.cos(ph).abs() * sp * 0.6 + upBias * _rng.nextDouble(),
        math.sin(ph) * math.sin(th) * sp,
        size * (0.6 + _rng.nextDouble() * 0.8),
        _rng.nextDouble() < 0.25 ? ColorMath.lerp(color, 0xFFFFFFFF, 0.6) : color,
        life * (0.6 + _rng.nextDouble() * 0.6),
        gravity,
      );
    }
  }

  /// Flat splash on a surface (impact dust).
  void splash(double x, double y, double z, int color, {int count = 10}) {
    final n = (count * density).round();
    for (var k = 0; k < n; k++) {
      final th = _rng.nextDouble() * math.pi * 2;
      final sp = 1.5 + _rng.nextDouble() * 2.2;
      _spawn(
        x,
        y + 0.05,
        z,
        math.cos(th) * sp,
        1 + _rng.nextDouble() * 2.5,
        math.sin(th) * sp,
        0.08 + _rng.nextDouble() * 0.08,
        color,
        0.35 + _rng.nextDouble() * 0.25,
        18,
      );
    }
  }

  /// Rising flame licks behind a fireball.
  void flame(double x, double y, double z, {int color = 0xFFFF7A1A}) {
    if (_rng.nextDouble() > density) return;
    final c = _rng.nextDouble() < 0.4 ? 0xFFFFE27A : color;
    _spawn(
      x + (_rng.nextDouble() - 0.5) * 0.3,
      y + 0.1,
      z + (_rng.nextDouble() - 0.5) * 0.3,
      (_rng.nextDouble() - 0.5) * 0.6,
      2.5 + _rng.nextDouble() * 2,
      (_rng.nextDouble() - 0.5) * 0.6,
      0.22 + _rng.nextDouble() * 0.16,
      c,
      0.3 + _rng.nextDouble() * 0.2,
      -2,
    );
  }

  void update(double dt) {
    for (var i = 0; i < capacity; i++) {
      final b = billboards[i];
      if (!b.active) continue;
      _age[i] += dt;
      final t = _age[i] / _life[i];
      if (t >= 1) {
        b.active = false;
        continue;
      }
      _vy[i] -= _gravity[i] * dt;
      final drag = math.exp(-1.8 * dt);
      _vx[i] *= drag;
      _vz[i] *= drag;
      b.x += _vx[i] * dt;
      b.y += _vy[i] * dt;
      b.z += _vz[i] * dt;
      b.size = _size0[i] * (1 - t * 0.6);
      b.color = ColorMath.withAlpha(_color[i], (1 - t) * (ColorMath.a(_color[i]) / 255));
    }
  }

  void clear() {
    for (final b in billboards) {
      b.active = false;
    }
  }
}
