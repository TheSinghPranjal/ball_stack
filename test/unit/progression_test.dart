import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/core/services/storage_service.dart';
import 'package:ball_stack/features/gameplay/domain/game_event.dart';
import 'package:ball_stack/features/levels/data/level_generator.dart';
import 'package:ball_stack/features/player/data/player_repository.dart';
import 'package:ball_stack/features/player/domain/player_profile.dart';
import 'package:ball_stack/features/player/domain/progression_service.dart';
import 'package:ball_stack/features/settings/data/settings_repository.dart';
import 'package:ball_stack/features/settings/domain/game_settings.dart';
import 'package:ball_stack/features/shop/data/skin_catalog.dart';
import 'package:flutter_test/flutter_test.dart';

RunResult run(String id, {int level = 1, bool won = true, int score = 500, int combo = 4, int bonus = 2}) => RunResult(
      runId: id,
      levelId: level,
      won: won,
      score: score,
      floorsCleared: 10,
      totalFloors: 10,
      bestCombo: combo,
      bonusCoins: bonus,
      smashes: 1,
      seconds: 30,
    );

void main() {
  final level1 = LevelGenerator().generate(1, InputMode.spin);

  group('rewards', () {
    test('winning pays coins, unlocks the next level and records stars', () {
      final p = PlayerProfile();
      final r = ProgressionService.applyRun(p, run('a'), level1);
      expect(r.alreadyRewarded, isFalse);
      expect(r.firstClearCoins, level1.reward.firstClearBonus);
      expect(r.total, r.scoreCoins + r.bonusCoins + r.comboCoins + r.firstClearCoins);
      expect(p.coins, r.total);
      expect(p.highestUnlocked, 2);
      expect(p.currentLevel, 2);
      expect(p.levelStars[1], greaterThanOrEqualTo(1));
      expect(p.bestScore, 500);
    });

    test('the same run never pays twice', () {
      final p = PlayerProfile();
      ProgressionService.applyRun(p, run('a'), level1);
      final coins = p.coins;
      final again = ProgressionService.applyRun(p, run('a'), level1);
      expect(again.alreadyRewarded, isTrue);
      expect(p.coins, coins);
    });

    test('first-clear bonus is paid only once per level', () {
      final p = PlayerProfile();
      ProgressionService.applyRun(p, run('a'), level1);
      final second = ProgressionService.applyRun(p, run('b'), level1);
      expect(second.firstClearCoins, 0);
    });

    test('a failed run unlocks nothing', () {
      final p = PlayerProfile();
      final r = ProgressionService.applyRun(p, run('x', won: false, score: 300), level1);
      expect(r.stars, 0);
      expect(p.highestUnlocked, 1);
      expect(p.isCompleted(1), isFalse);
    });

    test('stars scale with score relative to par', () {
      expect(ProgressionService.stars(1000, 1000, true), 3);
      expect(ProgressionService.stars(600, 1000, true), 2);
      expect(ProgressionService.stars(100, 1000, true), 1);
      expect(ProgressionService.stars(5000, 1000, false), 0);
    });
  });

  group('shop', () {
    test('cannot buy without coins; buying deducts once; re-select is free', () {
      final p = PlayerProfile(coins: 100);
      expect(ProgressionService.buyOrSelectSkin(p, 'chrome'), PurchaseResult.insufficientCoins);
      expect(p.coins, 100);
      p.coins = 1000;
      expect(ProgressionService.buyOrSelectSkin(p, 'chrome'), PurchaseResult.purchased);
      expect(p.coins, 700);
      expect(p.selectedSkin, 'chrome');
      expect(ProgressionService.buyOrSelectSkin(p, 'chrome'), PurchaseResult.selected);
      expect(p.coins, 700, reason: 'never charge twice for the same skin');
      expect(ProgressionService.buyOrSelectSkin(p, SkinCatalog.defaultSkinId), PurchaseResult.selected);
    });

    test('shields are capped', () {
      final p = PlayerProfile(coins: 10000);
      for (var i = 0; i < ProgressionService.maxShields; i++) {
        expect(ProgressionService.buyShield(p), PurchaseResult.purchased);
      }
      expect(ProgressionService.buyShield(p), PurchaseResult.maxReached);
      expect(p.shields, ProgressionService.maxShields);
    });
  });

  group('daily reward', () {
    test('claim once per day, streak continues on consecutive days and resets after a gap', () {
      final p = PlayerProfile();
      final d1 = DateTime(2026, 11, 14, 9);
      expect(ProgressionService.claimDaily(p, d1), ProgressionService.dailyAmount(1));
      expect(ProgressionService.claimDaily(p, d1.add(const Duration(hours: 5))), 0);
      expect(ProgressionService.claimDaily(p, DateTime(2026, 11, 15)), ProgressionService.dailyAmount(2));
      expect(p.dailyStreak, 2);
      expect(ProgressionService.claimDaily(p, DateTime(2026, 11, 18)), ProgressionService.dailyAmount(1));
      expect(p.dailyStreak, 1);
    });
  });

  group('persistence', () {
    test('profile survives a save/load cycle', () async {
      final store = MemoryStore();
      final repo = PlayerRepository(store);
      final p = PlayerProfile(coins: 321, currentLevel: 7, highestUnlocked: 9, shields: 2, selectedSkin: 'neon')
        ..ownedSkins.add('neon')
        ..levelStars[3] = 2
        ..levelBest[3] = 999;
      await repo.save(p);
      final back = PlayerRepository(store).load();
      expect(back.coins, 321);
      expect(back.currentLevel, 7);
      expect(back.highestUnlocked, 9);
      expect(back.shields, 2);
      expect(back.selectedSkin, 'neon');
      expect(back.ownedSkins, containsAll(['neon', SkinCatalog.defaultSkinId]));
      expect(back.levelStars[3], 2);
      expect(back.levelBest[3], 999);
    });

    test('corrupted data falls back to defaults', () async {
      final store = MemoryStore();
      await store.setString(PlayerRepository.key, '{not json');
      expect(PlayerRepository(store).load().coins, 0);
    });

    test('settings survive a save/load cycle', () async {
      final store = MemoryStore();
      final repo = SettingsRepository(store);
      await repo.save(const GameSettings(
          music: false, quality: GraphicsQuality.low, sensitivity: 1.6, mode: InputMode.smash, reduceMotion: true));
      final s = SettingsRepository(store).load();
      expect(s.music, isFalse);
      expect(s.quality, GraphicsQuality.low);
      expect(s.sensitivity, 1.6);
      expect(s.mode, InputMode.smash);
      expect(s.reduceMotion, isTrue);
    });
  });
}
