import '../../../core/services/storage_service.dart';
import '../domain/game_settings.dart';

class SettingsRepository {
  SettingsRepository(this._store);

  static const String key = 'settings_v1';
  final KeyValueStore _store;

  GameSettings load() {
    final j = _store.readJson(key);
    return j == null ? const GameSettings() : GameSettings.fromJson(j);
  }

  Future<void> save(GameSettings s) => _store.writeJson(key, s.toJson());
}
