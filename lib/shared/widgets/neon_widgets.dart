import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/typography.dart';
import '../../core/services/audio_service.dart';
import 'common.dart';

/// Shared neon-arcade UI pieces (home + in-game HUD).

void neonClick() {
  if (Get.isRegistered<AudioService>()) Get.find<AudioService>().click();
}

/// Scale-on-press wrapper with click sound.
class PressableScale extends StatefulWidget {
  const PressableScale({super.key, required this.child, required this.onTap, this.semanticLabel, this.selected});

  final Widget child;
  final VoidCallback onTap;
  final String? semanticLabel;
  final bool? selected;

  @override
  State<PressableScale> createState() => PressableScaleState();
}

class PressableScaleState extends State<PressableScale> {
  bool _down = false;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      selected: widget.selected,
      label: widget.semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTapDown: (_) => setState(() => _down = true),
        onTapCancel: () => setState(() => _down = false),
        onTapUp: (_) {
          setState(() => _down = false);
          neonClick();
          widget.onTap();
        },
        child: AnimatedScale(
          scale: _down ? 0.93 : 1,
          duration: Duration(milliseconds: _down ? 80 : 160),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: widget.child,
        ),
      ),
    );
  }
}

class NeonCoinPill extends StatelessWidget {
  const NeonCoinPill({super.key, required this.coins, this.onAdd, this.compact = false});

  final int coins;
  final VoidCallback? onAdd;

  /// Slightly smaller variant for the in-game HUD.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: compact ? 44 : 48,
      padding: const EdgeInsets.fromLTRB(6, 5, 5, 5),
      decoration: BoxDecoration(
        gradient: const LinearGradient(colors: [Color(0xCC2A1F70), Color(0xCC1A1250)]),
        borderRadius: BorderRadius.circular(30),
        border: Border.all(color: const Color(0x667A8CFF), width: 1.5),
        boxShadow: const [BoxShadow(color: Color(0x553A6BFF), blurRadius: 14)],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/icons/coin.png', width: compact ? 32 : 36, height: compact ? 32 : 36),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: BoxConstraints(minWidth: compact ? 36 : 44),
            child: Text(formatNumber(coins), style: AppText.number.copyWith(fontSize: 20)),
          ),
          if (onAdd != null) ...[
            const SizedBox(width: 10),
            PressableScale(
              onTap: onAdd!,
              semanticLabel: 'Get coins',
              child: Container(
                width: compact ? 30 : 34,
                height: compact ? 30 : 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [Color(0xFF7CF25A), Color(0xFF22B830)],
                  ),
                  border: Border.all(color: const Color(0xAAFFFFFF), width: 1.5),
                  boxShadow: const [BoxShadow(color: Color(0x8844E040), blurRadius: 8)],
                ),
                child: const Icon(Icons.add_rounded, color: Colors.white, size: 24),
              ),
            ),
          ] else
            const SizedBox(width: 8),
        ],
      ),
    );
  }
}

/// Small golden laurel branch.
class NeonLaurel extends StatelessWidget {
  const NeonLaurel({super.key, this.mirror = false, this.size = const Size(22, 34)});

  final bool mirror;
  final Size size;

  @override
  Widget build(BuildContext context) {
    return Transform.flip(
      flipX: mirror,
      child: CustomPaint(size: size, painter: const _LaurelPainter()),
    );
  }
}

