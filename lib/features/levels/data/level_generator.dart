import 'dart:math' as math;

import '../../../app/theme/colors.dart';
import '../../../core/constants/game_constants.dart';
import '../../../core/enums/game_enums.dart';
import '../../../core/utils/angle_utils.dart';
import '../../../core/utils/seeded_random.dart';
import '../../gameplay/domain/level_config.dart';

/// Pure, deterministic procedural level generator. `generate(n, mode)` always returns the same tower.
class LevelGenerator {
  /// Levels shown in the level map. The generator itself supports any positive level.
  static const int levelCount = 300;

  final Map<String, LevelConfig> _cache = {};

  // The seed namespace keeps the game's original working title on purpose: changing it would reshuffle
  // every level layout for existing players.
  static int seedFor(int level, InputMode mode) => fnv1a('spiral-plunge/${mode.name}/$level');

  static Difficulty difficultyFor(int level) {
    if (level <= 10) return Difficulty.easy;
    if (level <= 40) return Difficulty.normal;
    if (level <= 110) return Difficulty.hard;
    if (level <= 200) return Difficulty.expert;
    return Difficulty.insane;
  }

  /// 0..1 difficulty curve with a gentle "breather" after every boss level (multiples of 10).
  static double curve(int level) {
    final base = ((level - 1) / 160).clamp(0.0, 1.0);
    final eased = 1 - math.pow(1 - base, 1.6).toDouble();
    final breather = level % 10 == 1 && level > 1 ? 0.06 : 0.0;
    return (eased - breather).clamp(0.0, 1.0);
  }

  static bool isBossLevel(int level) => level % 10 == 0;

  LevelConfig generate(int level, InputMode mode) {
    assert(level >= 1);
    final key = '${mode.name}:$level';
    return _cache.putIfAbsent(key, () => mode == InputMode.spin ? _spin(level) : _smash(level));
  }

  // ------------------------------------------------------------------ spin mode

