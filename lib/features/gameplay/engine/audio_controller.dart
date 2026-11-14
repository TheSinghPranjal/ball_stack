import '../domain/game_event.dart';

/// Sound identifiers (file names under assets/audio/sfx without extension).
abstract final class Sfx {
  static const bounce = 'bounce';
  static const land = 'land';
  static const breakSeg = 'break';
  static const smash = 'smash';
  static const fireball = 'fireball';
  static const combo = 'combo';
  static const coin = 'coin';
  static const click = 'click';
  static const nearMiss = 'near_miss';
  static const levelComplete = 'level_complete';
  static const gameOver = 'game_over';
  static const shield = 'shield';
  static String pass(int chain) => 'pass_${chain.clamp(1, 8)}';

  static const all = [
    bounce,
    land,
    breakSeg,
    smash,
    fireball,
    combo,
    coin,
    click,
    nearMiss,
    levelComplete,
    gameOver,
    shield,
    'pass_1',
    'pass_2',
    'pass_3',
    'pass_4',
    'pass_5',
    'pass_6',
    'pass_7',
    'pass_8',
  ];
}

/// Engine-facing audio/haptic sink (implemented by the app's AudioService/HapticsService).
abstract interface class GameAudioSink {
  void playSfx(String id, {double volume = 1});
  void haptic(HapticLevel level);
}

enum HapticLevel { light, medium, heavy }

/// Maps simulation events to sounds and haptics. Throttles repeated bounce sounds.
class AudioController {
  AudioController(this.sink);

  final GameAudioSink? sink;
  double _lastBounce = -1;

  void onEvent(GameEvent e, double time) {
    final s = sink;
    if (s == null) return;
    switch (e.type) {
      case GameEventType.bounce:
        if (time - _lastBounce > 0.08) {
          s.playSfx(Sfx.bounce, volume: 0.8);
          _lastBounce = time;
        }
      case GameEventType.floorPassed:
        s.playSfx(Sfx.pass(e.chain), volume: 0.8);
        s.haptic(HapticLevel.light);
      case GameEventType.smashReady:
        s.playSfx(Sfx.fireball);
        s.haptic(HapticLevel.medium);
      case GameEventType.fireballOn:
        s.playSfx(Sfx.fireball);
        s.haptic(HapticLevel.medium);
      case GameEventType.smashed:
        s.playSfx(Sfx.smash);
        s.haptic(HapticLevel.heavy);
      case GameEventType.ringSmashed:
        s.playSfx(Sfx.breakSeg, volume: 0.7);
        if (e.chain % 5 == 0) s.playSfx(Sfx.combo, volume: 0.6);
        s.haptic(HapticLevel.light);
      case GameEventType.segmentBroken:
        s.playSfx(Sfx.breakSeg);
        s.haptic(HapticLevel.medium);
      case GameEventType.bonusCollected:
        s.playSfx(Sfx.coin);
      case GameEventType.nearMiss:
        s.playSfx(Sfx.nearMiss, volume: 0.7);
      case GameEventType.shieldUsed:
        s.playSfx(Sfx.shield);
        s.haptic(HapticLevel.heavy);
      case GameEventType.death:
        s.playSfx(Sfx.gameOver);
        s.haptic(HapticLevel.heavy);
      case GameEventType.levelComplete:
        s.playSfx(Sfx.land);
        s.playSfx(Sfx.levelComplete);
        s.haptic(HapticLevel.heavy);
      case GameEventType.comboReset:
      case GameEventType.fireballOff:
        break;
    }
  }
}
