import 'package:flutter/material.dart';

/// UI palette (see docs/wireframes/UI_UX_SPEC.md).
abstract final class AppColors {
  static const ink = Color(0xFF1B1640);
  static const night = Color(0xFF120E2E);
  static const nightLight = Color(0xFF2A1F63);
  static const candy = Color(0xFFFF5A7A);
  static const tangerine = Color(0xFFFF9F43);
  static const sky = Color(0xFF4FC3FF);
  static const mint = Color(0xFF3EE6B0);
  static const gold = Color(0xFFFFD447);
  static const danger = Color(0xFFFF2E63);
  static const glass = Color(0x24FFFFFF);
  static const glassBorder = Color(0x40FFFFFF);
  static const textDim = Color(0xB3FFFFFF);

  static const primaryGradient = LinearGradient(
    colors: [candy, tangerine],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
  static const skyGradient = LinearGradient(
    colors: [Color(0xFF6A8BFF), sky],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );
}

/// Environment + platform palette for one level theme. Colours are ARGB ints for the 3D renderer.
class GameTheme {
  const GameTheme({
    required this.name,
    required this.skyTop,
    required this.skyBottom,
    required this.fog,
    required this.safeA,
    required this.safeB,
    required this.pillar,
    required this.pillarBand,
    required this.accent,
    this.danger = 0xFF5A0A2E,
    this.dangerRim = 0xFFFF2E8A,
    this.bonus = 0xFFFFC93C,
    this.skyLight = 0xFFFFF6E8,
    this.groundLight = 0xFF5A3A9A,
    this.ring = 0xFF3FE0FF,
  });

  final String name;
  final int skyTop;
  final int skyBottom;
  final int fog;
  final int safeA;
  final int safeB;
  final int pillar;
  final int pillarBand;
  final int accent;
  final int danger;
  final int dangerRim;
  final int bonus;
  final int skyLight;
  final int groundLight;

  /// Neon ring glowing on the pillar just under each platform.
  final int ring;

  Color get skyTopColor => Color(skyTop);
  Color get skyBottomColor => Color(skyBottom);
  Color get accentColor => Color(accent);
}

/// Six original palettes; levels cycle through them.
abstract final class GameThemes {
  static const all = <GameTheme>[
    GameTheme(
      name: 'Neon Gold',
      skyTop: 0xFF4B2C8F,
      skyBottom: 0xFFFF7E79,
      fog: 0xFF7A3F8F,
      safeA: 0xFFFFD43A,
      safeB: 0xFFFFCB2A,
      pillar: 0xFFE6DCFF,
      pillarBand: 0xFFB9A6F0,
      accent: 0xFFFFE066,
    ),
    GameTheme(
      name: 'Mint Lagoon',
      skyTop: 0xFF07344A,
      skyBottom: 0xFF2BB5A6,
      fog: 0xFF0E5A66,
      safeA: 0xFF3EE6B0,
      safeB: 0xFF8BF5D3,
      pillar: 0xFFE6DCFF,
      pillarBand: 0xFFB9A6F0,
      accent: 0xFF7EF9FF,
    ),
    GameTheme(
      name: 'Berry Night',
      skyTop: 0xFF1D0B3A,
      skyBottom: 0xFF7B2C8F,
      fog: 0xFF3A1460,
      safeA: 0xFFB18CFF,
      safeB: 0xFFD7C2FF,
      pillar: 0xFFE6DCFF,
      pillarBand: 0xFFB9A6F0,
      accent: 0xFFFF9BF5,
    ),
    GameTheme(
      name: 'Citrus Sky',
      skyTop: 0xFF1450A8,
      skyBottom: 0xFF79D3FF,
      fog: 0xFF2F78C2,
      safeA: 0xFFFFDD4A,
      safeB: 0xFFFFF09A,
      pillar: 0xFFE6DCFF,
      pillarBand: 0xFFB9A6F0,
      accent: 0xFFB5F1FF,
    ),
    GameTheme(
      name: 'Coral Reef',
      skyTop: 0xFF16123D,
      skyBottom: 0xFFEA5A7B,
      fog: 0xFF4A1F57,
      safeA: 0xFF4FC3FF,
      safeB: 0xFF9BE0FF,
      pillar: 0xFFE6DCFF,
      pillarBand: 0xFFB9A6F0,
      accent: 0xFFFFC2D1,
    ),
    GameTheme(
      name: 'Aurora',
      skyTop: 0xFF050818,
      skyBottom: 0xFF1D5C5A,
      fog: 0xFF0C2830,
      safeA: 0xFF9EFFA0,
      safeB: 0xFFD4FFB8,
      pillar: 0xFFE6DCFF,
      pillarBand: 0xFFB9A6F0,
      accent: 0xFFB0FFE0,
    ),
  ];

  static GameTheme forIndex(int i) => all[i % all.length];
}
