import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/neon_widgets.dart';
import '../../../settings/presentation/controllers/settings_controller.dart';
import '../controllers/game_controller.dart';

/// Dimmed, centred overlay with a neon-edged frosted glass card and entrance animation.
class _OverlayFrame extends StatelessWidget {
  const _OverlayFrame({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: const Duration(milliseconds: 320),
      curve: Curves.easeOutBack,
      builder: (_, t, c) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Container(
          color: const Color(0xFF0C0626).withValues(alpha: 0.5 * t.clamp(0.0, 1.0)),
          alignment: Alignment.center,
          child: Transform.scale(scale: 0.88 + 0.12 * t, child: c),
        ),
      ),
      // The card is laid out at a fixed width and scaled down as a whole on short screens, so every button
      // stays visible without scrolling.
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 12),
          child: LayoutBuilder(
            builder: (_, box) => Center(
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: SizedBox(width: box.maxWidth.clamp(0.0, 420.0), child: _NeonCard(child: child)),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _NeonCard extends StatelessWidget {
  const _NeonCard({required this.child});

  final Widget child;

  static const _r = 34.0;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(2.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(_r),
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFFFF6BE0), Color(0xFF9B6BFF), Color(0xFF3FD8FF), Color(0xFFB04BFF)],
        ),
        boxShadow: const [
          BoxShadow(color: Color(0x99A04BFF), blurRadius: 30, spreadRadius: 2),
          BoxShadow(color: Color(0x553FD8FF), blurRadius: 50),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_r - 2),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: 16, sigmaY: 16),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [Color(0xD9452A9E), Color(0xE62C1878), Color(0xF0221262)],
              ),
            ),
            child: child,
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
          const _Banner(text: 'PAUSED', colors: [Color(0xFFB06BFF), Color(0xFF6A2BE0)], glow: Color(0xFF9B6BFF)),
          const SizedBox(height: 24),
          _RetryButton(label: 'RESUME', icon: Icons.play_arrow_rounded, onTap: c.resume),
          const SizedBox(height: 14),
          _CyanButton(label: 'RESTART', icon: Icons.replay_rounded, onTap: c.retry),
          const SizedBox(height: 14),
          NeonPillButton.glass(label: 'HOME', icon: Icons.home_rounded, onTap: c.goHome),
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
            const SizedBox(height: 140, width: double.infinity, child: _CrashedBall()),
            Transform.translate(
              offset: const Offset(0, -14),
              child: const _Banner(
                text: 'CRASHED!',
                colors: [Color(0xFFFF5BD0), Color(0xFFE0168A)],
                glow: Color(0xFFFF3FB8),
              ),
            ),
            if (c.newBest.value)
              Padding(
                padding: const EdgeInsets.only(bottom: 4),
                child: Text(
                  'NEW BEST!',
                  style: AppText.h2.copyWith(color: AppColors.gold, fontSize: 18, letterSpacing: 1.5),
                ),
              ),
            _ScoreBlock(score: score),
            const SizedBox(height: 14),
            _StatsPanel(
              best: formatNumber(best),
              combo: '×${r?.bestCombo ?? 0}',
              floors: '${r?.floorsCleared ?? 0}/${r?.totalFloors ?? 0}',
            ),
            const SizedBox(height: 18),
            if (!c.reviveUsed.value) ...[
              _CyanButton(
                label: 'REVIVE',
                icon: Icons.favorite_rounded,
                trailing: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/icons/coin.png', width: 30),
                    const SizedBox(width: 6),
                    Text(
                      '${c.reviveCost}',
                      style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                    ),
                  ],
                ),
                onTap: c.canAffordRevive ? () => c.reviveWithCoins() : null,
              ),
              if (!c.canAffordRevive)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text('Not enough coins to revive', style: AppText.caption.copyWith(fontSize: 11)),
                ),
              const SizedBox(height: 14),
            ],
            _RetryButton(label: 'RETRY', icon: Icons.replay_rounded, onTap: c.retry),
            const SizedBox(height: 14),
            NeonPillButton.glass(label: 'HOME', icon: Icons.home_rounded, onTap: c.goHome),
          ],
        );
      }),
    );
  }
}

class _RetryButton extends StatelessWidget {
  const _RetryButton({required this.label, required this.icon, required this.onTap});

  final String label;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => NeonPillButton(
    label: label,
    icon: icon,
    onTap: onTap,
    height: 66,
    fontSize: 28,
    colors: const [Color(0xFFFFA43A), Color(0xFFFF5A5A), Color(0xFFF0329E)],
    edge: const Color(0xFFB0185E),
    glow: const Color(0xFFFF5A8A),
  );
}

