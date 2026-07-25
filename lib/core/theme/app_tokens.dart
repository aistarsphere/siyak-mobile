import 'package:flutter/material.dart';

/// Centralized **semantic design tokens** for the Siyaq graphite/gold identity.
/// Spec + role table: `docs/DESIGN_SYSTEM.md`.
///
/// A single [AppTokens] definition drives both the custom Siyaq screens (via the
/// [SC] accessor) and Material components (registered as a [ThemeExtension] on
/// `ThemeData`). Screens reference roles, never raw hex.
@immutable
class AppTokens extends ThemeExtension<AppTokens> {
  const AppTokens({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceStrong,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.border,
    required this.borderStrong,
    required this.divider,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.primary,
    required this.primaryStrong,
    required this.primaryContainer,
    required this.onPrimary,
    required this.success,
    required this.warning,
    required this.error,
    required this.info,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;

  // Surfaces (background < surface < elevated < strong)
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceStrong;

  // Text
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  // Lines
  final Color border;
  final Color borderStrong;
  final Color divider;

  // Icons
  final Color iconPrimary;
  final Color iconSecondary;

  // Primary = **gold** (the interaction color). Dark charcoal text sits on it.
  final Color primary;
  final Color primaryStrong; // pressed / active
  final Color primaryContainer; // soft translucent gold fill (chips, badges)
  final Color onPrimary;

  // Status
  final Color success;
  final Color warning;
  final Color error;
  final Color info;

  // Depth
  final Color shadow;
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  // ── Brand constants ───────────────────────────────────────────────────────
  static const graphiteDeep = Color(0xFF1B1D22);
  static const goldDark = Color(0xFFDDB75F); // dark-theme primary
  static const goldLight = Color(0xFFCDA34B); // light-theme primary

  static const dark = AppTokens(
    brightness: Brightness.dark,
    background: Color(0xFF17191E),
    surface: Color(0xFF23262D),
    surfaceElevated: Color(0xFF2C3038),
    surfaceStrong: Color(0xFF343944),
    textPrimary: Color(0xFFF4F1EA), // warm near-white
    textSecondary: Color(0xFFC4C8CE),
    textMuted: Color(0xFF8C929C),
    textDisabled: Color(0xFF5C626C),
    border: Color(0xFF313640),
    borderStrong: Color(0xFF3C424D),
    divider: Color(0xFF262A31),
    iconPrimary: Color(0xFFF4F1EA),
    iconSecondary: Color(0xFF8C929C),
    primary: goldDark,
    primaryStrong: Color(0xFFC79B45),
    primaryContainer: Color(0x29DDB75F), // gold @ ~16%
    onPrimary: graphiteDeep,
    success: Color(0xFF57B37E),
    warning: goldDark,
    error: Color(0xFFE06B6B),
    info: Color(0xFF7FA0BE),
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
  );

  static const light = AppTokens(
    brightness: Brightness.light,
    background: Color(0xFFF7F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1ECE2),
    surfaceStrong: Color(0xFFE8E2D5),
    textPrimary: Color(0xFF262A31), // deep charcoal, not black
    textSecondary: Color(0xFF58606B),
    textMuted: Color(0xFF6E747E), // AA-readable muted (not disabled)
    textDisabled: Color(0xFFAEB2BA),
    border: Color(0xFFE4E0D7),
    borderStrong: Color(0xFFD4CFC3),
    divider: Color(0xFFECE8DF),
    iconPrimary: Color(0xFF262A31),
    iconSecondary: Color(0xFF58606B),
    primary: goldLight,
    primaryStrong: Color(0xFFB78D3A),
    primaryContainer: Color(0x24CDA34B), // gold @ ~14%
    onPrimary: Color(0xFF262A31),
    success: Color(0xFF3E9A66),
    warning: Color(0xFFB78D3A),
    error: Color(0xFFC85A5A),
    info: Color(0xFF5B7C9E),
    shadow: Color(0x14000000),
    scrim: Color(0x66000000),
  );

  static AppTokens of(Brightness b) => b == Brightness.dark ? dark : light;

  @override
  AppTokens copyWith({Brightness? brightness}) => this;

  @override
  AppTokens lerp(ThemeExtension<AppTokens>? other, double t) {
    if (other is! AppTokens) return this;
    // The two palettes are distinct identities, not a continuous ramp; snap at
    // the midpoint to avoid muddy intermediate greys during a toggle.
    return t < 0.5 ? this : other;
  }
}
