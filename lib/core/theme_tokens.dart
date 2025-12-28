import 'package:flutter/material.dart';

/// Centralized design tokens for Sero (non-destructive defaults).
///
/// These values intentionally match the app's current look-and-feel so
/// introducing them is safe and will not change UI until components are
/// explicitly switched to use them.
class SeroTokens {
  // Colors
  static const Color primary = Color(0xFFD50000);
  static const Color background = Color(0xFF080101);
  static const Color surface = Color(0xFF0B0B0C);
  static const Color success = Color(0xFF1AFF6B);
  static const Color calm = Color(0xFF4CAF50);
  static const Color sad = Color(0xFF2196F3);
  static const Color stressed = Color(0xFFFF5252);

  // Text
  static const double bodySize = 15.0;
  static const double smallSize = 12.0;
  static const double headingSize = 18.0;

  // Spacing
  static const double spacingXS = 6.0;
  static const double spacingSM = 8.0;
  static const double spacingMD = 12.0;
  static const double spacingLG = 16.0;

  // Radii
  static const double radiusSmall = 8.0;
  static const double radiusLarge = 14.0;

  // Elevation
  static const double cardElevation = 2.0;

  // Text styles (referencing current defaults, non-invasive)
  static const TextStyle body = TextStyle(
    color: Colors.white,
    fontSize: bodySize,
  );

  static const TextStyle caption = TextStyle(
    color: Colors.white70,
    fontSize: smallSize,
  );

  static const TextStyle heading = TextStyle(
    color: Colors.white,
    fontSize: headingSize,
    fontWeight: FontWeight.w700,
  );
}