  LevelConfig _spin(int level) {
    final seed = seedFor(level, InputMode.spin);
    final rng = SeededRandom(seed);
    final t = curve(level);
    final boss = isBossLevel(level);
    final floorCount = ((12 + level * 0.32).round().clamp(12, 56) + rng.range(-1, 2) + (boss ? 6 : 0)).clamp(10, 64);
    const n = GameConstants.slotsPerFloor;
    const d = GameConstants.slotAngle;

    final floors = <FloorSpec>[];
    double prevGapCentre = 0;
    for (var i = 0; i < floorCount; i++) {
      final p = floorCount <= 1 ? 0.0 : i / (floorCount - 1);
      // gap width
      int gap;
      if (level <= 3 || i == 0) {
        gap = 4;
      } else {
        gap = (3.3 - 1.4 * t - 0.5 * p + (boss ? -0.3 : 0)).round().clamp(2, 4);
      }
      // where the gap's centre lies (floor-local angle relative to a fixed tower)
      double gapCentre;
      if (i == 0) {
        gapCentre = math.pi / 2; // ball starts on solid ground, the gap is a quarter turn away
      } else if (rng.chance(0.38 - 0.2 * t)) {
        gapCentre = prevGapCentre + rng.between(-0.6, 0.6) * d; // "chute": rewarding combo line
      } else {
        gapCentre = prevGapCentre + (rng.chance(0.5) ? -1 : 1) * math.pi * rng.between(0.35, 0.9);
      }
      final offset = AngleUtils.wrap(gapCentre - gap * d / 2);
      final slots = List<SegmentType>.filled(n, SegmentType.safe);
      for (var s = 0; s < gap; s++) {
        slots[s] = SegmentType.gap;
      }

      // landing zone below the previous floor's gap must stay hazard-free
      final protected = <int>{};
      if (i == 0) {
        protected.add(_slotAt(offset, AngleUtils.wrap(GameConstants.ballWorldAngle)));
      } else {
        final prev = floors[i - 1];
        for (var s = 0; s < n; s++) {
          if (prev.slots[s] != SegmentType.gap) continue;
          final a = prev.offset + (s + 0.5) * d;
          final idx = _slotAt(offset, a);
          protected.add(idx);
          if (level < 30) {
            protected.add((idx + 1) % n);
            protected.add((idx + n - 1) % n);
          }
        }
      }

      List<int> candidates() {
        final out = <int>[];
        final edgeOk = t > 0.4;
        for (var s = gap; s < n; s++) {
          if (slots[s] != SegmentType.safe || protected.contains(s)) continue;
          if (!edgeOk && (s == gap || s == n - 1)) continue;
          out.add(s);
        }
        return out;
      }

      // dangers
      if (level > 2 && i > 0) {
        final dMax = (1 + 4 * t + p * 1.2 + (boss ? 1 : 0)).round().clamp(0, 6);
        final dMin = (dMax - 2).clamp(0, dMax);
        final count = rng.range(dMin, dMax);
        for (var k = 0; k < count; k++) {
          final c = candidates();
          if (c.isEmpty) break;
          final s = c[rng.nextInt(c.length)];
          slots[s] = SegmentType.danger;
          final nxt = s + 1;
          if (t > 0.25 && nxt < n && rng.chance(0.3 + 0.2 * t) && slots[nxt] == SegmentType.safe &&
              !protected.contains(nxt)) {
            slots[nxt] = SegmentType.danger;
          }
        }
      }

      // blink hazards
      BlinkSpec? blink;
      if (level >= 8 && i > 0 && rng.chance(0.1 + 0.18 * t)) {
        final c = candidates();
        final k = t > 0.6 ? 2 : 1;
        for (var j = 0; j < k && c.isNotEmpty; j++) {
          slots[c.removeAt(rng.nextInt(c.length))] = SegmentType.blink;
        }
        final period = 2.2 - 0.6 * t;
        blink = BlinkSpec(period: period, phase: rng.between(0, period), duty: 0.5);
      }

      // sweeper arm
      SweeperSpec? sweeper;
      if (level >= 15 && i > 1 && rng.chance(0.07 + 0.16 * t)) {
        sweeper = SweeperSpec(
          start: rng.between(0, AngleUtils.tau),
          width: d * 1.25,
          speed: (0.6 + rng.between(0, 0.6) + 0.4 * t) * (rng.chance(0.5) ? -1 : 1),
        );
      }

      // breakable and bonus slots
      if (level >= 5 && i > 0 && rng.chance(0.22)) {
        final c = candidates();
        for (var j = 0; j < rng.range(1, 2) && c.isNotEmpty; j++) {
          slots[c.removeAt(rng.nextInt(c.length))] = SegmentType.breakable;
        }
      }
      if (rng.chance(0.16)) {
        final c = candidates();
        if (c.isNotEmpty) slots[c[rng.nextInt(c.length)]] = SegmentType.bonus;
      }

      // Fairness: always leave room to bounce (≥ 4 contiguous non-hazard slots).
      while (LevelValidator.longestSafeArc(slots) < 4) {
        final hazards = [
          for (var s = 0; s < n; s++)
            if (slots[s] == SegmentType.danger || slots[s] == SegmentType.blink) s
        ];
        if (hazards.isEmpty) break;
        slots[hazards[rng.nextInt(hazards.length)]] = SegmentType.safe;
      }
      if (!slots.contains(SegmentType.blink)) blink = null;

      floors.add(FloorSpec(index: i, offset: offset, slots: slots, blink: blink, sweeper: sweeper));
      prevGapCentre = gapCentre;
    }

    return LevelConfig(
      levelId: level,
      seed: seed,
      mode: InputMode.spin,
      difficulty: difficultyFor(level),
      floors: floors,
      themeIndex: (level - 1) % GameThemes.all.length,
      rotationSpeed: 0,
      rotationDirection: 1,
      scoreMultiplier: 1 + (level ~/ 25) * 0.1,
      reward: RewardConfig(baseCoins: 10 + level ~/ 5, firstClearBonus: 25 + level, coinsPerScore: 25),
      parScore: (floorCount * 26 * (1 + (level ~/ 25) * 0.1)).round() + ScoringRules.levelComplete(level),
      gravity: GameConstants.gravity * (1 + 0.08 * t),
      bounceVelocity: GameConstants.bounceVelocity * (1 + 0.03 * t),
    );
  }

  // ------------------------------------------------------------------ smash mode

