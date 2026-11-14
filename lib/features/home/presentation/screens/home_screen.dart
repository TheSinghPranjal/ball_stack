import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../../../app/theme/colors.dart';
import '../../../../app/theme/typography.dart';
import '../../../../core/enums/game_enums.dart';
import '../../../../shared/widgets/arcade_button.dart';
import '../../../../shared/widgets/common.dart';
import '../../../../shared/widgets/neon_widgets.dart';
import '../../../../shared/widgets/showcase_view.dart';
import '../../../player/domain/progression_service.dart';
import '../controllers/home_controller.dart';

class HomeScreen extends GetView<HomeController> {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final p = controller.player;
    final compact = MediaQuery.sizeOf(context).height < 720;
    return Scaffold(
      backgroundColor: const Color(0xFF1A0F4A),
      body: Stack(
        fit: StackFit.expand,
        children: [
          Image.asset('assets/images/bg/home_bg.jpg', fit: BoxFit.cover, alignment: Alignment.topCenter),
          const DecoratedBox(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                stops: [0, 0.18, 0.6, 1],
                colors: [Color(0x88140A38), Color(0x00000000), Color(0x00000000), Color(0x99140A38)],
              ),
            ),
          ),
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
              child: Column(
                children: [
                  Row(
                    children: [
                      Obx(() => NeonCoinPill(coins: p.coins.value, onAdd: controller.openShop)),
                      const Spacer(),
                      Obx(() {
                        final on = controller.settings.value.music || controller.settings.value.sfx;
                        return _SquareIconButton(
                          icon: on ? Icons.volume_up_rounded : Icons.volume_off_rounded,
                          onTap: controller.toggleSound,
                          semanticLabel: on ? 'Mute' : 'Unmute',
                        );
                      }),
                      const SizedBox(width: 12),
                      _SquareIconButton(
                        icon: Icons.settings_rounded,
                        onTap: controller.openSettings,
                        semanticLabel: 'Settings',
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Expanded(
                    child: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Positioned.fill(
                          child: Obx(
                            () => ShowcaseView(
                              level: p.currentLevel.value,
                              skin: p.selectedSkin,
                              quality: controller.settings.value.quality,
                              stage: true,
                              stageTopInset: compact ? 64 : 62,
                            ),
                          ),
                        ),
                        Align(
                          alignment: Alignment.topCenter,
                          child: _NeonLogo(scale: compact ? 0.78 : 1),
                        ),
                      ],
                    ),
                  ),
                  _ModeButtons(controller: controller),
                  SizedBox(height: compact ? 10 : 16),
                  Obx(() => _StatsRow(level: p.currentLevel.value, best: p.bestScore.value)),
                  const SizedBox(height: 18),
                  _PlayButton(onTap: controller.play),
                  SizedBox(height: compact ? 14 : 26),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _MenuTile(
                        label: 'Balls',
                        colors: const [Color(0xFF3FA9FF), Color(0xFF1B4FD8)],
                        glow: const Color(0xFF3FA9FF),
                        onTap: controller.openShop,
                        child: const _GlossyBall(),
                      ),
                      _MenuTile(
                        label: 'Levels',
                        colors: const [Color(0xFF9B6BFF), Color(0xFF5A2BD0)],
                        glow: const Color(0xFF9B6BFF),
                        onTap: controller.openLevels,
                        child: const Icon(Icons.grid_view_rounded, color: Colors.white, size: 38),
                      ),
                      Obx(
                        () => _MenuTile(
                          label: 'Daily',
                          colors: const [Color(0xFFB35CFF), Color(0xFF6A2BD8)],
                          glow: const Color(0xFFD45CFF),
                          badge: p.dailyAvailable.value,
                          onTap: () => _showDaily(context),
                          child: Image.asset('assets/images/icons/gift.png', width: 44),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showDaily(BuildContext context) {
    final available = controller.player.dailyAvailable.value;
    Get.dialog(
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 380),
            child: Material(
              color: Colors.transparent,
              child: GlassPanel(
                opacity: 0.2,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Image.asset('assets/images/icons/gift.png', width: 84),
                    const SizedBox(height: 8),
                    const Text('DAILY REWARD', style: AppText.h1),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      alignment: WrapAlignment.center,
                      children: [
                        for (var d = 1; d <= 7; d++)
                          Container(
                            width: 64,
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            decoration: BoxDecoration(
                              color: d == controller.dailyDay && available
                                  ? AppColors.tangerine.withValues(alpha: 0.5)
                                  : const Color(0x33000000),
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(color: AppColors.glassBorder),
                            ),
                            child: Column(
                              children: [
                                Text('DAY $d', style: AppText.caption.copyWith(fontSize: 10, color: Colors.white)),
                                const SizedBox(height: 4),
                                Text(
                                  '${ProgressionService.dailyAmount(d)}',
                                  style: AppText.number.copyWith(fontSize: 15),
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    ArcadeButton(
                      label: available ? 'CLAIM ${controller.dailyAmount}' : 'COME BACK TOMORROW',
                      fontSize: available ? 20 : 15,
                      onPressed: available
                          ? () async {
                              final amount = await controller.claimDaily();
                              Get.back<void>();
                              if (amount > 0) {
                                Get.snackbar(
                                  'Daily reward',
                                  '+$amount coins collected!',
                                  colorText: Colors.white,
                                  backgroundColor: const Color(0xCC1B1640),
                                  margin: const EdgeInsets.all(16),
                                );
                              }
                            }
                          : null,
                    ),
                    const SizedBox(height: 10),
                    ArcadeButton(
                      label: 'CLOSE',
                      style: ArcadeButtonStyle.glass,
                      height: 46,
                      fontSize: 16,
                      onPressed: () => Get.back<void>(),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

const _neonPink = Color(0xFFFF4FD8);
const _neonCyan = Color(0xFF3FE0FF);

class _SquareIconButton extends StatelessWidget {
  const _SquareIconButton({required this.icon, required this.onTap, required this.semanticLabel});

  final IconData icon;
  final VoidCallback onTap;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: semanticLabel,
      child: Container(
        width: 52,
        height: 52,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          gradient: const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xCC5A4DB8), Color(0xCC2A1F70)],
          ),
          border: Border.all(color: const Color(0x80B8B0FF), width: 1.5),
          boxShadow: const [BoxShadow(color: Color(0x553A2BFF), blurRadius: 12, offset: Offset(0, 4))],
        ),
        child: Icon(icon, color: Colors.white, size: 28),
      ),
    );
  }
}

/// Logo with an animated neon orbit swoosh behind it.
class _NeonLogo extends StatefulWidget {
  const _NeonLogo({this.scale = 1});

  final double scale;

  @override
  State<_NeonLogo> createState() => _NeonLogoState();
}

class _NeonLogoState extends State<_NeonLogo> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(seconds: 3))..repeat();

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 320 * widget.scale,
      height: 150 * widget.scale,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned.fill(child: CustomPaint(painter: _OrbitPainter(_a))),
          Image.asset('assets/images/logo/logo.png', width: 280 * widget.scale),
        ],
      ),
    );
  }
}

class _OrbitPainter extends CustomPainter {
  _OrbitPainter(this.anim) : super(repaint: anim);

  final Animation<double> anim;

  @override
  void paint(Canvas canvas, Size size) {
    canvas.save();
    canvas.translate(size.width / 2, size.height * 0.62);
    canvas.rotate(-0.16);
    final oval = Rect.fromCenter(center: Offset.zero, width: size.width * 0.98, height: size.height * 0.5);
    // Open arc: leave a gap at upper-left where the swoosh "starts".
    const start = 3.6, sweep = 5.6;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..shader = const SweepGradient(colors: [_neonPink, Color(0xFFB06BFF), _neonPink]).createShader(oval)
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 9)
      ..color = Colors.white.withValues(alpha: 0.55 + 0.25 * math.sin(anim.value * 2 * math.pi));
    canvas.drawArc(oval, start, sweep, false, p);
    p
      ..strokeWidth = 4
      ..maskFilter = null;
    canvas.drawArc(oval, start, sweep, false, p);
    // Travelling spark.
    final a = start + sweep * anim.value;
    final spark = Offset(oval.width / 2 * math.cos(a), oval.height / 2 * math.sin(a));
    canvas.drawCircle(
      spark,
      7,
      Paint()
        ..color = const Color(0xCCFFFFFF)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6),
    );
    canvas.drawCircle(spark, 2.5, Paint()..color = Colors.white);
    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant _OrbitPainter old) => false;
}

class _ModeButtons extends StatelessWidget {
  const _ModeButtons({required this.controller});

  final HomeController controller;

  @override
  Widget build(BuildContext context) {
    return Obx(() {
      final mode = controller.settings.value.mode;
      return Row(
        children: [
          Expanded(
            child: _ModePill(
              label: 'SPIN',
              icon: Icons.sync_rounded,
              colors: const [Color(0xFFB06BFF), Color(0xFF6A2BE0)],
              edge: const Color(0xFF4A1AA8),
              selected: mode == InputMode.spin,
              onTap: () => controller.setMode(InputMode.spin),
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: _ModePill(
              label: 'SMASH',
              icon: Icons.bolt_rounded,
              colors: const [Color(0xFF5CF0FF), Color(0xFF14A8D8)],
              edge: const Color(0xFF0B6E9A),
              selected: mode == InputMode.smash,
              onTap: () => controller.setMode(InputMode.smash),
            ),
          ),
        ],
      );
    });
  }
}

class _ModePill extends StatelessWidget {
  const _ModePill({
    required this.label,
    required this.icon,
    required this.colors,
    required this.edge,
    required this.selected,
    required this.onTap,
  });

  final String label;
  final IconData icon;
  final List<Color> colors;
  final Color edge;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      selected: selected,
      semanticLabel: '$label mode',
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: selected ? 1 : 0.72,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          height: 58,
          padding: const EdgeInsets.only(bottom: 4),
          decoration: BoxDecoration(
            color: edge,
            borderRadius: BorderRadius.circular(29),
            boxShadow: [
              if (selected) BoxShadow(color: colors.first.withValues(alpha: 0.7), blurRadius: 20, spreadRadius: 1),
            ],
          ),
          child: Container(
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(29),
              gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
              border: Border.all(color: Colors.white.withValues(alpha: selected ? 0.75 : 0.3), width: 2),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(icon, color: Colors.white, size: 28),
                const SizedBox(width: 10),
                Text(label, style: AppText.h2.copyWith(fontSize: 21, letterSpacing: 1, fontWeight: FontWeight.w900)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _StatsRow extends StatelessWidget {
  const _StatsRow({required this.level, required this.best});

  final int level;
  final int best;

  @override
  Widget build(BuildContext context) {
    const style = TextStyle(
      fontSize: 21,
      fontWeight: FontWeight.w900,
      color: Colors.white,
      letterSpacing: 0.5,
      shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, 2), blurRadius: 6)],
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const NeonLaurel(),
          const SizedBox(width: 12),
          Text('LEVEL $level', style: style),
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 18),
            width: 2,
            height: 28,
            decoration: BoxDecoration(color: Colors.white38, borderRadius: BorderRadius.circular(1)),
          ),
          Text('BEST ${formatNumber(best)}', style: style.copyWith(color: AppColors.gold)),
          const SizedBox(width: 12),
          const NeonLaurel(mirror: true),
        ],
      ),
    );
  }
}

