import '../../shop/data/skin_catalog.dart';

/// Everything that must survive an app restart about the player's progress.
class PlayerProfile {
  PlayerProfile({
    this.currentLevel = 1,
    this.highestUnlocked = 1,
    Map<int, int>? levelStars,
    Map<int, int>? levelBest,
    this.bestScore = 0,
    this.bestCombo = 0,
    this.coins = 0,
    Set<String>? ownedSkins,
    this.selectedSkin = SkinCatalog.defaultSkinId,
    this.shields = 0,
    this.lastDailyClaim,
    this.dailyStreak = 0,
    List<String>? rewardedRuns,
    this.totalRuns = 0,
  })  : levelStars = levelStars ?? {},
        levelBest = levelBest ?? {},
        ownedSkins = ownedSkins ?? {SkinCatalog.defaultSkinId},
        rewardedRuns = rewardedRuns ?? [];

  int currentLevel;
  int highestUnlocked;
  final Map<int, int> levelStars;
  final Map<int, int> levelBest;
  int bestScore;
  int bestCombo;
  int coins;
  final Set<String> ownedSkins;
  String selectedSkin;
  int shields;

  /// ISO date (yyyy-mm-dd) of the last daily reward claim.
  String? lastDailyClaim;
  int dailyStreak;

  /// Run ids that already paid out (guards against duplicate rewards). Bounded to the latest 64.
  final List<String> rewardedRuns;
  int totalRuns;

  bool isCompleted(int level) => levelStars.containsKey(level);
  Set<int> get completedLevels => levelStars.keys.toSet();

  Map<String, dynamic> toJson() => {
        'v': 1,
        'currentLevel': currentLevel,
        'highestUnlocked': highestUnlocked,
        'levelStars': levelStars.map((k, v) => MapEntry('$k', v)),
        'levelBest': levelBest.map((k, v) => MapEntry('$k', v)),
        'bestScore': bestScore,
        'bestCombo': bestCombo,
        'coins': coins,
        'ownedSkins': ownedSkins.toList(),
        'selectedSkin': selectedSkin,
        'shields': shields,
        'lastDailyClaim': lastDailyClaim,
        'dailyStreak': dailyStreak,
        'rewardedRuns': rewardedRuns,
        'totalRuns': totalRuns,
      };

  factory PlayerProfile.fromJson(Map<String, dynamic> j) {
    Map<int, int> intMap(Object? m) => m is Map
        ? {for (final e in m.entries) int.tryParse('${e.key}') ?? 0: (e.value as num).toInt()}
        : <int, int>{};
    return PlayerProfile(
      currentLevel: (j['currentLevel'] as num?)?.toInt() ?? 1,
      highestUnlocked: (j['highestUnlocked'] as num?)?.toInt() ?? 1,
      levelStars: intMap(j['levelStars']),
      levelBest: intMap(j['levelBest']),
      bestScore: (j['bestScore'] as num?)?.toInt() ?? 0,
      bestCombo: (j['bestCombo'] as num?)?.toInt() ?? 0,
      coins: (j['coins'] as num?)?.toInt() ?? 0,
      ownedSkins: ((j['ownedSkins'] as List?)?.cast<String>().toSet() ?? {})..add(SkinCatalog.defaultSkinId),
      selectedSkin: j['selectedSkin'] as String? ?? SkinCatalog.defaultSkinId,
      shields: (j['shields'] as num?)?.toInt() ?? 0,
      lastDailyClaim: j['lastDailyClaim'] as String?,
      dailyStreak: (j['dailyStreak'] as num?)?.toInt() ?? 0,
      rewardedRuns: (j['rewardedRuns'] as List?)?.cast<String>().toList(),
      totalRuns: (j['totalRuns'] as num?)?.toInt() ?? 0,
    );
  }
}
