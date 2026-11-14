import 'dart:math' as math;

import '../../../core/constants/game_constants.dart';

/// Tower angle. Spin mode: direct drag + key velocity + release inertia with friction.
/// Smash mode: constant auto-rotation from the level config.
class RotationController {
  double angle = 0;
  double prevAngle = 0;

  /// Inertial angular velocity (rad/s) after a drag is released.
  double inertia = 0;

  /// Smoothed keyboard velocity (rad/s).
  double keyVelocity = 0;

  bool inertiaEnabled = true;

  void stepSpin(
    double dt, {
    required double dragDelta,
    required double keyAxis,
    required bool dragging,
    required double releaseVelocity,
  }) {
    prevAngle = angle;
    final targetKey = keyAxis * GameConstants.keyRotationSpeed;
    keyVelocity += (targetKey - keyVelocity) * (1 - math.exp(-dt * 24));
    if (dragging) {
      inertia = 0;
    } else if (releaseVelocity != 0 && inertiaEnabled) {
      inertia = releaseVelocity.clamp(-GameConstants.maxInertia, GameConstants.maxInertia);
    }
    if (!dragging && inertia != 0) {
      inertia *= math.exp(-GameConstants.inertiaFriction * dt);
      if (inertia.abs() < 0.02) inertia = 0;
    }
    angle += dragDelta + (keyVelocity + inertia) * dt;
  }

  void stepAuto(double dt, double speed, int direction) {
    prevAngle = angle;
    angle += speed * direction * dt;
  }
}
