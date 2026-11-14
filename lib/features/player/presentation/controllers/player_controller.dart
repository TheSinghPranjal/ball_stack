import 'package:get/get.dart';

import '../../../gameplay/domain/game_event.dart';
import '../../../gameplay/domain/level_config.dart';
import '../../../shop/data/skin_catalog.dart';
import '../../../shop/domain/ball_skin.dart';
import '../../data/player_repository.dart';
import '../../domain/player_profile.dart';
import '../../domain/progression_service.dart';

/// App-wide ViewModel for persistent player progress. Every mutation is saved immediately.
class PlayerController extends GetxService {
  PlayerController(this._repo);

  final PlayerRepository _repo;
  late PlayerProfile _profile;

  final coins = 0.obs;
  final currentLevel = 1.obs;
  final highestUnlocked = 1.obs;
  final bestScore = 0.obs;
  final bestCombo = 0.obs;
  final selectedSkinId = SkinCatalog.defaultSkinId.obs;
  final ownedSkins = <String>{}.obs;
  final shields = 0.obs;
  final levelStars = <int, int>{}.obs;
  final dailyAvailable = false.obs;

  PlayerProfile get profile => _profile;
  BallSkin get selectedSkin => SkinCatalog.byId(selectedSkinId.value);

  void load() {
    _profile = _repo.load();
    _publish();
  }

  void _publish() {
    final p = _profile;
    coins.value = p.coins;
    currentLevel.value = p.currentLevel;
    highestUnlocked.value = p.highestUnlocked;
    bestScore.value = p.bestScore;
    bestCombo.value = p.bestCombo;
    selectedSkinId.value = p.selectedSkin;
    ownedSkins
      ..clear()
      ..addAll(p.ownedSkins);
    shields.value = p.shields;
    levelStars
      ..clear()
      ..addAll(p.levelStars);
    dailyAvailable.value = ProgressionService.canClaimDaily(p, DateTime.now());
  }

  Future<void> _commit() async {
    _publish();
    await _repo.save(_profile);
  }

  Future<RunReward> finishRun(RunResult result, LevelConfig level) async {
    final reward = ProgressionService.applyRun(_profile, result, level);
    if (!reward.alreadyRewarded) await _commit();
    return reward;
  }

  Future<PurchaseResult> buyOrSelectSkin(String id) async {
    final r = ProgressionService.buyOrSelectSkin(_profile, id);
    if (r != PurchaseResult.insufficientCoins) await _commit();
    return r;
  }

  Future<PurchaseResult> buyShield() async {
    final r = ProgressionService.buyShield(_profile);
    if (r == PurchaseResult.purchased) await _commit();
    return r;
  }

  Future<void> consumeShield() async {
    if (_profile.shields <= 0) return;
    _profile.shields--;
    await _commit();
  }

  Future<bool> spend(int amount) async {
    final ok = ProgressionService.spend(_profile, amount);
    if (ok) await _commit();
    return ok;
  }

  Future<int> claimDaily() async {
    final amount = ProgressionService.claimDaily(_profile, DateTime.now());
    if (amount > 0) await _commit();
    return amount;
  }

  int get nextDailyDay => ProgressionService.nextStreakDay(_profile, DateTime.now());

  Future<void> selectLevel(int level) async {
    if (level > _profile.highestUnlocked) return;
    _profile.currentLevel = level;
    await _commit();
  }

  Future<void> resetProgress() async {
    await _repo.clear();
    _profile = PlayerProfile();
    await _commit();
  }
}