class _LaurelPainter extends CustomPainter {
  const _LaurelPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final stem = Paint()
      ..color = const Color(0xFFE8B830)
      ..style = PaintingStyle.stroke
      ..strokeWidth = math.max(2, size.width * 0.08)
      ..strokeCap = StrokeCap.round;
    final path = Path()
      ..moveTo(w * 0.85, h * 0.98)
      ..quadraticBezierTo(w * 0.05, h * 0.7, w * 0.45, h * 0.02);
    canvas.drawPath(path, stem);
    final leaf = Paint()
      ..shader = const LinearGradient(colors: [Color(0xFFFFE680), Color(0xFFE0A020)]).createShader(Offset.zero & size);
    final metric = path.computeMetrics().first;
    for (var i = 0; i < 4; i++) {
      final t = metric.getTangentForOffset(metric.length * (0.18 + i * 0.22))!;
      for (final side in [-1.0, 1.0]) {
        canvas.save();
        canvas.translate(t.position.dx, t.position.dy);
        canvas.rotate(-t.angle + math.pi + side * 0.75);
        final lw = size.width * 0.42, lh = lw * 0.55;
        canvas.drawOval(Rect.fromLTWH(0, -lh / 2, lw, lh), leaf);
        canvas.restore();
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Chunky glossy pill button with a coloured base edge and glow (home + popups).
class NeonPillButton extends StatelessWidget {
  const NeonPillButton({
    super.key,
    required this.label,
    required this.onTap,
    required this.colors,
    required this.edge,
    this.glow,
    this.icon,
    this.trailing,
    this.height = 64,
    this.fontSize = 24,
    this.glass = false,
  });

  /// Glass variant (HOME): translucent violet fill, no strong glow.
  const NeonPillButton.glass({
    super.key,
    required this.label,
    required this.onTap,
    this.icon,
    this.trailing,
    this.height = 58,
    this.fontSize = 22,
  }) : colors = const [Color(0xAA6A4BC8), Color(0xAA45309A)],
       edge = const Color(0x88301E70),
       glow = null,
       glass = true;

  final String label;
  final VoidCallback? onTap;
  final List<Color> colors;
  final Color edge;
  final Color? glow;
  final IconData? icon;
  final Widget? trailing;
  final double height;
  final double fontSize;
  final bool glass;

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    final r = BorderRadius.circular(height / 2);
    final body = Opacity(
      opacity: enabled ? 1 : 0.5,
      child: Container(
        height: height,
        padding: const EdgeInsets.only(bottom: 5),
        decoration: BoxDecoration(
          color: edge,
          borderRadius: r,
          boxShadow: [
            if (glow != null && enabled) BoxShadow(color: glow!.withValues(alpha: 0.55), blurRadius: 22),
            const BoxShadow(color: Color(0x55000000), blurRadius: 8, offset: Offset(0, 5)),
          ],
        ),
        child: Container(
          decoration: BoxDecoration(
            borderRadius: r,
            gradient: LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors),
            border: Border.all(color: Colors.white.withValues(alpha: glass ? 0.35 : 0.7), width: 2),
          ),
          child: Stack(
            children: [
              if (!glass)
                Positioned(
                  left: height * 0.4,
                  right: height * 0.4,
                  top: 4,
                  height: height * 0.32,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(height),
                      gradient: const LinearGradient(
                        begin: Alignment.topCenter,
                        end: Alignment.bottomCenter,
                        colors: [Color(0x66FFFFFF), Color(0x00FFFFFF)],
                      ),
                    ),
                  ),
                ),
              Center(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 18),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (icon != null) ...[
                          Icon(icon, color: Colors.white, size: fontSize * 1.35),
                          SizedBox(width: fontSize * 0.55),
                        ],
                        Text(
                          label,
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: fontSize,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 1.2,
                            shadows: const [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 4)],
                          ),
                        ),
                        if (trailing != null) ...[SizedBox(width: fontSize * 0.6), trailing!],
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
    if (!enabled) return Semantics(button: true, enabled: false, label: label, child: body);
    return PressableScale(onTap: onTap!, semanticLabel: label, child: body);
  }
}

/// Big white number with a blue neon outline (HUD score, result screens).
class NeonNumber extends StatelessWidget {
  const NeonNumber(this.text, {super.key, this.fontSize = 46});

  final String text;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final base = TextStyle(
      fontSize: fontSize,
      fontWeight: FontWeight.w900,
      height: 1,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return Stack(
      children: [
        Text(
          text,
          style: base.copyWith(
            foreground: Paint()
              ..style = PaintingStyle.stroke
              ..strokeWidth = fontSize * 0.15
              ..strokeJoin = StrokeJoin.round
              ..color = const Color(0xFF2B5FE0),
            shadows: const [Shadow(color: Color(0xAA3FA9FF), blurRadius: 14)],
          ),
        ),
        Text(text, style: base.copyWith(color: Colors.white)),
      ],
    );
  }
}

/// Gold crown glyph (no crown in Material icons).
class CrownIcon extends StatelessWidget {
  const CrownIcon({super.key, this.size = 34});

  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(size: Size(size, size * 0.8), painter: const _CrownPainter());
}

class _CrownPainter extends CustomPainter {
  const _CrownPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(w * 0.06, h * 0.3)
      ..lineTo(w * 0.3, h * 0.55)
      ..lineTo(w * 0.5, h * 0.12)
      ..lineTo(w * 0.7, h * 0.55)
      ..lineTo(w * 0.94, h * 0.3)
      ..lineTo(w * 0.84, h * 0.78)
      ..lineTo(w * 0.16, h * 0.78)
      ..close();
    canvas.drawPath(path.shift(const Offset(0, 2)), Paint()..color = const Color(0x55000000));
    canvas.drawPath(
      path,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0xFFFFE680), Color(0xFFF5A800)],
        ).createShader(Offset.zero & size),
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(Rect.fromLTRB(w * 0.14, h * 0.8, w * 0.86, h * 0.98), const Radius.circular(3)),
      Paint()..color = const Color(0xFFE89A00),
    );
    final gem = Paint()..color = Colors.white;
    for (final x in [0.06, 0.5, 0.94]) {
      canvas.drawCircle(Offset(w * x, h * (x == 0.5 ? 0.1 : 0.28)), w * 0.06, gem);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Icon filled with a vertical gradient.
class GradientIcon extends StatelessWidget {
  const GradientIcon(this.icon, {super.key, required this.colors, this.size = 32});

  final IconData icon;
  final List<Color> colors;
  final double size;

  @override
  Widget build(BuildContext context) => ShaderMask(
    shaderCallback: (r) =>
        LinearGradient(begin: Alignment.topCenter, end: Alignment.bottomCenter, colors: colors).createShader(r),
    child: Icon(icon, size: size, color: Colors.white),
  );
}
