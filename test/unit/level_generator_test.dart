import 'dart:convert';

import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/features/gameplay/domain/level_config.dart';
import 'package:ball_stack/features/levels/data/level_generator.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final gen = LevelGenerator();

  for (final mode in InputMode.values) {
    test('all ${LevelGenerator.levelCount} ${mode.name} levels are solvable', () {
      for (var l = 1; l <= LevelGenerator.levelCount; l++) {
        final c = gen.generate(l, mode);
        final problems = LevelValidator.problems(c);
        expect(problems, isEmpty, reason: 'level $l: $problems');
      }
    });
  }

  test('generation is deterministic (same seed ⇒ same tower)', () {
    final a = jsonEncode(LevelGenerator().generate(57, InputMode.spin).toJson());
    final b = jsonEncode(LevelGenerator().generate(57, InputMode.spin).toJson());
    expect(a, b);
    expect(LevelGenerator.seedFor(57, InputMode.spin), isNot(LevelGenerator.seedFor(58, InputMode.spin)));
  });

  test('LevelConfig JSON round-trip', () {
    final c = gen.generate(120, InputMode.spin);
    final back = LevelConfig.fromJson(jsonDecode(jsonEncode(c.toJson())) as Map<String, dynamic>);
    expect(jsonEncode(back.toJson()), jsonEncode(c.toJson()));
  });

  test('difficulty ramps up: taller towers and more hazards later', () {
    int dangers(int from, int to) {
      var n = 0;
      for (var l = from; l <= to; l++) {
        n += gen.generate(l, InputMode.spin).dangerSlots;
      }
      return n;
    }

    expect(gen.generate(1, InputMode.spin).dangerSlots, 0);
    expect(gen.generate(200, InputMode.spin).floorCount, greaterThan(gen.generate(5, InputMode.spin).floorCount));
    expect(dangers(150, 160), greaterThan(dangers(3, 13)));
    // mechanics are introduced gradually
    bool hasBlink(int l) => gen.generate(l, InputMode.spin).floors.any((f) => f.blink != null);
    bool hasSweeper(int l) => gen.generate(l, InputMode.spin).floors.any((f) => f.sweeper != null);
    expect(List.generate(7, (i) => hasBlink(i + 1)).any((b) => b), isFalse);
    expect(List.generate(14, (i) => hasSweeper(i + 1)).any((b) => b), isFalse);
    expect(List.generate(60, (i) => hasSweeper(i + 100)).any((b) => b), isTrue);
  });

  test('smash mode floors are solid with a safe window', () {
    final c = gen.generate(80, InputMode.smash);
    for (final f in c.floors) {
      expect(f.slots.contains(SegmentType.gap), isFalse);
      expect(LevelValidator.longestSafeArc(f.slots), greaterThanOrEqualTo(6));
    }
  });
}
