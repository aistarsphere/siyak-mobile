import 'package:flutter/material.dart';

/// "Amber Noir" palette — extracted verbatim from the Stitch project
/// «Siyag Word Explorer» (tailwind.config colors on every screen).
class AppColors {
  AppColors._();

  // Canvas
  static const background = Color(0xFF181309);
  static const backgroundDeep = Color(0xFF0C0C0C); // gameplay body bg
  static const surface = Color(0xFF181309);
  static const surfaceDim = Color(0xFF181309);

  // Surfaces (containers)
  static const surfaceContainerLowest = Color(0xFF120E05);
  static const surfaceContainerLow = Color(0xFF201B11);
  static const surfaceContainer = Color(0xFF241F14);
  static const surfaceContainerHigh = Color(0xFF2F291E);
  static const surfaceContainerHighest = Color(0xFF3A3428);
  static const surfaceBright = Color(0xFF3F382D);
  static const surfaceVariant = Color(0xFF3A3428);

  // Primary (warm amber / gold)
  static const primary = Color(0xFFFFE2AB);
  static const onPrimary = Color(0xFF402D00);
  static const primaryContainer = Color(0xFFFFBF00);
  static const onPrimaryContainer = Color(0xFF6D5000);
  static const primaryFixedDim = Color(0xFFFBBC00);
  static const surfaceTint = Color(0xFFFBBC00);

  // Secondary (orange heat)
  static const secondary = Color(0xFFFFB95F);
  static const onSecondary = Color(0xFF472A00);
  static const secondaryContainer = Color(0xFFEE9800);
  static const onSecondaryContainer = Color(0xFF5B3800);

  // Tertiary (cold cyan)
  static const tertiary = Color(0xFFB4EFFF);
  static const onTertiary = Color(0xFF003640);
  static const tertiaryContainer = Color(0xFF04DCFF);

  // Error
  static const error = Color(0xFFFFB4AB);
  static const onError = Color(0xFF690005);
  static const errorContainer = Color(0xFF93000A);

  // Text
  static const onBackground = Color(0xFFEDE1D0); // warm ivory
  static const onSurface = Color(0xFFEDE1D0);
  static const onSurfaceVariant = Color(0xFFD4C5AB);
  static const outline = Color(0xFF9C8F78);
  static const outlineVariant = Color(0xFF504532);
  static const inverseSurface = Color(0xFFEDE1D0);
  static const inverseOnSurface = Color(0xFF363024);

  // Accents used by Stitch effects
  static const amber = Color(0xFFFFBF00); // glow / CTA
  static const amberDeep = Color(0xFFF59E0B); // gradient start
  static const emerald = Color(0xFF10B981); // success confetti
  static const ivory = Color(0xFFFDFCF0); // heat pill text
  static const confettiRed = Color(0xFFEF4444);

  /// Confetti palette from the Stitch solved screen JS.
  static const confetti = <Color>[
    amber,
    amberDeep,
    emerald,
    ivory,
    confettiRed,
  ];

  /// `gradient-fill`: linear-gradient(90deg, #F59E0B, #FFBF00)
  static const heatGradient = LinearGradient(colors: [amberDeep, amber]);

  static Color amberGlow(double opacity) => amber.withValues(alpha: opacity);
}
