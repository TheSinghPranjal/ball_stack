import '../../../core/constants/game_constants.dart';

/// Tracks consecutive drops (spin mode) and consecutive destructions (smash mode). Renderer-independent.
class ComboSystem {
  /// Floors fallen through without a bounce.
  int chain = 0;

  /// Rings smashed in a row while holding (smash mode).
  int streak = 0;

  int maxCombo = 0;

  /// Spin mode: next landing smashes the floor.
  bool smashReady = false;

  int get multiplier => chain.clamp(1, GameConstants.maxMultiplier);

  /// Returns true when this pass newly activated smash-ready.
  bool onFloorPassed() {
    chain++;
    if (chain > maxCombo) maxCombo = chain;
    if (chain >= GameConstants.smashChainThreshold && !smashReady) {
      smashReady = true;
      return true;
    }
    return false;
  }

  /// Consumes smash-ready. The smashed floor counts towards the chain before it resets.
  int onSmash() {
    final c = chain + 1;
    if (c > maxCombo) maxCombo = c;
    smashReady = false;
    chain = 0;
    return c;
  }

  void onRingSmashed() {
    streak++;
    if (streak > maxCombo) maxCombo = streak;
  }

  /// Returns the chain that was lost (0 if none).
  int onBounce() {
    final lost = chain > streak ? chain : streak;
    chain = 0;
    streak = 0;
    return lost;
  }

  void reset() {
    chain = 0;
    streak = 0;
    maxCombo = 0;
    smashReady = false;
  }
}
