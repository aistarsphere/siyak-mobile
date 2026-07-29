/// ─── Organic typography ──────────────────────────────────────────────────────
///
/// Caprasimo over Figtree for Latin, Baloo Bhaijaan 2 over Tajawal for Arabic.
/// The design's own note is that "density moves spacing, not sizes", so the type
/// scale is fixed and only the `--space-*` tokens carry the 1.10× density.
///
/// Two things this layer exists to get right:
///
/// 1. **Variable weight actually applies.** Figtree and Baloo Bhaijaan 2 ship as
///    variable fonts, where `fontWeight` alone does not move the `wght` axis —
///    `fontVariations` must be set too. This project already shipped that bug
///    once with Inter, so [OrganicTextStyles.resolve] always sets both.
/// 2. **Arabic is not Latin with different glyphs.** The design raises Arabic
///    line-height to 1.75 and forbids letter-spacing and uppercase outright, so
///    those are stripped per script rather than left to call sites.
library;

import 'package:flutter/widgets.dart';

import 'organic_tokens.dart';

/// Roles in the type scale.
///
/// Sizes are the prototype's. Display roles use the heading face; everything else
/// uses the body face.
enum OrganicTextRole {
  /// Screen-level wordmark / hero.
  displayLarge(size: 34, weight: FontWeight.w400, display: true, height: 1.15),

  /// Section heading.
  headingLarge(size: 26, weight: FontWeight.w400, display: true, height: 1.2),
  headingMedium(size: 25, weight: FontWeight.w400, display: true, height: 1.2),
  headingSmall(size: 18, weight: FontWeight.w400, display: true, height: 1.25),

  /// The guessed word on a board row or a result row.
  wordLarge(size: 16, weight: FontWeight.w700, height: 1.3),
  wordMedium(size: 15, weight: FontWeight.w700, height: 1.3),

  bodyLarge(size: 15, weight: FontWeight.w400, height: 1.65),
  bodyMedium(size: 14.5, weight: FontWeight.w400, height: 1.6),
  bodySmall(size: 13, weight: FontWeight.w400, height: 1.5),

  /// Board labels — the word drawn beside a thread tip.
  labelBoard(size: 13, weight: FontWeight.w600, height: 1.2),
  labelBoardQuiet(size: 11.5, weight: FontWeight.w600, height: 1.2),

  /// Band tags and pills.
  tag(size: 10, weight: FontWeight.w700, height: 1.2, tracking: 0),

  /// Kickers. `letterSpacing` .14em ≈ 1.54 at 11px — **Latin only**; the design
  /// forbids tracking in Arabic, so [OrganicTextStyles.resolve] drops it.
  kicker(size: 11, weight: FontWeight.w600, height: 1.3, tracking: 1.54),

  meta(size: 12, weight: FontWeight.w600, height: 1.4);

  const OrganicTextRole({
    required this.size,
    required this.weight,
    required this.height,
    this.display = false,
    this.tracking = 0,
  });

  final double size;
  final FontWeight weight;

  /// Latin line-height multiplier. Arabic overrides this — see
  /// [OrganicTextStyles.arabicHeight].
  final double height;

  /// Whether this role uses the heading face rather than the body face.
  final bool display;

  /// Latin letter-spacing in logical pixels. Never applied to Arabic.
  final double tracking;
}

/// Builds [TextStyle]s for the Organic system.
abstract final class OrganicTextStyles {
  /// The design raises Arabic line-height to 1.75 for readable Naskh-derived
  /// shapes. Applied as a floor, so a role that already breathes more keeps its
  /// own value.
  static const arabicHeight = 1.75;

  /// Caprasimo has a single weight; asking for another would synthesise a fake
  /// bold. Baloo Bhaijaan 2 covers 400–800, Figtree 300–900.
  static const _variableRange = <String, (double, double)>{
    OrganicFonts.latinBody: (300, 900),
    OrganicFonts.arabicDisplay: (400, 800),
  };

  /// A style for [role] in [script].
  ///
  /// Pass [color] explicitly; this layer deliberately does not reach for a theme,
  /// so it stays usable in tests, previews and painters.
  static TextStyle resolve(
    OrganicTextRole role, {
    required OrganicScript script,
    Color? color,
    FontWeight? weight,
    double? sizeOverride,
  }) {
    final arabic = script == OrganicScript.arabic;
    final family = role.display
        ? OrganicFonts.display(script)
        : OrganicFonts.body(script);
    final resolvedWeight = weight ?? role.weight;

    return TextStyle(
      fontFamily: family,
      fontSize: sizeOverride ?? role.size,
      fontWeight: resolvedWeight,
      // Variable families need the axis driven explicitly; static ones must not
      // carry a variation or the shaper may ignore the weight entirely.
      fontVariations: OrganicFonts.isVariable(family)
          ? <FontVariation>[
              FontVariation('wght', _clampWeight(family, resolvedWeight)),
            ]
          : null,
      height: arabic
          ? (role.height > arabicHeight ? role.height : arabicHeight)
          : role.height,
      // The design forbids letter-spacing in Arabic. Silently dropping it here is
      // safer than trusting every call site to remember.
      letterSpacing: arabic || role.tracking == 0 ? null : role.tracking,
      color: color,
    );
  }

  /// Keeps a requested weight inside the axis the file actually carries, so a
  /// w900 request on a 400–800 face clamps instead of falling back.
  static double _clampWeight(String family, FontWeight weight) {
    final range = _variableRange[family];
    final value = weight.value.toDouble();
    if (range == null) return value;
    return value.clamp(range.$1, range.$2);
  }

  /// Whether text in [script] may be uppercased.
  ///
  /// Arabic has no case, and the design forbids the transform outright — a
  /// `toUpperCase()` on Arabic is a no-op at best and a signal of a copied Latin
  /// pattern at worst.
  static bool allowsUppercase(OrganicScript script) =>
      script == OrganicScript.latin;

  /// Script for a language code, matching how the app already resolves type.
  static OrganicScript scriptForLanguage(String? code) =>
      (code ?? '').toLowerCase().startsWith('ar')
      ? OrganicScript.arabic
      : OrganicScript.latin;
}
