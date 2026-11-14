import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/widgets/arcade_button.dart';
import '../../../../shared/widgets/common.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../controllers/game_controller.dart';

/// Dimmed, centred overlay container with entrance animation.
class _OverlayFrame extends StatelessWidget {
  const _OverlayFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 260),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Container(
          color: Colors.black.withValues(alpha: 0.45 * t.clamp(0.0, 1.0)),
          alignment: Alignment.center,
          child: Transform.scale(scale: 0.9 + 0.1 * t, child: c),
        ),
      ),
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: GlassPanel(opacity: 0.14, child: child),
            ),
          ),
        ),
      ),
    );
  }
}

class PauseOverlay extends StatelessWidget {
  const PauseOverlay({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    final s = Get.find<SettingsController>();
    return _OverlayFrame(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('PAUSED', style: AppText.h1),
          const SizedBox(height: 20),
          ArcadeButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onPressed: c.resume),
          const SizedBox(height: 12),
          ArcadeButton(
              label: 'RESTART', icon: Icons.replay_rounded, style: ArcadeButtonStyle.secondary, onPressed: c.retry),
          const SizedBox(height: 12),
          ArcadeButton(label: 'HOME', icon: Icons.home_rounded, style: ArcadeButtonStyle.glass, onPressed: c.goHome),
          const SizedBox(height: 22),
          Obx(() {
            final v = s.settings.value;
            return Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                _Toggle(icon: Icons.music_note_rounded, label: 'Music', on: v.music, onTap: s.toggleMusic),
                _Toggle(icon: Icons.volume_up_rounded, label: 'Sound', on: v.sfx, onTap: s.toggleSfx),
                _Toggle(icon: Icons.vibration_rounded, label: 'Haptics', on: v.haptics, onTap: s.toggleHaptics),
              ],
            );
          }),
        ],
      ),
    );
  }
}

class _Toggle extends StatelessWidget {
  const _Toggle({required this.icon, required this.label, required this.on, required this.onTap});

  final IconData icon;
  final String label;
  final bool on;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      toggled: on,
      label: label,
      child: GestureDetector(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          width: 84,
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: on ? AppColors.mint.withValues(alpha: 0.28) : const Color(0x33000000),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: on ? AppColors.mint : AppColors.glassBorder, width: 1.5),
          ),
          child: Column(
            children: [
              Icon(on ? icon : Icons.block_rounded, color: Colors.white),
              const SizedBox(height: 4),
              Text(label, style: AppText.caption.copyWith(color: Colors.white, fontSize: 11)),
              Text(on ? 'ON' : 'OFF', style: AppText.caption.copyWith(fontSize: 10)),
            ],
          ),
        ),
      ),
    );
  }
}

class GameOverOverlay extends StatelessWidget {
  const GameOverOverlay({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    return _OverlayFrame(
      child: Obx(() {
        final r = c.runResult.value;
        final score = r?.score ?? c.score.value;
        final best = c.player.bestScore.value > score ? c.player.bestScore.value : score;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _Pulse(child: Image.asset('assets/images/ui/failure.png', width: 110)),
            const Text('CRASHED!', style: AppText.h1),
            if (c.newBest.value)
              Text('NEW BEST!', style: AppText.h2.copyWith(color: AppColors.gold, fontSize: 18)),
            const SizedBox(height: 8),
            Text(formatNumber(score), style: AppText.display),
            const Text('SCORE', style: AppText.caption),
            const SizedBox(height: 16),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                StatTile(label: 'BEST', value: formatNumber(best)),
                StatTile(label: 'MAX COMBO', value: '×${r?.bestCombo ?? 0}'),
                StatTile(label: 'FLOORS', value: '${r?.floorsCleared ?? 0}/${r?.totalFloors ?? 0}'),
              ],
            ),
            const SizedBox(height: 20),
            if (!c.reviveUsed.value) ...[
              ArcadeButton(
                label: 'REVIVE',
                style: ArcadeButtonStyle.secondary,
                icon: Icons.favorite_rounded,
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  Image.asset('assets/images/icons/coin.png', width: 20),
                  const SizedBox(width: 4),
                  Text('${c.reviveCost}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 18)),
                ]),
                onPressed: c.canAffordRevive ? () => c.reviveWithCoins() : null,
              ),
              if (!c.canAffordRevive)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not enough coins to revive', style: AppText.caption.copyWith(fontSize: 11)),
                ),
              const SizedBox(height: 12),
            ],
            ArcadeButton(label: 'RETRY', icon: Icons.replay_rounded, onPressed: c.retry),
            const SizedBox(height: 12),
            ArcadeButton(label: 'HOME', icon: Icons.home_rounded, style: ArcadeButtonStyle.glass, onPressed: c.goHome),
          ],
        );
      }),
    );
  }
}

