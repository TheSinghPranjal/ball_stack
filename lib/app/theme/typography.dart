import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppText {
  static const _shadow = [Shadow(color: Color(0x66000000), offset: Offset(0, 2), blurRadius: 6)];
  static const _tab = [FontFeature.tabularFigures()];

  static const display = TextStyle(
    fontSize: 44,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    height: 1.0,
    letterSpacing: -0.5,
    shadows: _shadow,
  );
  static const h1 = TextStyle(fontSize: 30, fontWeight: FontWeight.w900, color: Colors.white, shadows: _shadow);
  static const h2 = TextStyle(fontSize: 22, fontWeight: FontWeight.w800, color: Colors.white, shadows: _shadow);
  static const body = TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: Colors.white);
  static const caption = TextStyle(
    fontSize: 12,
    fontWeight: FontWeight.w800,
    color: AppColors.textDim,
    letterSpacing: 1.2,
  );
  static const number = TextStyle(
    fontSize: 18,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    fontFeatures: _tab,
    shadows: _shadow,
  );
  static const hudScore = TextStyle(
    fontSize: 40,
    fontWeight: FontWeight.w900,
    color: Colors.white,
    fontFeatures: _tab,
    height: 1,
    shadows: [Shadow(color: Color(0xAA000000), offset: Offset(0, 3), blurRadius: 8)],
  );
}
