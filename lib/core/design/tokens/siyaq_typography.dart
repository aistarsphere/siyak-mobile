import 'package:flutter/material.dart';

/// Bundled font families. No runtime fetching — every family ships in `assets/`.
class SiyaqFonts {
  SiyaqFonts._();

  /// Arabic game content and UI copy (Noto Naskh Arabic).
  static const arabic = 'NotoNaskhArabic';

  /// Latin / system base (Plus Jakarta Sans).
  static const latin = 'PlusJakartaSans';

  /// Ranks, numbers, timers, kicker labels (DM Mono).
  static const mono = 'DMMono';

  /// Fallback chain for a primary family.
  ///
  /// No bundled family covers both scripts: Plus Jakarta Sans and DM Mono have
  /// no Arabic glyphs, and Noto Naskh Arabic has no Latin design. Mixed-script
  /// strings are unavoidable in this product — a player's display name, a room
  /// code beside an Arabic label, an English category in an Arabic sentence — so
  /// every style declares the other families as fallbacks. Without this, the
  /// non-primary script renders as tofu boxes (the failure mode the audit found
  /// in Figma, where Inter is specified for Arabic text).
  static List<String> fallbackFor(String primary) => switch (primary) {
    arabic => const [latin, mono],
    mono => const [latin, arabic],
    _ => const [arabic, mono],
  };
}

/// Named typography roles, replacing anonymous per-call-site font sizes.
///
/// ## Metrics provenance
///
/// Size, weight, line-height and letter-spacing are taken **verbatim from the
/// Figma `Siyaq/*` text styles** now bound on the `Gameplay` page (`48:2`),
/// which the audit could not see — at audit time no style carried a line-height
/// or letter-spacing anywhere in the file (audit §3, §11-20). Ratios are stored
/// rather than absolute pixel leading so a role scales correctly.
///
/// `displayLarge` (40px) is the one exception: it appears on Foundations but not
/// among the bound styles, so its leading and tracking are **extrapolated** from
/// the tightening trend of the display ramp.
///
/// ## Script handling
///
/// Figma specifies **Inter for both scripts**, which cannot work — Inter ships no
/// Arabic glyphs, so Arabic would silently fall back to a system face
/// (audit §11-15). Pending product decision **D1**, Arabic uses the bundled Noto
/// Naskh Arabic and Latin uses Plus Jakarta Sans, resolved **per script at render
/// time** rather than per call site.
///
/// Two deliberate deviations for Arabic, which Figma is silent on:
///
///  * **Looser leading** — Naskh ascenders/descenders and diacritics need more
///    vertical room than Latin at the same size, so [arabicHeight] adds ~0.15.
///  * **No letter-spacing** — Arabic is a cursive joining script; positive
///    tracking visually breaks the connections between letters. Latin tracking is
///    therefore dropped for Arabic (see [SiyaqTypography.role]).
enum SiyaqTextRole {
  // size, weight, latin line-height ratio, latin letter-spacing
  displayLarge(40, FontWeight.w700, 1.20, -0.4),
  displayMedium(32, FontWeight.w700, 1.25, -0.3),
  displaySmall(28, FontWeight.w600, 1.286, -0.2),
  headingLarge(24, FontWeight.w700, 1.333, -0.2),
  headingMedium(20, FontWeight.w600, 1.40, 0),
  headingSmall(18, FontWeight.w600, 1.333, 0),
  bodyLarge(16, FontWeight.w400, 1.50, 0),
  bodyMedium(14, FontWeight.w400, 1.429, 0),
  bodySmall(12, FontWeight.w400, 1.333, 0.1),
  labelLarge(14, FontWeight.w500, 1.429, 0.1),
  labelMedium(12, FontWeight.w500, 1.333, 0.2),
  labelSmall(10, FontWeight.w500, 1.40, 0.3),
  buttonLarge(16, FontWeight.w600, 1.50, 0.2),
  buttonMedium(14, FontWeight.w600, 1.429, 0.2),

  /// The large distance/rank readout on a guess row (`Siyaq/Game/Distance`).
  gameDistance(20, FontWeight.w700, 1.40, 0);

  const SiyaqTextRole(
    this.size,
    this.weight,
    this.latinHeight,
    this.latinTracking,
  );

  final double size;
  final FontWeight weight;

  /// Line-height multiplier for Latin, from the bound Figma style.
  final double latinHeight;

  /// Letter-spacing in logical pixels for Latin, from the bound Figma style.
  final double latinTracking;

  /// Line-height multiplier for Arabic — looser than [latinHeight] so Naskh
  /// diacritics are not clipped.
  double get arabicHeight => latinHeight + 0.15;
}

/// Which script a text style should be shaped for.
enum SiyaqScript {
  /// Arabic — [SiyaqFonts.arabic], looser line-height.
  arabic,

  /// Latin — [SiyaqFonts.latin].
  latin,

  /// Tabular / numeric — [SiyaqFonts.mono]. Ranks, timers, room codes.
  mono,
}

