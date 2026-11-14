import '../../../core/services/storage_service.dart';
import '../domain/player_profile.dart';

class PlayerRepository {
  PlayerRepository(this._store);

  static const String key = 'player_profile_v1';
  final KeyValueStore _store;

  PlayerProfile load() {
    final j = _store.readJson(key);
    return j == null ? PlayerProfile() : PlayerProfile.fromJson(j);
  }

  Future<void> save(PlayerProfile p) => _store.writeJson(key, p.toJson());

  Future<void> clear() => _store.remove(key);
}
