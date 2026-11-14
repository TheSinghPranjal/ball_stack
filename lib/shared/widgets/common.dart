import 'dart:ui';

import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../app/theme/typography.dart';

/// Frosted panel used for overlays and cards on top of the 3D scene.
class GlassPanel extends StatelessWidget {
  const GlassPanel({super.key, required this.child, this.padding = const EdgeInsets.all(20), this.radius = 28,
      this.opacity = 0.16});

  final Widget child;
  final EdgeInsets padding;
  final double radius;
  final double opacity;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 14, sigmaY: 14),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: opacity),
            borderRadius: BorderRadius.circular(radius),
            border: Border.all(color: AppColors.glassBorder, width: 1.5),
          ),
          child: child,
        ),
      ),
    );
  }
}

/// Coin counter pill.
class CoinBadge extends StatelessWidget {
  const CoinBadge({super.key, required this.coins, this.size = 22});

  final int coins;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(6, 5, size * 0.6, 5),
      decoration: BoxDecoration(
        color: const Color(0x55000000),
        borderRadius: BorderRadius.circular(40),
        border: Border.all(color: AppColors.glassBorder, width: 1.2),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Image.asset('assets/images/icons/coin.png', width: size, height: size),
          const SizedBox(width: 6),
          Text(formatNumber(coins), style: AppText.number.copyWith(fontSize: size * 0.78)),
        ],
      ),
    );
  }
}

class StatTile extends StatelessWidget {
  const StatTile({super.key, required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(value, style: AppText.number.copyWith(fontSize: 20)),
        const SizedBox(height: 2),
        Text(label, style: AppText.caption.copyWith(fontSize: 10)),
      ],
    );
  }
}

/// Full-screen gradient backdrop with safe-area content.
class ScreenScaffold extends StatelessWidget {
  const ScreenScaffold({super.key, required this.child, this.colors});

  final Widget child;
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: colors ?? const [Color(0xFF3A1F7A), Color(0xFF1B1048), AppColors.night],
          ),
        ),
        child: SafeArea(child: child),
      ),
    );
  }
}

String formatNumber(int n) {
  final s = n.abs().toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return n < 0 ? '-$b' : b.toString();
}

/// Rows of up to 3 stars.
class StarRow extends StatelessWidget {
  const StarRow({super.key, required this.stars, this.size = 14, this.spacing = 1});

  final int stars;
  final double size;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          Padding(
            padding: EdgeInsets.symmetric(horizontal: spacing),
            child: Opacity(
              opacity: i < stars ? 1 : 0.25,
              child: Image.asset('assets/images/icons/star.png', width: size, height: size),
            ),
          ),
      ],
    );
  }
}
