import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:get/get.dart';

import '../../features/gameplay/engine/audio_controller.dart';
import '../../features/settings/domain/game_settings.dart';
import '../logging/log.dart';

/// Low-latency SFX via [AudioPool]s, a looping music player, and haptics. Pauses music when the app
/// is backgrounded. Implements the engine's [GameAudioSink].
class AudioService extends GetxService with WidgetsBindingObserver implements GameAudioSink {
  final Map<String, AudioPool> _pools = {};
  AudioPlayer? _music;
  bool _ready = false;
  bool _musicWanted = false;
  bool _foreground = true;

  bool sfxOn = true;
  bool musicOn = true;
  bool hapticsOn = true;
  double sfxVolume = 0.9;
  double musicVolume = 0.6;

  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    WidgetsBinding.instance.addObserver(this);
    try {
      // iOS "ambient": respects the silent switch and mixes with the user's own music (game convention).
      // Android: game usage; no exclusive focus so SFX never stop other apps.
      await AudioPlayer.global.setAudioContext(AudioContext(
        iOS: AudioContextIOS(category: AVAudioSessionCategory.ambient),
        android: const AudioContextAndroid(
          contentType: AndroidContentType.sonification,
          usageType: AndroidUsageType.game,
          audioFocus: AndroidAudioFocus.none,
        ),
      ));
      for (final id in Sfx.all) {
        _pools[id] = await AudioPool.create(
          source: AssetSource('audio/sfx/$id.wav'),
          maxPlayers: id == Sfx.bounce || id.startsWith('pass') ? 3 : 2,
        );
      }
      final music = AudioPlayer(playerId: 'music');
      await music.setReleaseMode(ReleaseMode.loop);
      await music.setSource(AssetSource('audio/music/music_loop.wav'));
      _music = music;
      _ready = true;
    } catch (e) {
      Log.w('Audio', 'audio unavailable: $e');
    }
  }

  void apply(GameSettings s) {
    sfxOn = s.sfx;
    musicOn = s.music;
    hapticsOn = s.haptics;
    sfxVolume = s.sfxVolume;
    musicVolume = s.musicVolume;
    _music?.setVolume(musicVolume);
    _syncMusic();
  }

  @override
  void playSfx(String id, {double volume = 1}) {
    if (!sfxOn || !_foreground) return;
    final pool = _pools[id];
    if (pool == null) return;
    pool.start(volume: (volume * sfxVolume).clamp(0.0, 1.0)).catchError((Object e) {
      Log.w('Audio', 'sfx $id failed: $e');
      return () async {};
    });
  }

  void click() {
    playSfx(Sfx.click, volume: 0.6);
    haptic(HapticLevel.light);
  }

  @override
  void haptic(HapticLevel level) {
    if (!hapticsOn) return;
    switch (level) {
      case HapticLevel.light:
        HapticFeedback.selectionClick();
      case HapticLevel.medium:
        HapticFeedback.lightImpact();
      case HapticLevel.heavy:
        HapticFeedback.mediumImpact();
    }
  }

  void startMusic() {
    _musicWanted = true;
    _syncMusic();
  }

  void stopMusic() {
    _musicWanted = false;
    _syncMusic();
  }

  void _syncMusic() {
    final m = _music;
    if (m == null) return;
    final shouldPlay = _musicWanted && musicOn && _foreground;
    if (shouldPlay && m.state != PlayerState.playing) {
      m.setVolume(musicVolume);
      m.resume();
    } else if (!shouldPlay && m.state == PlayerState.playing) {
      m.pause();
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    _syncMusic();
  }

  @override
  void onClose() {
    WidgetsBinding.instance.removeObserver(this);
    for (final p in _pools.values) {
      p.dispose();
    }
    _music?.dispose();
    super.onClose();
  }
}