/// Resolved text styles for one script, exposed via `context.type`.
///
/// Instances are const-constructed per (script × colour) pair by
/// `context_tokens.dart`; nothing is cached in a global.
@immutable
class SiyaqTypography extends ThemeExtension<SiyaqTypography> {
  const SiyaqTypography({required this.script, required this.defaultColor});

  /// Default script for unqualified lookups, derived from the active locale.
  final SiyaqScript script;

  /// Colour applied when a call site does not override it.
  final Color defaultColor;

  TextStyle role(
    SiyaqTextRole role, {
    SiyaqScript? script,
    Color? color,
    FontWeight? weight,
    double? letterSpacing,
    double? height,
  }) {
    final s = script ?? this.script;
    final isArabic = s == SiyaqScript.arabic;
    final family = _familyFor(s);
    return TextStyle(
      fontFamily: family,
      fontFamilyFallback: SiyaqFonts.fallbackFor(family),
      fontSize: role.size,
      fontWeight: weight ?? role.weight,
      color: color ?? defaultColor,
      height: height ?? (isArabic ? role.arabicHeight : role.latinHeight),
      // Arabic is cursive: positive tracking breaks letter joining, so the
      // Latin tracking from Figma is dropped unless explicitly overridden.
      letterSpacing: letterSpacing ?? (isArabic ? null : role.latinTracking),
    );
  }

  /// Escape hatch for an explicit pixel size, bypassing the named scale.
  ///
  /// Exists so the migration bridge (`context.legacyType`) can reproduce the old
  /// `ST.*` metrics **exactly**, keeping Phase 1 pixel-identical. New code must
  /// use [role] — a raw size here defeats the purpose of the scale.
  TextStyle custom({
    required SiyaqScript script,
    required double size,
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
    double? letterSpacing,
  }) => TextStyle(
    fontFamily: _familyFor(script),
    fontFamilyFallback: SiyaqFonts.fallbackFor(_familyFor(script)),
    fontSize: size,
    fontWeight: weight,
    color: color ?? defaultColor,
    height: height,
    letterSpacing: letterSpacing,
  );

  // ── Convenience accessors ─────────────────────────────────────────────────
  TextStyle get displayLarge => role(SiyaqTextRole.displayLarge);
  TextStyle get displayMedium => role(SiyaqTextRole.displayMedium);
  TextStyle get displaySmall => role(SiyaqTextRole.displaySmall);
  TextStyle get headingLarge => role(SiyaqTextRole.headingLarge);
  TextStyle get headingMedium => role(SiyaqTextRole.headingMedium);
  TextStyle get headingSmall => role(SiyaqTextRole.headingSmall);
  TextStyle get bodyLarge => role(SiyaqTextRole.bodyLarge);
  TextStyle get bodyMedium => role(SiyaqTextRole.bodyMedium);
  TextStyle get bodySmall => role(SiyaqTextRole.bodySmall);
  TextStyle get labelLarge => role(SiyaqTextRole.labelLarge);
  TextStyle get labelMedium => role(SiyaqTextRole.labelMedium);
  TextStyle get labelSmall => role(SiyaqTextRole.labelSmall);

  /// Mono numeric style — ranks, timers, room codes.
  TextStyle numeric(SiyaqTextRole r, {Color? color, double? letterSpacing}) =>
      role(
        r,
        script: SiyaqScript.mono,
        color: color,
        letterSpacing: letterSpacing,
      );

  /// Uppercase mono kicker (matches the existing `Kicker` widget's metrics).
  TextStyle get kicker => role(
    SiyaqTextRole.labelSmall,
    script: SiyaqScript.mono,
    letterSpacing: 1.8,
  );

  static String _familyFor(SiyaqScript s) => switch (s) {
    SiyaqScript.arabic => SiyaqFonts.arabic,
    SiyaqScript.latin => SiyaqFonts.latin,
    SiyaqScript.mono => SiyaqFonts.mono,
  };

  /// Build the Material [TextTheme] so framework widgets inherit the scale.
  TextTheme toTextTheme() => TextTheme(
    displayLarge: displayLarge,
    displayMedium: displayMedium,
    displaySmall: displaySmall,
    headlineMedium: headingLarge,
    headlineSmall: headingMedium,
    titleLarge: headingMedium,
    titleMedium: headingSmall,
    titleSmall: labelLarge,
    bodyLarge: bodyLarge,
    bodyMedium: bodyMedium,
    bodySmall: bodySmall,
    labelLarge: labelLarge,
    labelMedium: labelMedium,
    labelSmall: labelSmall,
  );

  /// Script for a locale code. Arabic is the primary locale.
  static SiyaqScript scriptForLocale(String languageCode) =>
      languageCode == 'ar' ? SiyaqScript.arabic : SiyaqScript.latin;

  @override
  SiyaqTypography copyWith({SiyaqScript? script, Color? defaultColor}) =>
      SiyaqTypography(
        script: script ?? this.script,
        defaultColor: defaultColor ?? this.defaultColor,
      );

  @override
  SiyaqTypography lerp(ThemeExtension<SiyaqTypography>? other, double t) {
    if (other is! SiyaqTypography) return this;
    return t < 0.5 ? this : other;
  }
}
