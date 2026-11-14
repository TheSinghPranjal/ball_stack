import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/routes/app_routes.dart';
import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/widgets/arcade_button.dart';
import '../../../../shared/widgets/common.dart';
import '../../../player/presentation/controllers/player_controller.dart';
import '../../data/level_generator.dart';

class LevelSelectScreen extends StatefulWidget {
  const LevelSelectScreen({super.key});

  @override
  State<LevelSelectScreen> createState() => _LevelSelectScreenState();
}

class _LevelSelectScreenState extends State<LevelSelectScreen> {
  final PlayerController player = Get.find<PlayerController>();
  late final ScrollController _scroll;

  @override
  void initState() {
    super.initState();
    // Start scrolled near the current level.
    final row = ((player.currentLevel.value - 1) ~/ 4) - 2;
    _scroll = ScrollController(initialScrollOffset: math.max(0, row) * 102.0);
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  Future<void> _open(int level) async {
    await player.selectLevel(level);
    Get.offNamed(AppRoutes.game, arguments: level);
  }

  @override
  Widget build(BuildContext context) {
    return ScreenScaffold(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
            child: Row(
              children: [
                RoundIconButton(icon: Icons.arrow_back_rounded, onPressed: () => Get.back<void>(), semanticLabel: 'Back'),
                const Expanded(child: Center(child: Text('LEVELS', style: AppText.h1))),
                Obx(() => CoinBadge(coins: player.coins.value, size: 18)),
              ],
            ),
          ),
          Obx(() => Text(
                '${player.levelStars.length} cleared · ${player.levelStars.values.fold(0, (a, b) => a + b)} ★',
                style: AppText.caption,
              )),
          const SizedBox(height: 8),
          Expanded(
            child: LayoutBuilder(builder: (context, cons) {
              final cols = (cons.maxWidth / 92).floor().clamp(4, 8);
              return Obx(() {
                final unlocked = player.highestUnlocked.value;
                final current = player.currentLevel.value;
                final stars = Map<int, int>.of(player.levelStars);
                return GridView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
                  gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: cols,
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 0.88,
                  ),
                  itemCount: LevelGenerator.levelCount,
                  itemBuilder: (_, i) {
                    final level = i + 1;
                    return _LevelTile(
                      level: level,
                      locked: level > unlocked,
                      current: level == current,
                      stars: stars[level] ?? 0,
                      boss: LevelGenerator.isBossLevel(level),
                      onTap: () => _open(level),
                    );
                  },
                );
              });
            }),
          ),
        ],
      ),
    );
  }
}

class _LevelTile extends StatelessWidget {
  const _LevelTile({
    required this.level,
    required this.locked,
    required this.current,
    required this.stars,
    required this.boss,
    required this.onTap,
  });

  final int level;
  final bool locked;
  final bool current;
  final int stars;
  final bool boss;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final theme = GameThemes.forIndex(level - 1);
    return Semantics(
      button: !locked,
      label: locked ? 'Level $level, locked' : 'Level $level, $stars stars',
      child: GestureDetector(
        onTap: locked ? null : onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            gradient: locked
                ? null
                : LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [Color(theme.safeA), Color(theme.skyTop)],
                  ),
            color: locked ? const Color(0x33FFFFFF) : null,
            border: Border.all(
              color: current ? Colors.white : AppColors.glassBorder,
              width: current ? 3 : 1.5,
            ),
            boxShadow: current ? [BoxShadow(color: Color(theme.accent).withValues(alpha: 0.7), blurRadius: 16)] : null,
          ),
          child: Stack(
            children: [
              Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (locked)
                      const Icon(Icons.lock_rounded, color: AppColors.textDim, size: 26)
                    else
                      Text('$level', style: AppText.h2.copyWith(fontSize: level > 99 ? 20 : 24)),
                    const SizedBox(height: 4),
                    if (!locked) StarRow(stars: stars, size: 13),
                  ],
                ),
              ),
              if (boss && !locked)
                const Positioned(
                  top: 4,
                  right: 6,
                  child: Icon(Icons.local_fire_department_rounded, size: 16, color: Color(0xFFFFE066)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
