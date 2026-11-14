import 'dart:math' as math;

import '../../gameplay/domain/game_event.dart';
import '../../gameplay/domain/level_config.dart';
import '../../levels/data/level_generator.dart';
import '../../shop/data/skin_catalog.dart';
import 'player_profile.dart';

/// Coins paid out for one run.
class RunReward {
  const RunReward({
    required this.scoreCoins,
    required this.bonusCoins,
    required this.comboCoins,
    required this.firstClearCoins,
    required this.stars,
    required this.newBest,
    required this.alreadyRewarded,
  });

  final int scoreCoins;
  final int bonusCoins;
  final int comboCoins;
  final int firstClearCoins;
  final int stars;
  final bool newBest;
  final bool alreadyRewarded;

  int get total => scoreCoins + bonusCoins + comboCoins + firstClearCoins;

  static const none = RunReward(
      scoreCoins: 0, bonusCoins: 0, comboCoins: 0, firstClearCoins: 0, stars: 0, newBest: false, alreadyRewarded: true);
}

enum PurchaseResult { purchased, selected, insufficientCoins, maxReached }

/// Pure progression rules operating on a [PlayerProfile] (persistence is the caller's job).
class ProgressionService {
  static const int maxShields = 3;
  static const int shieldPrice = 120;

  static int stars(int score, int par, bool won) {
    if (!won) return 0;
    if (score >= par) return 3;
    if (score >= par * 0.6) return 2;
    return 1;
  }

  static int reviveCost(int level) => 60 + level * 2;

  /// Applies a finished run. Idempotent per `runId` — calling twice never pays twice.
  static RunReward applyRun(PlayerProfile p, RunResult r, LevelConfig level) {
    if (p.rewardedRuns.contains(r.runId)) return RunReward.none;
    p.rewardedRuns.add(r.runId);
    if (p.rewardedRuns.length > 64) p.rewardedRuns.removeRange(0, p.rewardedRuns.length - 64);
    p.totalRuns++;

    final newBest = r.score > p.bestScore;
    p.bestScore = math.max(p.bestScore, r.score);
    p.bestCombo = math.max(p.bestCombo, r.bestCombo);
    p.levelBest[r.levelId] = math.max(p.levelBest[r.levelId] ?? 0, r.score);

    final scoreCoins = r.won ? level.reward.baseCoins + r.score ~/ level.reward.coinsPerScore : r.score ~/ (level.reward.coinsPerScore * 3);
    final comboCoins = r.won ? r.bestCombo : 0;
    var firstClear = 0;
    var stars = 0;
    if (r.won) {
      stars = ProgressionService.stars(r.score, level.parScore, true);
      if (!p.isCompleted(r.levelId)) firstClear = level.reward.firstClearBonus;
      p.levelStars[r.levelId] = math.max(p.levelStars[r.levelId] ?? 0, stars);
      final next = math.min(r.levelId + 1, LevelGenerator.levelCount);
      p.highestUnlocked = math.max(p.highestUnlocked, next);
      if (p.currentLevel == r.levelId) p.currentLevel = next;
    }
    final reward = RunReward(
      scoreCoins: scoreCoins,
      bonusCoins: r.bonusCoins,
      comboCoins: comboCoins,
      firstClearCoins: firstClear,
      stars: stars,
      newBest: newBest,
      alreadyRewarded: false,
    );
    p.coins += reward.total;
    return reward;
  }

  static PurchaseResult buyOrSelectSkin(PlayerProfile p, String skinId) {
    final skin = SkinCatalog.byId(skinId);
    if (p.ownedSkins.contains(skin.id)) {
      p.selectedSkin = skin.id;
      return PurchaseResult.selected;
    }
    if (p.coins < skin.price) return PurchaseResult.insufficientCoins;
    p.coins -= skin.price;
    p.ownedSkins.add(skin.id);
    p.selectedSkin = skin.id;
    return PurchaseResult.purchased;
  }

  static PurchaseResult buyShield(PlayerProfile p) {
    if (p.shields >= maxShields) return PurchaseResult.maxReached;
    if (p.coins < shieldPrice) return PurchaseResult.insufficientCoins;
    p.coins -= shieldPrice;
    p.shields++;
    return PurchaseResult.purchased;
  }

  static bool spend(PlayerProfile p, int amount) {
    if (p.coins < amount) return false;
    p.coins -= amount;
    return true;
  }

  // ---- daily reward

  static String dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  static bool canClaimDaily(PlayerProfile p, DateTime now) => p.lastDailyClaim != dateKey(now);

  /// Streak day (1..7) that would be paid today.
  static int nextStreakDay(PlayerProfile p, DateTime now) {
    final yesterday = dateKey(DateTime(now.year, now.month, now.day - 1));
    final continues = p.lastDailyClaim == yesterday;
    return continues ? (p.dailyStreak % 7) + 1 : 1;
  }

  static int dailyAmount(int streakDay) => 50 + (streakDay - 1) * 25 + (streakDay == 7 ? 100 : 0);

  /// Returns coins granted (0 if already claimed today).
  static int claimDaily(PlayerProfile p, DateTime now) {
    if (!canClaimDaily(p, now)) return 0;
    final day = nextStreakDay(p, now);
    final amount = dailyAmount(day);
    p.dailyStreak = day;
    p.lastDailyClaim = dateKey(now);
    p.coins += amount;
    return amount;
  }
}
