import 'package:flutter/material.dart';

import 'app_colors.dart';

/// Type scale from the Stitch design. Fonts are BUNDLED (pubspec `fonts:`):
/// Sora for Latin (the Stitch spec — it has no Arabic glyphs) with
/// Noto Sans Arabic as the Arabic-script fallback, matching the backend's
/// own web frontend. No runtime font fetching — fully offline-safe.
class AppTypography {
  AppTypography._();

  static const String latinFamily = 'Sora';
  static const List<String> arabicFallback = ['NotoSansArabic'];

  static TextStyle _sora({
    required double size,
    required double height,
    required FontWeight weight,
    double letterSpacing = 0,
    Color color = AppColors.onSurface,
  }) =>
      TextStyle(
        fontFamily: latinFamily,
        fontFamilyFallback: arabicFallback,
        fontSize: size,
        height: height / size,
        fontWeight: weight,
        letterSpacing: letterSpacing,
        color: color,
      );

  /// display-lg: 32/40, -0.02em, 700
  static TextStyle get displayLg =>
      _sora(size: 32, height: 40, weight: FontWeight.w700, letterSpacing: -0.64);

  /// display-sm: 24/32, -0.01em, 700
  static TextStyle get displaySm =>
      _sora(size: 24, height: 32, weight: FontWeight.w700, letterSpacing: -0.24);

  /// headline-lg: 20/28, 600
  static TextStyle get headlineLg =>
      _sora(size: 20, height: 28, weight: FontWeight.w600);

  /// headline-mobile: 18/24, 600
  static TextStyle get headlineMobile =>
      _sora(size: 18, height: 24, weight: FontWeight.w600);

  /// body-lg: 16/24, 400
  static TextStyle get bodyLg =>
      _sora(size: 16, height: 24, weight: FontWeight.w400);

  /// body-sm: 14/20, 400
  static TextStyle get bodySm =>
      _sora(size: 14, height: 20, weight: FontWeight.w400);

  /// label-md: 12/16, 0.05em, 600
  static TextStyle get labelMd =>
      _sora(size: 12, height: 16, weight: FontWeight.w600, letterSpacing: 0.6);

  /// label-xs: 10/12, 500
  static TextStyle get labelXs =>
      _sora(size: 10, height: 12, weight: FontWeight.w500);

  /// The giant secret word on the solved screen (`text-5xl`).
  static TextStyle get secretWord => _sora(
      size: 48,
      height: 56,
      weight: FontWeight.w700,
      color: AppColors.primaryContainer);

  /// Amber text glow: `text-shadow 0 0 10px rgba(255,191,0,0.6)`.
  static List<Shadow> get amberTextGlow => [
        Shadow(color: AppColors.amberGlow(0.6), blurRadius: 10),
      ];
}