class _PlayButton extends StatefulWidget {
  const _PlayButton({required this.onTap});

  final VoidCallback onTap;

  @override
  State<_PlayButton> createState() => _PlayButtonState();
}

class _PlayButtonState extends State<_PlayButton> with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(vsync: this, duration: const Duration(milliseconds: 1100))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 104,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          // Neon floor ring under the button.
          Positioned(
            left: -4,
            right: -4,
            top: 34,
            bottom: -10,
            child: AnimatedBuilder(
              animation: _a,
              builder: (_, _) => CustomPaint(painter: _RingPainter(0.65 + 0.35 * _a.value)),
            ),
          ),
          ScaleTransition(
            scale: Tween(begin: 0.98, end: 1.03).animate(CurvedAnimation(parent: _a, curve: Curves.easeInOut)),
            child: PressableScale(
              onTap: widget.onTap,
              semanticLabel: 'Play',
              child: Container(
                width: 300,
                height: 86,
                padding: const EdgeInsets.only(bottom: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFA0157A),
                  borderRadius: BorderRadius.circular(43),
                  boxShadow: const [BoxShadow(color: Color(0x99FF3FB8), blurRadius: 28, spreadRadius: 2)],
                ),
                child: Container(
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(43),
                    gradient: const LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [Color(0xFFFF7AD0), Color(0xFFF0329E), Color(0xFFD42AD8)],
                    ),
                    border: Border.all(color: const Color(0xCCFFFFFF), width: 2.5),
                  ),
                  child: Stack(
                    children: [
                      // Glossy top highlight.
                      Positioned(
                        left: 24,
                        right: 24,
                        top: 5,
                        height: 26,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            borderRadius: BorderRadius.circular(20),
                            gradient: const LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                            ),
                          ),
                        ),
                      ),
                      const Center(
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_arrow_rounded, color: Colors.white, size: 56),
                            SizedBox(width: 6),
                            Text(
                              'PLAY',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 40,
                                fontWeight: FontWeight.w900,
                                letterSpacing: 2,
                                shadows: [Shadow(color: Color(0x66800050), offset: Offset(0, 3), blurRadius: 6)],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _RingPainter extends CustomPainter {
  _RingPainter(this.intensity);

  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    final oval = Offset.zero & size;
    final p = Paint()
      ..style = PaintingStyle.stroke
      ..shader = const LinearGradient(
        colors: [_neonPink, Color(0xFFB06BFF), _neonCyan, Color(0xFFB06BFF), _neonPink],
      ).createShader(oval)
      ..strokeWidth = 12
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10)
      ..color = Colors.white.withValues(alpha: 0.7 * intensity);
    canvas.drawOval(oval, p);
    p
      ..strokeWidth = 3
      ..maskFilter = null
      ..color = Colors.white.withValues(alpha: intensity);
    canvas.drawOval(oval, p);
  }

  @override
  bool shouldRepaint(covariant _RingPainter old) => old.intensity != intensity;
}

