import 'package:ball_stack/core/constants/game_constants.dart';
import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/features/gameplay/domain/game_event.dart';
import 'package:ball_stack/features/gameplay/domain/level_config.dart';
import 'package:ball_stack/features/gameplay/engine/collision_system.dart';
import 'package:ball_stack/features/gameplay/engine/simulation.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

void main() {
  group('ball physics', () {
    test('falls under gravity using delta time (frame-rate independent)', () {
      final a = Simulation(testLevel([allSafe]));
      final b = Simulation(testLevel([allSafe]));
      final y0 = a.ball.y;
      // 0.2 s as 24 steps of 1/120 vs. the same duration — identical because the step is fixed.
      runFor(a, 0.2);
      runFor(b, 0.2);
      expect(a.ball.y, lessThan(y0));
      expect(a.ball.y, b.ball.y);
      expect(a.ball.vy, closeTo(-GameConstants.gravity * 0.2, 0.5));
    });

    test('terminal velocity is respected', () {
      final sim = Simulation(testLevel([gapUnderBall, gapUnderBall, gapUnderBall, gapUnderBall, gapUnderBall]));
      runFor(sim, 1.5);
      expect(sim.ball.vy, greaterThanOrEqualTo(-GameConstants.terminalVelocity));
    });
  });

  group('collisions (spin mode)', () {
    test('lands on a safe platform and bounces', () {
      final sim = Simulation(testLevel([allSafe]));
      final e = runUntil(sim, GameEventType.bounce);
      expect(e, isNotNull);
      expect(sim.ball.vy, closeTo(sim.level.bounceVelocity, 1e-9));
      expect(sim.ball.bottom, closeTo(sim.level.floorTop(0), 1e-9));
      expect(sim.over, isFalse);
    });

    test('falls through a valid opening and scores the floor', () {
      final sim = Simulation(testLevel([gapUnderBall, allSafe]));
      final e = runUntil(sim, GameEventType.floorPassed);
      expect(e, isNotNull);
      expect(e!.floor, 0);
      expect(e.chain, 1);
      expect(e.points, ScoringRules.passPoints(1));
      expect(sim.floor, 1);
      expect(sim.floorStates[0].broken, isTrue);
    });

    test('dangerous segment ends the run', () {
      final sim = Simulation(testLevel([dangerUnderBall]));
      final e = runUntil(sim, GameEventType.death);
      expect(e, isNotNull);
      expect(e!.cause, 'danger');
      expect(sim.over, isTrue);
      expect(sim.won, isFalse);
    });

    test('rotating the tower moves a gap under the ball', () {
      // Slot 4 is a gap; rotate so the ball's local angle falls into slot 4.
      final sim = Simulation(testLevel(['SSSSGSSSSSSSSSSS', allSafe]));
      final frame = InputFrame()..dragDelta = 0;
      // local = -angle → want local in slot 4 = [4Δ,5Δ): angle = -(4.5Δ)
      sim.rotation.angle = -(4.5 * GameConstants.slotAngle);
      expect(runUntil(sim, GameEventType.floorPassed, input: frame), isNotNull);
    });

    test('several floors crossed in one step are resolved in order (no tunnelling)', () {
      final sim = Simulation(testLevel([gapUnderBall, gapUnderBall, gapUnderBall, allSafe]));
      final events = <GameEvent>[];
      for (var i = 0; i < 40; i++) {
        events.addAll(sim.step(0.05, InputFrame())); // large steps
      }
      final passed = events.where((e) => e.type == GameEventType.floorPassed).map((e) => e.floor).toList();
      expect(passed, [0, 1, 2]);
      // three drops arm smash mode, so floor 3 is smashed rather than bounced on
      expect(events.any((e) => e.type == GameEventType.smashed && e.floor == 3), isTrue);
    });

    test('breakable segment breaks on bounce and becomes a gap', () {
      final sim = Simulation(testLevel(['BBBSSSSSSSSSSSSS', allSafe]));
      final e = runUntil(sim, GameEventType.segmentBroken);
      expect(e, isNotNull);
      expect(sim.floorStates[0].destroyed[e!.slot], isTrue);
      expect(runUntil(sim, GameEventType.floorPassed), isNotNull);
    });

    test('bonus coin is collected only once', () {
      final sim = Simulation(testLevel(['\$\$\$SSSSSSSSSSSSS']));
      final events = runFor(sim, 4);
      expect(events.where((e) => e.type == GameEventType.bonusCollected).length, 1);
      expect(sim.bonusCoins, 1);
    });

    test('shield absorbs one hazard hit', () {
      final sim = Simulation(testLevel([dangerUnderBall]), shields: 1);
      expect(runUntil(sim, GameEventType.shieldUsed), isNotNull);
      expect(sim.over, isFalse);
      expect(sim.shields, 0);
      expect(runUntil(sim, GameEventType.death), isNotNull);
    });

    test('blink slots are lethal only while active', () {
      // Blink never active (duty 0) → safe.
      final off = Simulation(testLevel(['KKKSSSSSSSSSSSSS'], blink: const BlinkSpec(period: 1, phase: 0, duty: 0)));
      expect(runUntil(off, GameEventType.bounce), isNotNull);
      final on = Simulation(testLevel(['KKKSSSSSSSSSSSSS'], blink: const BlinkSpec(period: 1, phase: 0, duty: 1)));
      expect(runUntil(on, GameEventType.death)?.cause, 'blink');
    });
  });

  group('combo and smash', () {
    test('three consecutive drops arm smash mode; next landing smashes even a hazard', () {
      final sim = Simulation(testLevel([gapUnderBall, gapUnderBall, gapUnderBall, dangerUnderBall, allSafe]));
      expect(runUntil(sim, GameEventType.smashReady), isNotNull);
      expect(sim.combo.chain, 3);
      final smash = runUntil(sim, GameEventType.smashed);
      expect(smash, isNotNull);
      expect(smash!.floor, 3);
      expect(sim.over, isFalse);
      expect(sim.combo.smashReady, isFalse);
      expect(sim.combo.chain, 0);
      expect(sim.combo.maxCombo, 4);
    });

    test('combo resets on bounce and multiplier grows with chain', () {
      final sim = Simulation(testLevel([gapUnderBall, gapUnderBall, allSafe]));
      final events = runFor(sim, 3);
      final passes = events.where((e) => e.type == GameEventType.floorPassed).toList();
      expect(passes.map((e) => e.points), [10, 20]);
      expect(events.any((e) => e.type == GameEventType.comboReset && e.chain == 2), isTrue);
      expect(sim.combo.chain, 0);
    });

    test('score is never awarded twice for the same floor', () {
      final sim = Simulation(testLevel([gapUnderBall, allSafe]));
      final events = runFor(sim, 5);
      expect(events.where((e) => e.type == GameEventType.floorPassed && e.floor == 0).length, 1);
    });
  });

  group('level end', () {
    test('passing the last floor and reaching the base completes the level', () {
      final sim = Simulation(testLevel([gapUnderBall, gapUnderBall]));
      final e = runUntil(sim, GameEventType.levelComplete);
      expect(e, isNotNull);
      expect(sim.won, isTrue);
      expect(sim.over, isTrue);
      expect(sim.floorsCleared, 2);
      expect(e!.points, ScoringRules.levelComplete(1));
    });

    test('revive continues a failed run with grace period', () {
      final sim = Simulation(testLevel([dangerUnderBall, allSafe]));
      runUntil(sim, GameEventType.death);
      expect(sim.canRevive, isTrue);
      sim.revive();
      expect(sim.over, isFalse);
      expect(sim.grace, greaterThan(0));
      expect(runUntil(sim, GameEventType.bounce, maxSeconds: 1.5), isNotNull, reason: 'hazard is safe during grace');
    });
  });

  group('smash mode', () {
    InputFrame hold() => InputFrame()..holding = true;

    test('holding smashes a safe ring', () {
      final sim = Simulation(testLevel([allSafe, allSafe], mode: InputMode.smash));
      final e = runUntil(sim, GameEventType.ringSmashed, input: hold());
      expect(e, isNotNull);
      expect(sim.floorStates[0].broken, isTrue);
    });

    test('released ball bounces even on danger', () {
      final sim = Simulation(testLevel([dangerUnderBall], mode: InputMode.smash));
      expect(runUntil(sim, GameEventType.bounce), isNotNull);
      expect(sim.over, isFalse);
    });

    test('holding into danger kills', () {
      final sim = Simulation(testLevel([dangerUnderBall], mode: InputMode.smash));
      expect(runUntil(sim, GameEventType.death, input: hold()), isNotNull);
    });

    test('heat builds into a fireball that smashes danger', () {
      final floors = [for (var i = 0; i < 9; i++) allSafe, dangerUnderBall, allSafe];
      final sim = Simulation(testLevel(floors, mode: InputMode.smash));
      expect(runUntil(sim, GameEventType.fireballOn, input: hold()), isNotNull);
      expect(sim.fireball, isTrue);
      final events = runFor(sim, 1, input: hold());
      expect(events.any((e) => e.type == GameEventType.death), isFalse);
      expect(sim.floorStates[9].broken, isTrue);
    });
  });

  test('simulation is deterministic for identical input sequences', () {
    List<double> run() {
      final sim = Simulation(testLevel(['SSSSGGGSSSSSSDSS', 'SSSSSSSSGGGSSSSS', allSafe]));
      final f = InputFrame();
      for (var i = 0; i < 600; i++) {
        f.dragDelta = (i % 50 < 10) ? 0.01 : 0;
        f.dragging = i % 50 < 10;
        sim.step(GameConstants.fixedStep, f);
      }
      return [sim.ball.y, sim.rotation.angle, sim.score.toDouble(), sim.time];
    }

    expect(run(), run());
  });

  test('collision: boundary angle belongs to the higher slot', () {
    expect(CollisionSystem.slotIndex(GameConstants.slotAngle * 3), 3);
    expect(CollisionSystem.slotIndex(GameConstants.slotAngle * 3 - 1e-9), 2);
  });
}
