import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';

/// Environment backdrop: vertical gradient, soft bloom and parallax bokeh motes. Drawn with a handful of
/// canvas calls (no widgets per particle).
class SkyPainter {
  SkyPainter(int count) : _motes = List.generate(count, (i) => _Mote(math.Random(i * 7919 + 13)));

  final List<_Mote> _motes;
  final Paint _p = Paint();
  final Paint _glow = Paint()..maskFilter = const MaskFilter.blur(BlurStyle.normal, 6);

  void paint(Canvas canvas, Size size, GameTheme theme, double time, double parallax) {
    final rect = Offset.zero & size;
    _p.shader = LinearGradient(
      begin: Alignment.topCenter,
      end: Alignment.bottomCenter,
      colors: [Color(theme.skyTop), Color(theme.skyBottom)],
    ).createShader(rect);
    canvas.drawRect(rect, _p);
    _p.shader = RadialGradient(
      center: const Alignment(0, -0.25),
      radius: 0.75,
      colors: [Color(theme.accent).withValues(alpha: 0.22), Color(theme.accent).withValues(alpha: 0)],
    ).createShader(rect);
    canvas.drawRect(rect, _p);
    _p.shader = null;
    for (final m in _motes) {
      final y = ((m.y + parallax * m.depth * 0.02 - time * m.speed) % 1.2 + 1.2) % 1.2 - 0.1;
      final x = m.x + math.sin(time * 0.3 + m.phase) * 0.02;
      final r = m.r * size.shortestSide;
      _glow.color = Colors.white.withValues(alpha: m.alpha * (0.6 + 0.4 * math.sin(time * 1.3 + m.phase)));
      canvas.drawCircle(Offset(x * size.width, y * size.height), r, _glow);
    }
  }
}

class _Mote {
  _Mote(math.Random r)
      : x = r.nextDouble(),
        y = r.nextDouble(),
        r = 0.004 + r.nextDouble() * 0.012,
        depth = 0.3 + r.nextDouble(),
        speed = 0.005 + r.nextDouble() * 0.015,
        alpha = 0.08 + r.nextDouble() * 0.22,
        phase = r.nextDouble() * 6.28;

  final double x, y, r, depth, speed, alpha, phase;
}
