import 'package:get/get.dart';

import '../../../../core/enums/game_enums.dart';
import '../../../../core/services/audio_service.dart';
import '../../data/settings_repository.dart';
import '../../domain/game_settings.dart';

/// App-wide settings ViewModel; persists on every change and pushes audio settings live.
class SettingsController extends GetxService {
  SettingsController(this._repo);

  final SettingsRepository _repo;
  final settings = const GameSettings().obs;

  GameSettings get value => settings.value;

  void load() {
    settings.value = _repo.load();
    _applyAudio();
  }

  void _applyAudio() {
    if (Get.isRegistered<AudioService>()) Get.find<AudioService>().apply(settings.value);
  }

  Future<void> update(GameSettings Function(GameSettings s) change) async {
    settings.value = change(settings.value);
    _applyAudio();
    await _repo.save(settings.value);
  }

  Future<void> toggleMusic() => update((s) => s.copyWith(music: !s.music));
  Future<void> toggleSfx() => update((s) => s.copyWith(sfx: !s.sfx));
  Future<void> toggleHaptics() => update((s) => s.copyWith(haptics: !s.haptics));
  Future<void> toggleReduceMotion() => update((s) => s.copyWith(reduceMotion: !s.reduceMotion));
  Future<void> setQuality(GraphicsQuality q) => update((s) => s.copyWith(quality: q));
  Future<void> setSensitivity(double v) => update((s) => s.copyWith(sensitivity: v));
  Future<void> setMode(InputMode m) => update((s) => s.copyWith(mode: m));
  Future<void> markTutorialSeen() => update((s) => s.copyWith(tutorialSeen: true));

  /// Toggles music and sfx together (the home-screen speaker button).
  Future<void> toggleSound() {
    final on = !(value.music || value.sfx);
    return update((s) => s.copyWith(music: on, sfx: on));
  }
}