class LevelCompleteOverlay extends StatelessWidget {
  const LevelCompleteOverlay({super.key, required this.c});

  final GameController c;

  @override
  Widget build(BuildContext context) {
    return _OverlayFrame(
      child: Obx(() {
        final reward = c.reward.value;
        final r = c.runResult.value;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _StarBurst(stars: reward?.stars ?? 0),
            Text('LEVEL ${c.levelId.value} CLEAR!', style: AppText.h1, textAlign: TextAlign.center),
            if (c.newBest.value) Text('NEW BEST!', style: AppText.h2.copyWith(color: AppColors.gold, fontSize: 18)),
            const SizedBox(height: 6),
            _CountUp(value: r?.score ?? c.score.value, style: AppText.display),
            const Text('SCORE', style: AppText.caption),
            const SizedBox(height: 16),
            if (reward == null)
              const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.white))
            else ...[
              _RewardRow(label: 'Score coins', value: reward.scoreCoins),
              _RewardRow(label: 'Gold collected', value: reward.bonusCoins),
              _RewardRow(label: 'Combo bonus', value: reward.comboCoins),
              if (reward.firstClearCoins > 0) _RewardRow(label: 'First clear', value: reward.firstClearCoins),
              const Divider(color: AppColors.glassBorder, height: 20),
              _RewardRow(label: 'TOTAL', value: reward.total, bold: true),
            ],
            const SizedBox(height: 20),
            ArcadeButton(label: 'NEXT LEVEL', icon: Icons.arrow_forward_rounded, onPressed: c.nextLevel),
            const SizedBox(height: 12),
            ArcadeButton(
                label: 'REPLAY', icon: Icons.replay_rounded, style: ArcadeButtonStyle.secondary, onPressed: c.retry),
            const SizedBox(height: 12),
            ArcadeButton(label: 'HOME', icon: Icons.home_rounded, style: ArcadeButtonStyle.glass, onPressed: c.goHome),
          ],
        );
      }),
    );
  }
}

class _RewardRow extends StatelessWidget {
  const _RewardRow({required this.label, required this.value, this.bold = false});

  final String label;
  final int value;
  final bool bold;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 3),
      child: Row(
        children: [
          Expanded(child: Text(label, style: AppText.body.copyWith(fontWeight: bold ? FontWeight.w900 : null))),
          Image.asset('assets/images/icons/coin.png', width: 20),
          const SizedBox(width: 6),
          _CountUp(value: value, prefix: '+', style: AppText.number.copyWith(fontSize: bold ? 22 : 18)),
        ],
      ),
    );
  }
}

class _CountUp extends StatelessWidget {
  const _CountUp({required this.value, required this.style, this.prefix = ''});

  final int value;
  final TextStyle style;
  final String prefix;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: value.toDouble()),
      duration: const Duration(milliseconds: 900),
      curve: Curves.easeOutCubic,
      builder: (_, v, _) => Text('$prefix${formatNumber(v.round())}', style: style),
    );
  }
}

class _StarBurst extends StatelessWidget {
  const _StarBurst({required this.stars});

  final int stars;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 90,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++)
            TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: Duration(milliseconds: 500 + i * 220),
              curve: Curves.elasticOut,
              builder: (_, t, child) => Transform.scale(scale: t, child: child),
              child: Padding(
                padding: EdgeInsets.only(bottom: i == 1 ? 18 : 0, left: 4, right: 4),
                child: Opacity(
                  opacity: i < stars ? 1 : 0.22,
                  child: Image.asset('assets/images/icons/star.png', width: i == 1 ? 72 : 56),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _Pulse extends StatefulWidget {
  const _Pulse({required this.child});

  final Widget child;

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _a =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ScaleTransition(
      scale: Tween(begin: 0.92, end: 1.06).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
      child: widget.child);
}
