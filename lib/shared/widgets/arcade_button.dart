import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../app/theme/colors.dart';
import '../../core/services/audio_service.dart';

enum ArcadeButtonStyle { primary, secondary, glass, danger }

/// Chunky arcade button with press-scale animation, click sound and haptic.
class ArcadeButton extends StatefulWidget {
  const ArcadeButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.style = ArcadeButtonStyle.primary,
    this.icon,
    this.height = 56,
    this.fontSize = 20,
    this.trailing,
    this.semanticLabel,
  });

  final String label;
  final VoidCallback? onPressed;
  final ArcadeButtonStyle style;
  final IconData? icon;
  final double height;
  final double fontSize;
  final Widget? trailing;
  final String? semanticLabel;

  @override
  State<ArcadeButton> createState() => _ArcadeButtonState();
}

class _ArcadeButtonState extends State<ArcadeButton> {
  bool _down = false;

  Gradient? get _gradient => switch (widget.style) {
        ArcadeButtonStyle.primary => AppColors.primaryGradient,
        ArcadeButtonStyle.secondary => AppColors.skyGradient,
        ArcadeButtonStyle.danger => const LinearGradient(colors: [AppColors.danger, Color(0xFFB0124A)]),
        ArcadeButtonStyle.glass => null,
      };

  Color get _shadow => switch (widget.style) {
        ArcadeButtonStyle.primary => const Color(0xFFB8324E),
        ArcadeButtonStyle.secondary => const Color(0xFF2B5FBF),
        ArcadeButtonStyle.danger => const Color(0xFF7A0A30),
        ArcadeButtonStyle.glass => const Color(0x33000000),
      };

  @override
  Widget build(BuildContext context) {
    final enabled = widget.onPressed != null;
    final depth = widget.height * 0.09;
    return Semantics(
      button: true,
      label: widget.semanticLabel ?? widget.label,
      child: GestureDetector(
        onTapDown: enabled ? (_) => setState(() => _down = true) : null,
        onTapCancel: () => setState(() => _down = false),
        onTapUp: enabled
            ? (_) {
                setState(() => _down = false);
                if (Get.isRegistered<AudioService>()) Get.find<AudioService>().click();
                widget.onPressed!();
              }
            : null,
        child: AnimatedScale(
          scale: _down ? 0.94 : 1,
          duration: Duration(milliseconds: _down ? 90 : 160),
          curve: _down ? Curves.easeOut : Curves.elasticOut,
          child: Opacity(
            opacity: enabled ? 1 : 0.45,
            child: Container(
              height: widget.height,
              padding: EdgeInsets.only(bottom: _down ? depth * 0.3 : depth),
              decoration: BoxDecoration(
                color: _shadow,
                borderRadius: BorderRadius.circular(widget.height / 2),
              ),
              child: Container(
                decoration: BoxDecoration(
                  gradient: _gradient,
                  color: _gradient == null ? AppColors.glass : null,
                  borderRadius: BorderRadius.circular(widget.height / 2),
                  border: Border.all(color: Colors.white.withValues(alpha: 0.35), width: 1.5),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (widget.icon != null) ...[
                      Icon(widget.icon, color: Colors.white, size: widget.fontSize + 4),
                      const SizedBox(width: 8),
                    ],
                    Flexible(
                      child: Text(
                        widget.label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: widget.fontSize,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 0.8,
                          shadows: const [Shadow(color: Color(0x55000000), offset: Offset(0, 2), blurRadius: 4)],
                        ),
                      ),
                    ),
                    if (widget.trailing != null) ...[const SizedBox(width: 8), widget.trailing!],
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

/// Round icon button (pause, settings, back).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({super.key, required this.icon, required this.onPressed, this.size = 48, this.semanticLabel,
      this.badge = false});

  final IconData icon;
  final VoidCallback onPressed;
  final double size;
  final String? semanticLabel;
  final bool badge;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: semanticLabel,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () {
          if (Get.isRegistered<AudioService>()) Get.find<AudioService>().click();
          onPressed();
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: size,
              height: size,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.glass,
                border: Border.all(color: AppColors.glassBorder, width: 1.5),
              ),
              child: Icon(icon, color: Colors.white, size: size * 0.52),
            ),
            if (badge)
              Positioned(
                right: 0,
                top: 0,
                child: Container(
                  width: 14,
                  height: 14,
                  decoration: BoxDecoration(
                      color: AppColors.danger, shape: BoxShape.circle, border: Border.all(color: Colors.white, width: 2)),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