class _MenuTile extends StatelessWidget {
  const _MenuTile({
    required this.label,
    required this.onTap,
    required this.colors,
    required this.glow,
    required this.child,
    this.badge = false,
  });

  final String label;
  final VoidCallback onTap;
  final List<Color> colors;
  final Color glow;
  final Widget child;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return PressableScale(
      onTap: onTap,
      semanticLabel: label,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Stack(
            clipBehavior: Clip.none,
            children: [
              Container(
                width: 82,
                height: 82,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(24),
                  gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.55), width: 2),
                  boxShadow: [
                    BoxShadow(color: glow.withValues(alpha: 0.6), blurRadius: 18),
                    const BoxShadow(color: Color(0x66000000), blurRadius: 6, offset: Offset(0, 5)),
                  ],
                ),
                child: Stack(
                  children: [
                    Positioned(
                      left: 8,
                      right: 8,
                      top: 4,
                      height: 30,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(18),
                          gradient: const LinearGradient(
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                            colors: [Color(0x40FFFFFF), Color(0x00FFFFFF)],
                          ),
                        ),
                      ),
                    ),
                    Center(child: child),
                  ],
                ),
              ),
              if (badge)
                Positioned(
                  right: -5,
                  top: -5,
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      color: AppColors.danger,
                      shape: BoxShape.circle,
                      border: Border.all(color: Colors.white, width: 3),
                      boxShadow: const [BoxShadow(color: Color(0x88FF2E63), blurRadius: 8)],
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            label.toUpperCase(),
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w900,
              color: Colors.white,
              letterSpacing: 0.8,
              shadows: [Shadow(color: Color(0x88000000), offset: Offset(0, 2), blurRadius: 4)],
            ),
          ),
        ],
      ),
    );
  }
}

/// Glossy blue sphere for the Balls tile.
class _GlossyBall extends StatelessWidget {
  const _GlossyBall();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 46,
      height: 46,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          center: Alignment(-0.35, -0.4),
          radius: 0.9,
          colors: [Color(0xFFE8F6FF), Color(0xFF6CC4FF), Color(0xFF1E5BE0), Color(0xFF14248A)],
          stops: [0, 0.25, 0.7, 1],
        ),
        boxShadow: [BoxShadow(color: Color(0x8840C8FF), blurRadius: 10)],
      ),
    );
  }
}
