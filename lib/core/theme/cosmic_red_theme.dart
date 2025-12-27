import 'package:flutter/material.dart';

class CosmicRedTheme {
  static const Color background = Color(0xFF0B0B0F);
  static const Color cosmicRed = Color(0xFFB11226);
  static const Color glowRed = Color(0xFFFF2E2E);
  static const Color softRed = Color(0xFF7A1C28);

  static ThemeData theme = ThemeData(
    brightness: Brightness.dark,
    scaffoldBackgroundColor: background,
    fontFamily: 'Inter',
    textTheme: const TextTheme(
      headlineLarge: TextStyle(color: Colors.white),
      bodyMedium: TextStyle(color: Colors.white70),
    ),
  );
}
