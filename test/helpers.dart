import 'package:ball_stack/core/constants/game_constants.dart';
import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/features/gameplay/domain/game_event.dart';
import 'package:ball_stack/features/gameplay/domain/level_config.dart';
import 'package:ball_stack/features/gameplay/engine/simulation.dart';

/// Builds a level from compact floor strings: one char per slot (16 chars), e.g.
/// `'S'` safe, `'G'` gap, `'D'` danger, `'B'` breakable, `'$'` bonus, `'K'` blink.
/// The ball sits over slot 0 when the tower angle is 0 and offsets are 0.
LevelConfig testLevel(List<String> floors, {InputMode mode = InputMode.spin, int id = 1, BlinkSpec? blink,
    SweeperSpec? sweeper}) {
  SegmentType parse(String c) => switch (c) {
        'S' => SegmentType.safe,
        'G' => SegmentType.gap,
        'D' => SegmentType.danger,
        'B' => SegmentType.breakable,
        '\$' => SegmentType.bonus,
        'K' => SegmentType.blink,
        _ => throw ArgumentError(c),
      };
  return LevelConfig(
    levelId: id,
    seed: 1,
    mode: mode,
    difficulty: Difficulty.easy,
    floors: [
      for (var i = 0; i < floors.length; i++)
        FloorSpec(
          index: i,
          offset: 0,
          slots: floors[i].padRight(16, 'S').split('').map(parse).toList(),
          blink: floors[i].contains('K') ? blink : null,
          sweeper: i == 0 ? sweeper : null,
        ),
    ],
    themeIndex: 0,
    rotationSpeed: 0,
    rotationDirection: 1,
    scoreMultiplier: 1,
    reward: const RewardConfig(baseCoins: 10, firstClearBonus: 26, coinsPerScore: 25),
    parScore: 300,
  );
}

const String allSafe = 'SSSSSSSSSSSSSSSS';
const String gapUnderBall = 'GGGSSSSSSSSSSSSS';
const String dangerUnderBall = 'DDDSSSSSSSSSSSSS';

/// Runs the simulation until an event of [type] appears (or [maxSeconds] elapse).
GameEvent? runUntil(Simulation sim, GameEventType type, {double maxSeconds = 6, InputFrame? input}) {
  final frame = input ?? InputFrame();
  final steps = (maxSeconds / GameConstants.fixedStep).ceil();
  for (var i = 0; i < steps; i++) {
    for (final e in sim.step(GameConstants.fixedStep, frame)) {
      if (e.type == type) return e;
    }
    if (sim.over && type != GameEventType.death && type != GameEventType.levelComplete) return null;
  }
  return null;
}

List<GameEvent> runFor(Simulation sim, double seconds, {InputFrame? input}) {
  final frame = input ?? InputFrame();
  final out = <GameEvent>[];
  final steps = (seconds / GameConstants.fixedStep).ceil();
  for (var i = 0; i < steps; i++) {
    out.addAll(sim.step(GameConstants.fixedStep, frame));
  }
  return out;
}