class _CyanButton extends StatelessWidget {
  const _CyanButton({required this.label, required this.icon, required this.onTap, this.trailing});

  final String label;
  final IconData icon;
  final VoidCallback? onTap;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) => NeonPillButton(
    label: label,
    icon: icon,
    onTap: onTap,
    trailing: trailing,
    colors: const [Color(0xFF5CE8FF), Color(0xFF1E9BFF), Color(0xFF1560E0)],
    edge: const Color(0xFF0B3FA0),
    glow: const Color(0xFF3FC8FF),
  );
}

/// Slanted glossy title banner ("CRASHED!", "PAUSED", "LEVEL CLEAR!").
class _Banner extends StatelessWidget {
  const _Banner({required this.text, required this.colors, required this.glow});

  final String text;
  final List<Color> colors;
  final Color glow;

  @override
  Widget build(BuildContext context) {
    return Transform.rotate(
      angle: -0.035,
      child: Container(
        padding: const EdgeInsets.fromLTRB(28, 6, 28, 10),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
          border: Border.all(color: Colors.white.withValues(alpha: 0.6), width: 2),
          boxShadow: [
            BoxShadow(color: glow.withValues(alpha: 0.6), blurRadius: 24),
            const BoxShadow(color: Color(0x66000000), blurRadius: 8, offset: Offset(0, 6)),
          ],
        ),
        child: FittedBox(
          fit: BoxFit.scaleDown,
          child: Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 44,
              fontWeight: FontWeight.w900,
              fontStyle: FontStyle.italic,
              letterSpacing: 1.5,
              shadows: [
                Shadow(color: Color(0xAA5A0838), offset: Offset(0, 4), blurRadius: 0),
                Shadow(color: Color(0x66000000), offset: Offset(0, 5), blurRadius: 8),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ScoreBlock extends StatelessWidget {
  const _ScoreBlock({required this.score});

  final int score;

  @override
  Widget build(BuildContext context) {
    return Stack(
      alignment: Alignment.center,
      children: [
        // Soft golden haze behind the score.
        Container(
          width: 300,
          height: 110,
          decoration: const BoxDecoration(gradient: RadialGradient(colors: [Color(0x40FFC83C), Color(0x00FFC83C)])),
        ),
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const NeonLaurel(size: Size(38, 60)),
            const SizedBox(width: 22),
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TweenAnimationBuilder<double>(
                  tween: Tween(begin: 0, end: score.toDouble()),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOutCubic,
                  builder: (_, v, _) => NeonNumber(formatNumber(v.round()), fontSize: 58),
                ),
                const SizedBox(height: 6),
                const Text(
                  'SCORE',
                  style: TextStyle(color: Colors.white, fontSize: 17, fontWeight: FontWeight.w900, letterSpacing: 2.5),
                ),
              ],
            ),
            const SizedBox(width: 22),
            const NeonLaurel(mirror: true, size: Size(38, 60)),
          ],
        ),
      ],
    );
  }
}

class _StatsPanel extends StatelessWidget {
  const _StatsPanel({required this.best, required this.combo, required this.floors});

  final String best, combo, floors;

  @override
  Widget build(BuildContext context) {
    Widget cell(Widget icon, String value, String label) => Expanded(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(height: 34, child: Center(child: icon)),
          const SizedBox(height: 4),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              value,
              style: AppText.number.copyWith(fontSize: 26, fontFeatures: const [FontFeature.tabularFigures()]),
            ),
          ),
          const SizedBox(height: 2),
          FittedBox(
            fit: BoxFit.scaleDown,
            child: Text(
              label,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 12,
                fontWeight: FontWeight.w900,
                letterSpacing: 0.8,
              ),
            ),
          ),
        ],
      ),
    );
    Widget divider() =>
        Container(width: 1.5, margin: const EdgeInsets.symmetric(vertical: 8), color: const Color(0x55D9C8FF));
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(24),
        color: const Color(0x33FFFFFF),
        border: Border.all(color: const Color(0x88D9C8FF), width: 1.5),
      ),
      child: IntrinsicHeight(
        child: Row(
          children: [
            cell(const CrownIcon(size: 36), best, 'BEST'),
            divider(),
            cell(
              const GradientIcon(
                Icons.local_fire_department_rounded,
                colors: [Color(0xFFFFD23A), Color(0xFFFF4A1A)],
                size: 34,
              ),
              combo,
              'MAX COMBO',
            ),
            divider(),
            cell(
              const GradientIcon(Icons.layers_rounded, colors: [Color(0xFF5CE8FF), Color(0xFFA06BFF)], size: 34),
              floors,
              'FLOORS',
            ),
          ],
        ),
      ),
    );
  }
}

