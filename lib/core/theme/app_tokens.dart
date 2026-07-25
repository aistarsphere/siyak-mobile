import 'package:flutter/material.dart';

/// Centralized **semantic design tokens** for the Siyaq graphite/gold identity
/// (source: `design_reference/SIYAQ_Flutter_Brand_Resources/docs/color_tokens.json`).
///
/// A single [AppTokens] definition drives both the custom Siyaq screens (via the
/// [SC] accessor) and Material components (registered as a [ThemeExtension] on
/// `ThemeData`). Screens reference tokens, never raw hex.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceAlt,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.border,
    required this.divider,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.accentPrimary,
    required this.onAccent,
    required this.accentGold,
    required this.onGold,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.disabled,
  });

  final Brightness brightness;
  final Color background;
  final Color surface;
  final Color surfaceAlt;
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color border;
  final Color divider;
  final Color iconPrimary;
  final Color iconSecondary;

  /// Primary interactive/brand color — **graphite** (not gold), per brand rules.
  final Color accentPrimary;

  /// Readable foreground on [accentPrimary]/[success]/[error]/[info] fills.
  final Color onAccent;

  /// Restrained **gold** accent — premium moments, achievements, rank/streak
  /// highlights, key result emphasis. Never a general primary.
  final Color accentGold;

  /// Readable foreground on a gold fill (dark graphite).
  final Color onGold;

  final Color success;
  final Color warning;
  final Color error;
  final Color info;
  final Color disabled;

  bool get isDark => brightness == Brightness.dark;

  // ── Brand constants (shared across themes) ────────────────────────────────
  static const graphitePrimary = Color(0xFF4A4F58);
  static const graphiteStrong = Color(0xFF353A42);
  static const graphiteDeep = Color(0xFF252A31);
  static const gold = Color(0xFFD8B36A);

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF4F2EE),
    surface: Color(0xFFFFFFFF),
    surfaceAlt: Color(0xFFE9E7E2),
    textPrimary: Color(0xFF343840),
    textSecondary: Color(0xFF626873),
    textMuted: Color(0xFF858B95),
    border: Color(0xFFD6D3CD),
    divider: Color(0xFFC9C6BF),
    iconPrimary: Color(0xFF343840),
    iconSecondary: Color(0xFF626873),
    // Gold is the PRIMARY interaction color (dark graphite text on it).
    accentPrimary: gold,
    onAccent: Color(0xFF343840),
    accentGold: gold,
    onGold: Color(0xFF343840),
    success: Color(0xFF3E8A5B),
    warning: Color(0xFFB98A33),
    error: Color(0xFFB65656),
    info: Color(0xFF5B7690),
    disabled: Color(0xFFB6BAC1),
  );

  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF1E2024),
    surface: Color(0xFF292C31),
    surfaceAlt: Color(0xFF32363C),
    textPrimary: Color(0xFFF1F2F4),
    textSecondary: Color(0xFFC0C4CA),
    textMuted: Color(0xFF9298A1),
    border: Color(0xFF41464E),
    divider: Color(0xFF4A4F58),
    iconPrimary: Color(0xFFF1F2F4),
    iconSecondary: Color(0xFF9298A1),
    // Gold is the PRIMARY interaction color (dark graphite text on it).
    accentPrimary: gold,
    onAccent: graphiteDeep,
    accentGold: gold,
    onGold: graphiteDeep,
    success: Color(0xFF63A97B),
    warning: gold,
    error: Color(0xFFC86B6B),
    info: Color(0xFF7E96AE),
    disabled: Color(0xFF686E77),
  );

  static AppTokens of(Brightness b) => b == Brightness.dark ? dark : light;

  @override
  AppTokens copyWith({Brightness? brightness}) => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    // Snap at the midpoint — the two palettes are distinct identities, not a
    // continuous ramp; this avoids muddy intermediate greys during a toggle.
    return t < 0.5 ? this : other;
  }
}
