import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/features/gameplay/engine/game_state_machine.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  GameStateMachine playing() {
    final m = GameStateMachine();
    for (final s in [GamePhase.loading, GamePhase.ready, GamePhase.intro, GamePhase.playing]) {
      expect(m.transition(s), isTrue, reason: '→ ${s.name}');
    }
    return m;
  }

  test('happy path to playing and through gameplay sub-states', () {
    final m = playing();
    expect(m.transition(GamePhase.falling), isTrue);
    expect(m.transition(GamePhase.bouncing), isTrue);
    expect(m.transition(GamePhase.falling), isTrue);
    expect(m.transition(GamePhase.combo), isTrue);
    expect(m.transition(GamePhase.destruction), isTrue);
    expect(m.transition(GamePhase.falling), isTrue);
    expect(m.transition(GamePhase.levelCompleted), isTrue);
    expect(m.transition(GamePhase.restarting), isTrue);
    expect(m.transition(GamePhase.ready), isTrue);
  });

  test('invalid transitions are rejected and state is unchanged', () {
    final m = GameStateMachine();
    expect(m.transition(GamePhase.playing), isFalse);
    expect(m.state, GamePhase.initializing);
    final p = playing();
    expect(p.transition(GamePhase.loading), isFalse);
    expect(p.transition(GamePhase.ready), isFalse);
    p.transition(GamePhase.bouncing);
    expect(p.transition(GamePhase.levelCompleted), isFalse, reason: 'cannot finish while moving up');
    expect(p.state, GamePhase.bouncing);
  });

  test('pause remembers and restores the interrupted sub-state', () {
    final m = playing()..transition(GamePhase.combo);
    expect(m.pause(), isTrue);
    expect(m.state, GamePhase.paused);
    expect(m.pause(), isFalse);
    expect(m.transition(GamePhase.falling), isFalse, reason: 'paused world cannot advance');
    expect(m.resume(), isTrue);
    expect(m.state, GamePhase.combo);
  });

  test('game over allows revive or restart only', () {
    final m = playing()..transition(GamePhase.falling)..transition(GamePhase.gameOver);
    expect(m.transition(GamePhase.levelCompleted), isFalse);
    expect(m.transition(GamePhase.playing), isTrue);
    m
      ..transition(GamePhase.falling)
      ..transition(GamePhase.gameOver);
    expect(m.transition(GamePhase.restarting), isTrue);
  });

  test('listeners receive transitions', () {
    final seen = <String>[];
    final m = GameStateMachine()..addListener((a, b) => seen.add('${a.name}>${b.name}'));
    m.transition(GamePhase.loading);
    m.transition(GamePhase.playing); // rejected
    expect(seen, ['initializing>loading']);
  });
}