/// Cracked glossy ball bursting over neon ripple rings, with flying shards and sparks.
class _CrashedBall extends StatefulWidget {
  const _CrashedBall();

  @override
  State<_CrashedBall> createState() => _CrashedBallState();
}

class _CrashedBallState extends State<_CrashedBall> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 2400))
    ..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => CustomPaint(painter: _CrashedBallPainter(_a));
}

class _CrashedBallPainter extends CustomPainter {
  _CrashedBallPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  static const _pink = Color(0xFFFF3FB8);
  static const _cyan = Color(0xFF3FD8FF);

  @override
  void paint(Canvas canvas, Size size) {
    final t = anim.value;
    final wave = math.sin(t * 2 * math.pi);
    final c = Offset(size.width / 2, size.height * 0.5);
    final r = size.height * 0.34;

    // Burst glow.
    canvas.drawCircle(
      c,
      r * 2.1,
      Paint()
        ..shader = RadialGradient(
          colors: [_pink.withValues(alpha: 0.75), _pink.withValues(alpha: 0)],
        ).createShader(Rect.fromCircle(center: c, radius: r * 2.1)),
    );

    // Light rays.
    final ray = Paint()
      ..strokeCap = StrokeCap.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2);
    for (var i = 0; i < 10; i++) {
      final a = -math.pi + i * math.pi / 9 + 0.05 * wave;
      final len = r * (1.5 + 0.25 * ((i * 37) % 5) / 5);
      ray
        ..strokeWidth = i.isEven ? 2.4 : 1.4
        ..color = Colors.white.withValues(alpha: 0.35 + 0.15 * wave);
      canvas.drawLine(c + Offset(math.cos(a), math.sin(a)) * r * 1.15, c + Offset(math.cos(a), math.sin(a)) * len, ray);
    }

