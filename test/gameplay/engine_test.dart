import 'package:ball_stack/core/enums/game_enums.dart';
import 'package:ball_stack/features/gameplay/domain/game_event.dart';
import 'package:ball_stack/features/gameplay/engine/game_engine.dart';
import 'package:ball_stack/features/gameplay/presentation/widgets/game_scene_view.dart';
import 'package:ball_stack/features/shop/data/skin_catalog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers.dart';

class _Host extends StatefulWidget {
  const _Host({required this.engine});

  final GameEngine engine;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> with SingleTickerProviderStateMixin {
  @override
  void initState() {
    super.initState();
    widget.engine
      ..attach(this)
      ..attach(this) // second attach must not create a second loop
      ..begin();
  }

  @override
  void dispose() {
    widget.engine.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => MaterialApp(home: GameSceneView(engine: widget.engine));
}

Future<void> pumpFrames(WidgetTester t, int n) async {
  for (var i = 0; i < n; i++) {
    await t.pump(const Duration(milliseconds: 16));
  }
}

void main() {
  testWidgets('engine runs intro → playing, bounces, pauses and resumes', (t) async {
    final engine = GameEngine(level: testLevel([allSafe, gapUnderBall, allSafe]), skin: SkinCatalog.all.first);
    final events = <GameEventType>[];
    engine.onGameEvent = (e) => events.add(e.type);
    await t.pumpWidget(_Host(engine: engine));
    expect(engine.phase, GamePhase.intro);
    await pumpFrames(t, 90); // intro ≈ 1.1 s
    expect(GameStateMachineActive.isActive(engine.phase), isTrue);
    await pumpFrames(t, 90);
    expect(events, contains(GameEventType.bounce));

    engine.pause();
    expect(engine.phase, GamePhase.paused);
    expect(engine.isLoopRunning, isFalse);
    final y = engine.sim.ball.y, time = engine.sim.time;
    await pumpFrames(t, 60);
    expect(engine.sim.ball.y, y, reason: 'pause freezes the world');
    expect(engine.sim.time, time);

    engine.resume();
    expect(engine.isLoopRunning, isTrue);
    await pumpFrames(t, 30);
    expect(engine.sim.time, greaterThan(time));
    expect(engine.renderer.stats.drawn, greaterThan(100), reason: 'tower + ball rendered');

    await t.pumpWidget(const SizedBox());
    engine.dispose();
  });

  testWidgets('death leads to gameOver; restart rebuilds the level; revive continues', (t) async {
    final engine = GameEngine(level: testLevel([dangerUnderBall, allSafe]), skin: SkinCatalog.all.first);
    await t.pumpWidget(_Host(engine: engine));
    await pumpFrames(t, 200);
    expect(engine.phase, GamePhase.gameOver);
    expect(engine.canRevive, isTrue);
    engine.revive();
    expect(engine.phase, GamePhase.playing);
    await pumpFrames(t, 240);
    expect(engine.phase, GamePhase.gameOver, reason: 'hazard still there once grace expires');
    final oldRun = engine.runId;
    engine.restart();
    expect(engine.phase, GamePhase.intro);
    expect(engine.runId, isNot(oldRun));
    expect(engine.sim.floor, 0);
    await t.pumpWidget(const SizedBox());
    engine.dispose();
  });

  testWidgets('level completes when the ball reaches the base', (t) async {
    final engine = GameEngine(level: testLevel([gapUnderBall, gapUnderBall]), skin: SkinCatalog.all.first);
    await t.pumpWidget(_Host(engine: engine));
    await pumpFrames(t, 300);
    expect(engine.phase, GamePhase.levelCompleted);
    expect(engine.sim.won, isTrue);
    await t.pumpWidget(const SizedBox());
    engine.dispose();
  });
}

abstract final class GameStateMachineActive {
  static bool isActive(GamePhase p) =>
      const {GamePhase.playing, GamePhase.falling, GamePhase.bouncing, GamePhase.combo, GamePhase.destruction}
          .contains(p);
}
