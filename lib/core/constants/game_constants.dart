import 'dart:math' as math;

/// Global tunables. Per-level values live in `LevelConfig`; these are the defaults it is generated from.
abstract final class GameConstants {
  // ---- geometry
  static const int slotsPerFloor = 16;
  static const double slotAngle = 2 * math.pi / slotsPerFloor;
  static const double floorSpacing = 3.2;
  static const double platformInnerRadius = 0.78;
  static const double platformOuterRadius = 2.6;
  static const double platformThickness = 0.45;
  static const double pillarRadius = 0.74;
  static const double ballRadius = 0.3;

  /// Ball orbit radius (middle of the platform ring).
  static const double ballOrbitRadius = (platformInnerRadius + platformOuterRadius) / 2;

  /// World angle of the ball (0 = facing the camera).
  static const double ballWorldAngle = 0;

  // ---- physics
  static const double fixedStep = 1 / 120;
  static const int maxStepsPerFrame = 10;
  static const double gravity = 36;
  static const double bounceVelocity = 11.2;
  static const double terminalVelocity = 23;
  static const double diveVelocity = 24;
  static const double ballStartHeight = 2.6;

  // ---- rotation / input
  static const double keyRotationSpeed = 3.8; // rad/s
  static const double dragTurnsPerScreen = 1.1;
  static const double inertiaFriction = 9; // 1/s
  static const double maxInertia = 9; // rad/s

  // ---- combo / smash
  static const int smashChainThreshold = 3;
  static const int maxMultiplier = 8;
  static const double nearMissAngle = 0.16;

  // ---- fireball (smash mode)
  static const double heatPerRing = 0.12;
  static const double heatDecay = 0.6;
  static const double fireballDuration = 2.5;

  // ---- revive
  static const double reviveGrace = 1.6;
}

abstract final class ScoringRules {
  static const int floorPass = 10;
  static const int smashBonus = 20;
  static const int ringSmash = 5;
  static const int breakable = 15;
  static const int nearMiss = 5;
  static const int levelCompleteBase = 100;
  static const int levelCompletePerLevel = 5;

  static int multiplier(int chain) => chain.clamp(1, GameConstants.maxMultiplier);
  static int passPoints(int chain) => floorPass * multiplier(chain);
  static int levelComplete(int level) => levelCompleteBase + levelCompletePerLevel * level;
}

/// Monetisation is modular and **off** by default. No ad SDK is bundled; when enabled a provider must be
/// registered in `MonetizationService`.
abstract final class MonetizationConfig {
  static const bool enabled = false;
  static const bool interstitialsBetweenLevels = false;
}
