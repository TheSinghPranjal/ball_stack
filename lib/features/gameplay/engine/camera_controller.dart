import 'dart:math' as math;

import '../../../core/render3d/camera3d.dart';

class CameraConfig {
  const CameraConfig({
    this.distance = 10.5,
    this.height = 5.2,
    this.lookDown = 2.4,
    this.viewWidth = 6.8,
    this.followSharpness = 7,
    this.introRise = 7,
    this.introDuration = 1.1,
    this.maxShake = 0.35,
  });

  /// Horizontal distance from the tower axis.
  final double distance;

  /// Eye height above the focus point.
  final double height;

  /// Look-at point below the focus point.
  final double lookDown;

  /// World width framed at the tower axis on the narrow screen dimension.
  final double viewWidth;
  final double followSharpness;
  final double introRise;
  final double introDuration;
  final double maxShake;
}

/// Smooth downward-following camera with intro swoop, screen shake and FOV kick.
class CameraController {
  CameraController({this.config = const CameraConfig()});

  final CameraConfig config;
  final math.Random _rng = math.Random(3);

  double focusY = 0;
  double _targetFocus = 0;
  double _shake = 0;
  double _kick = 0;
  double _intro = 1;
  double _sx = 0, _sy = 0;
  bool reduceMotion = false;

  void reset(double ballY, {bool intro = true}) {
    _targetFocus = ballY;
    focusY = ballY;
    _shake = 0;
    _kick = 0;
    _intro = intro ? 0 : 1;
  }

  void skipIntro() => _intro = 1;
  bool get introDone => _intro >= 1;

  void shake(double amount) {
    if (reduceMotion) amount *= 0.25;
    _shake = math.min(config.maxShake, math.max(_shake, amount));
  }

  void kick() {
    if (!reduceMotion) _kick = 1;
  }

  /// Follow only downward so bounces do not bob the view.
  void follow(double ballY) {
    if (ballY < _targetFocus) _targetFocus = ballY;
  }

  /// Allows the camera to move up again (e.g. after a revive).
  void snapTo(double ballY) {
    _targetFocus = ballY;
  }

  void update(double dt) {
    focusY += (_targetFocus - focusY) * (1 - math.exp(-dt * config.followSharpness));
    _shake *= math.exp(-dt * 7);
    _kick *= math.exp(-dt * 6);
    if (_intro < 1) _intro = math.min(1, _intro + dt / config.introDuration);
    _sx = (_rng.nextDouble() - 0.5) * 2 * _shake;
    _sy = (_rng.nextDouble() - 0.5) * 2 * _shake;
  }

  void apply(Camera3D cam, double width, double height) {
    final ease = 1 - math.pow(1 - _intro, 3).toDouble();
    final rise = (1 - ease) * config.introRise;
    final sx = _sx, sy = _sy;
    final ey = focusY + config.height + rise;
    final ez = config.distance + rise * 0.6;
    cam.lookAt(sx, ey + sy, ez, sx * 0.5, focusY - config.lookDown + sy * 0.5, 0);
    cam.cx = width / 2;
    cam.cy = height / 2;
    final narrow = math.min(width, height * 0.62);
    final dist = math.sqrt(ez * ez + math.pow(ey - (focusY - config.lookDown), 2));
    cam.frameWidth(narrow, config.viewWidth, dist);
    cam.focal *= 1 + 0.07 * _kick;
  }
}