    // Ripple rings below the ball.
    final base = c + Offset(0, r * 0.85);
    for (var i = 0; i < 3; i++) {
      final k = ((t + i / 3) % 1);
      final w = r * (2.2 + 1.6 * k), h = w * 0.22;
      final col = i.isEven ? _pink : _cyan;
      final ring = Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..color = col.withValues(alpha: (1 - k) * 0.9)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2.5);
      canvas.drawOval(Rect.fromCenter(center: base, width: w, height: h), ring);
    }
    canvas.drawOval(
      Rect.fromCenter(center: base, width: r * 2.2, height: r * 0.45),
      Paint()
        ..shader = RadialGradient(
          colors: [_pink.withValues(alpha: 0.6), _pink.withValues(alpha: 0)],
        ).createShader(Rect.fromCenter(center: base, width: r * 2.2, height: r * 0.45)),
    );

    // Flying shards.
    final shard = Paint();
    const shards = [(-1.25, 0.95, -0.5), (-1.45, 0.25, 0.6), (1.4, 0.15, -0.8), (1.25, 0.85, 0.4)];
    for (final (dx, dy, rot) in shards) {
      final drift = 1 + 0.08 * wave;
      final p = c + Offset(dx * r * drift, -dy * r * 0.9 * drift + r * 0.2);
      canvas.save();
      canvas.translate(p.dx, p.dy);
      canvas.rotate(rot + 0.2 * wave);
      final s = r * 0.32;
      final path = Path()
        ..moveTo(-s * 0.9, -s * 0.2)
        ..lineTo(-s * 0.1, -s * 0.6)
        ..lineTo(s * 0.9, -s * 0.1)
        ..lineTo(s * 0.3, s * 0.5)
        ..lineTo(-s * 0.6, s * 0.4)
        ..close();
      shard.shader = const LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [Color(0xFFFF8AA8), Color(0xFFE0164A), Color(0xFF8A0828)],
      ).createShader(Rect.fromCircle(center: Offset.zero, radius: s));
      canvas.drawPath(path, shard);
      canvas.restore();
    }

    // Sparks.
    final spark = Paint()..color = Colors.white;
    for (var i = 0; i < 9; i++) {
      final a = i * 0.7 + 0.3;
      final d = r * (1.3 + (i % 3) * 0.25) * (1 + 0.06 * math.sin(t * 6.28 + i));
      final p = c + Offset(math.cos(a + math.pi) * d, math.sin(a + math.pi) * d * 0.8);
      spark.color = (i % 3 == 0 ? const Color(0xFFFF6A9A) : Colors.white).withValues(
        alpha: 0.5 + 0.5 * math.sin(t * 6.28 * 2 + i).abs(),
      );
      canvas.drawCircle(p, i % 3 == 0 ? 3.5 : 2, spark);
    }

    // Ball.
    final ballRect = Rect.fromCircle(center: c, radius: r);
    canvas.drawCircle(
      c + const Offset(0, 4),
      r,
      Paint()
        ..color = const Color(0x55000000)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(-0.35, -0.45),
          radius: 1.0,
          colors: [Color(0xFFFF8AB0), Color(0xFFF0205A), Color(0xFFB0083A), Color(0xFF5A0020)],
          stops: [0, 0.3, 0.75, 1],
        ).createShader(ballRect),
    );
    // Specular highlight.
    canvas.drawOval(
      Rect.fromCenter(center: c + Offset(-r * 0.35, -r * 0.48), width: r * 0.7, height: r * 0.38),
      Paint()
        ..color = Colors.white.withValues(alpha: 0.55)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 4),
    );

    // Crack: dark groove with a thin bright edge.
    final crack = Path()
      ..moveTo(c.dx - r * 0.05, c.dy - r * 1.0)
      ..lineTo(c.dx + r * 0.12, c.dy - r * 0.55)
      ..lineTo(c.dx - r * 0.22, c.dy - r * 0.18)
      ..lineTo(c.dx + r * 0.18, c.dy + r * 0.12)
      ..lineTo(c.dx + r * 0.05, c.dy + r * 0.45);
    final branch = Path()
      ..moveTo(c.dx + r * 0.12, c.dy - r * 0.55)
      ..lineTo(c.dx + r * 0.5, c.dy - r * 0.45)
      ..lineTo(c.dx + r * 0.72, c.dy - r * 0.6);
    final branch2 = Path()
      ..moveTo(c.dx - r * 0.22, c.dy - r * 0.18)
      ..lineTo(c.dx - r * 0.55, c.dy - r * 0.05);
    canvas.save();
    canvas.clipPath(Path()..addOval(ballRect));
    for (final p in [crack, branch, branch2]) {
      canvas.drawPath(
        p.shift(const Offset(1.5, 1.5)),
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 3
          ..color = const Color(0x66FFB0C8)
          ..strokeJoin = StrokeJoin.round,
      );
      canvas.drawPath(
        p,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = p == crack ? 5 : 3.5
          ..color = const Color(0xFF2A0414)
          ..strokeJoin = StrokeJoin.round
          ..strokeCap = StrokeCap.round,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _CrashedBallPainter old) => false;
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
            _Banner(
              text: 'LEVEL ${c.levelId.value} CLEAR!',
              colors: const [Color(0xFF5CF0B0), Color(0xFF14B88A)],
              glow: const Color(0xFF3EE6B0),
            ),
            const SizedBox(height: 10),
            if (c.newBest.value) Text('NEW BEST!', style: AppText.h2.copyWith(color: AppColors.gold, fontSize: 18)),
            const SizedBox(height: 6),
            _ScoreBlock(score: r?.score ?? c.score.value),
            const SizedBox(height: 16),
            if (reward == null)
              const Padding(
                padding: EdgeInsets.all(12),
                child: CircularProgressIndicator(color: Colors.white),
              )
            else ...[
              _RewardRow(label: 'Score coins', value: reward.scoreCoins),
              _RewardRow(label: 'Gold collected', value: reward.bonusCoins),
              _RewardRow(label: 'Combo bonus', value: reward.comboCoins),
              if (reward.firstClearCoins > 0) _RewardRow(label: 'First clear', value: reward.firstClearCoins),
              const Divider(color: Color(0x55D9C8FF), height: 20),
              _RewardRow(label: 'TOTAL', value: reward.total, bold: true),
            ],
            const SizedBox(height: 20),
            _RetryButton(label: 'NEXT LEVEL', icon: Icons.arrow_forward_rounded, onTap: c.nextLevel),
            const SizedBox(height: 14),
            _CyanButton(label: 'REPLAY', icon: Icons.replay_rounded, onTap: c.retry),
            const SizedBox(height: 14),
            NeonPillButton.glass(label: 'HOME', icon: Icons.home_rounded, onTap: c.goHome),
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
          Expanded(
            child: Text(label, style: AppText.body.copyWith(fontWeight: bold ? FontWeight.w900 : null)),
          ),
          Image.asset('assets/images/icons/coin.png', width: 20),
          const SizedBox(width: 6),
          _CountUp(
            value: value,
            prefix: '+',
            style: AppText.number.copyWith(fontSize: bold ? 22 : 18),
          ),
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
