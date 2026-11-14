import 'package:flutter/material.dart';

import 'colors.dart';

abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.night,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.candy,
      brightness: Brightness.dark,
      surface: AppColors.nightLight,
    ),
    splashFactory: NoSplash.splashFactory,
    highlightColor: Colors.transparent,
    sliderTheme: const SliderThemeData(
      activeTrackColor: AppColors.tangerine,
      thumbColor: Colors.white,
      inactiveTrackColor: AppColors.glass,
      trackHeight: 6,
    ),
    dialogTheme: const DialogThemeData(backgroundColor: AppColors.nightLight),
  );
}