  LevelConfig _smash(int level) {
    final seed = seedFor(level, InputMode.smash);
    final rng = SeededRandom(seed);
    final t = curve(level);
    final boss = isBossLevel(level);
    final floorCount = ((20 + level * 0.45).round().clamp(20, 80) + rng.range(-2, 2) + (boss ? 8 : 0)).clamp(16, 90);
    const n = GameConstants.slotsPerFloor;
    final floors = <FloorSpec>[];
    for (var i = 0; i < floorCount; i++) {
      final slots = List<SegmentType>.filled(n, SegmentType.safe);
      final calm = i == 0 || (level < 15 && i % 4 == 0) || i == floorCount - 1;
      if (level > 1 && !calm) {
        final arcs = rng.range(t < 0.3 ? 0 : 1, t < 0.5 ? 1 : 2);
        final maxLen = (3 + 5 * t).round();
        var start = rng.nextInt(n);
        for (var a = 0; a < arcs; a++) {
          final len = rng.range(2, maxLen);
          for (var k = 0; k < len; k++) {
            slots[(start + k) % n] = SegmentType.danger;
          }
          start = (start + len + rng.range(5, 8)) % n;
        }
        // guarantee a wide safe window (≥ 6 contiguous slots)
        _ensureSafeWindow(slots, 6);
      }
      if (rng.chance(0.14)) {
        final safe = [for (var s = 0; s < n; s++) if (slots[s] == SegmentType.safe) s];
        if (safe.isNotEmpty) slots[safe[rng.nextInt(safe.length)]] = SegmentType.bonus;
      }
      floors.add(FloorSpec(index: i, offset: rng.between(0, AngleUtils.tau), slots: slots));
    }
    return LevelConfig(
      levelId: level,
      seed: seed,
      mode: InputMode.smash,
      difficulty: difficultyFor(level),
      floors: floors,
      themeIndex: (level - 1) % GameThemes.all.length,
      rotationSpeed: 1.3 + 1.5 * t + rng.between(0, 0.4),
      rotationDirection: rng.chance(0.5) ? 1 : -1,
      scoreMultiplier: 1 + (level ~/ 25) * 0.1,
      reward: RewardConfig(baseCoins: 10 + level ~/ 5, firstClearBonus: 25 + level, coinsPerScore: 25),
      parScore: (floorCount * 22 * (1 + (level ~/ 25) * 0.1)).round() + ScoringRules.levelComplete(level),
    );
  }

  static void _ensureSafeWindow(List<SegmentType> slots, int window) {
    final n = slots.length;
    if (LevelValidator.longestSafeArc(slots) >= window) return;
    // clear a window starting at a deterministic position (first danger)
    final start = slots.indexOf(SegmentType.danger);
    for (var k = 0; k < window; k++) {
      slots[(start + k) % n] = SegmentType.safe;
    }
  }

  static int _slotAt(double floorOffset, double localAngle) =>
      (AngleUtils.wrap(localAngle - floorOffset) / GameConstants.slotAngle).floor() % GameConstants.slotsPerFloor;
}

/// Checks the fairness guarantees every generated level must satisfy.
abstract final class LevelValidator {
  static bool _hazard(SegmentType s) => s == SegmentType.danger || s == SegmentType.blink;

  static int longestSafeArc(List<SegmentType> slots) {
    final n = slots.length;
    var best = 0, run = 0;
    for (var k = 0; k < n * 2; k++) {
      if (_hazard(slots[k % n])) {
        run = 0;
      } else {
        run++;
        best = math.max(best, run);
      }
    }
    return math.min(best, n);
  }

  /// Returns a list of human-readable problems (empty = solvable).
  static List<String> problems(LevelConfig c) {
    final out = <String>[];
    const d = GameConstants.slotAngle;
    if (c.floors.isEmpty) out.add('no floors');
    for (var i = 0; i < c.floors.length; i++) {
      final f = c.floors[i];
      if (f.slots.length != GameConstants.slotsPerFloor) out.add('floor $i: wrong slot count');
      if (c.mode == InputMode.spin) {
        if (!f.slots.contains(SegmentType.gap)) out.add('floor $i: no gap');
        if (i == 0) {
          final s = LevelGenerator._slotAt(f.offset, GameConstants.ballWorldAngle);
          if (_hazard(f.slots[s]) || f.slots[s] == SegmentType.gap) out.add('floor 0: unsafe start');
        } else {
          final prev = c.floors[i - 1];
          for (var s = 0; s < prev.slots.length; s++) {
            if (prev.slots[s] != SegmentType.gap) continue;
            final idx = LevelGenerator._slotAt(f.offset, prev.offset + (s + 0.5) * d);
            if (_hazard(f.slots[idx])) out.add('floor $i: hazard in landing zone (slot $idx)');
          }
        }
        if (longestSafeArc(f.slots) < 3) out.add('floor $i: no room to bounce');
      } else {
        if (f.slots.contains(SegmentType.gap)) out.add('floor $i: smash floors must be solid');
        if (longestSafeArc(f.slots) < 6) out.add('floor $i: safe window too small');
      }
    }
    return out;
  }

  static bool isSolvable(LevelConfig c) => problems(c).isEmpty;
}
