import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../core/enums/game_enums.dart';
import '../controllers/game_controller.dart';
import '../widgets/game_scene_view.dart';
import '../widgets/hud.dart';
import '../widgets/overlays.dart';

class GameScreen extends StatefulWidget {
  const GameScreen({super.key});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with SingleTickerProviderStateMixin {
  final GameController c = Get.find<GameController>();

  @override
  void initState() {
    super.initState();
    c.attach(this);
  }

  @override
  void dispose() {
    c.engine.detach();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (didPop) return;
        final p = c.phase.value;
        if (p == GamePhase.paused) {
          c.resume();
        } else if (p == GamePhase.gameOver || p == GamePhase.levelCompleted) {
          c.goHome();
        } else {
          c.pause();
        }
      },
      child: Scaffold(
        backgroundColor: Colors.black,
        body: Stack(
          fit: StackFit.expand,
          children: [
            GameSceneView(engine: c.engine),
            FlashLayer(c: c),
            PopupLayer(c: c),
            GameHud(c: c),
            Obx(() => switch (c.phase.value) {
                  GamePhase.paused => PauseOverlay(c: c),
                  GamePhase.gameOver => GameOverOverlay(c: c),
                  GamePhase.levelCompleted => LevelCompleteOverlay(c: c),
                  _ => const SizedBox.shrink(),
                }),
          ],
        ),
      ),
    );
  }
}
