/// ─── Organic design system — foundation tokens ───────────────────────────────
///
/// Transcribed from the Claude Design project
/// `a17d4dc4-2b62-41a6-a8c4-bcbc17a8f327`, read through the design MCP on
/// 2026-07-30. Every value here is quoted from `_ds_manifest.json` or the
/// prototype's own `--sy-*` layer — nothing is eyeballed from a screenshot. See
/// `docs/DESIGN_MCP_EXTRACTION.md` for the full record.
///
/// **This layer is additive.** The shipping Siyaq design system
/// (`lib/core/design/tokens/…`, graphite/gold) is untouched, so adoption can
/// proceed screen by screen without a destructive cutover — the migration order
/// the brief itself sets out.
library;

import 'package:flutter/material.dart';

/// Raw Organic palette: the role colours and the three OKLCH tonal ramps.
///
/// Ramps share a perceptual lightness scale, so step *n* of any ramp carries the
/// same visual weight as step *n* of another. Prefer a ramp step over blending:
/// 100–300 for tinted fills, hovers and hairlines; 500 as the role base; 700–900
/// for text on tinted fills and pressed states.
abstract final class OrganicPalette {
  // ── Roles ─────────────────────────────────────────────────────────────────
  static const bg = Color(0xFFF5EAD8);
  static const surface = Color(0xFFEBDDC5);
  static const text = Color(0xFF201E1D);

  /// Terracotta. **Not usable for body copy** — measures ~3:1 on [bg], which the
  /// system documents as sufficient for icons, large text and chrome only. Use
  /// [accent700] for paragraph-size text in the accent.
  static const accent = Color(0xFFC67139);

  /// Sage — a genuine second voice, not a highlight.
  static const accent2 = Color(0xFF7A8A5E);

  /// `--color-divider`: text at 16%.
  static const divider = Color(0x29201E1D);

  // ── Neutral ramp ──────────────────────────────────────────────────────────
  static const neutral100 = Color(0xFFF9F4ED);
  static const neutral200 = Color(0xFFEEE7DB);
  static const neutral300 = Color(0xFFDCD3C4);
  static const neutral400 = Color(0xFFC0B6A5);
  static const neutral500 = Color(0xFFA19786);
  static const neutral600 = Color(0xFF82796A);
  static const neutral700 = Color(0xFF645C50);
  static const neutral800 = Color(0xFF474238);
  static const neutral900 = Color(0xFF2E2B25);

  // ── Accent ramp (terracotta) ──────────────────────────────────────────────
  static const accent100 = Color(0xFFFFF2EB);
  static const accent200 = Color(0xFFFFE1D0);
  static const accent300 = Color(0xFFFFC6A5);
  static const accent400 = Color(0xFFF6A06B);
  static const accent500 = Color(0xFFD67F48);
  static const accent600 = Color(0xFFB2622D);
  static const accent700 = Color(0xFF8C491A);
  static const accent800 = Color(0xFF643312);
  static const accent900 = Color(0xFF402310);

  // ── Accent-2 ramp (sage) ──────────────────────────────────────────────────
  static const accent2100 = Color(0xFFF0FAE1);
  static const accent2200 = Color(0xFFE1EECC);
  static const accent2300 = Color(0xFFCCDBB2);
  static const accent2400 = Color(0xFFAEBF92);
  static const accent2500 = Color(0xFF8FA073);
  static const accent2600 = Color(0xFF728157);
  static const accent2700 = Color(0xFF56633F);
  static const accent2800 = Color(0xFF3D472B);
  static const accent2900 = Color(0xFF272E1B);
}

/// Spacing scale at the system's 1.10× density.
///
/// The fractional values are authored, not rounding noise — the scale is a 4px
/// base multiplied by 1.10. Steps 5 and 7 do not exist in the source and are
/// deliberately absent rather than interpolated.
abstract final class OrganicSpacing {
  static const s1 = 4.4;
  static const s2 = 8.8;
  static const s3 = 13.2;
  static const s4 = 17.6;
  static const s6 = 26.4;
  static const s8 = 35.2;
}

/// Corner radii. The system's instruction is to over-round: [lg] for containers,
/// [pill] for buttons and inputs.
abstract final class OrganicRadius {
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 28.0;
  static const pill = 999.0;
}

/// Elevation, tuned to the warm ground rather than to black.
abstract final class OrganicElevation {
  static const _base = Color(0xFF2E2B25);

  static const sm = <BoxShadow>[
    BoxShadow(color: Color(0x242E2B25), offset: Offset(0, 1), blurRadius: 2),
  ];
  static const md = <BoxShadow>[
    BoxShadow(color: Color(0x292E2B25), offset: Offset(0, 3), blurRadius: 10),
  ];
  static const lg = <BoxShadow>[
    BoxShadow(color: Color(0x382E2B25), offset: Offset(0, 12), blurRadius: 32),
  ];

  /// `--sy-e3` — the bottom-sheet lift, which throws *upward*.
  static const sheetLight = <BoxShadow>[
    BoxShadow(color: Color(0x382E2B25), offset: Offset(0, -10), blurRadius: 34),
  ];
  static const sheetDark = <BoxShadow>[
    BoxShadow(color: Color(0x80000000), offset: Offset(0, -10), blurRadius: 40),
  ];

  /// Kept so the derivation of the alpha values above stays checkable.
  static Color get shadowBase => _base;
}

/// Motion, transcribed from the prototype's keyframes and transitions.
///
/// Only two curves exist in the source; resist adding a third.
abstract final class OrganicMotion {
  /// `cubic-bezier(.22, .9, .24, 1)` — sheets, rise, tie, celebration.
  static const standard = Cubic(0.22, 0.9, 0.24, 1);

  /// `cubic-bezier(.16, 1, .3, 1)` — word travel, pop, splash, ring flash.
  static const expressive = Cubic(0.16, 1, 0.3, 1);

  /// Micro state change (`transition: all/width 180ms`).
  static const micro = Duration(milliseconds: 180);

  /// `sy-rise` and `sy-sheet` — entrance and bottom sheet.
  static const entrance = Duration(milliseconds: 280);

  /// `sy-tie` — Orbit's connecting line growing toward the centre.
  static const tie = Duration(milliseconds: 420);

  /// `transition: transform 820ms` — an Orbit word travelling to its position.
  static const travel = Duration(milliseconds: 820);

  /// `sy-pop`, `sy-splash`, `sy-heart-*` — arrival and celebration.
  static const arrival = Duration(milliseconds: 900);

  /// `sy-ringflash` on the central target.
  static const ringFlash = Duration(milliseconds: 2600);

  // ── Ambient loops ─────────────────────────────────────────────────────────
  // Continuous repaint sources. Suppress under reduced motion and on low-end
  // devices; they are decoration, never feedback.

  /// `sy-breathe` — the central target, scale 1 ↔ 1.05.
  static const breathe = Duration(milliseconds: 5500);

  /// `sy-shimmer` — opacity .2 ↔ .55. Authored at 3.0s, 3.2s and 3.4s so
  /// multiple shimmering elements drift out of phase.
  static const shimmer = Duration(milliseconds: 3200);
  static const shimmerVariants = <Duration>[
    Duration(milliseconds: 3000),
    Duration(milliseconds: 3200),
    Duration(milliseconds: 3400),
  ];

  /// `sy-spin` — the pending spinner.
  static const spin = Duration(milliseconds: 2400);

  /// Loops that must stop when motion is reduced.
  static const ambient = <Duration>[breathe, shimmer, spin];
}

/// Which script a text style is being composed for.
///
/// Caprasimo and Figtree carry no Arabic glyphs, so the display/body pair swaps
/// wholesale for Arabic — which is what the prototype does, and what the shipping
/// app already does for IBM Plex Sans Arabic / Inter.
enum OrganicScript { latin, arabic }

/// Font families, per script.
///
/// All four ship in `assets/fonts/organic/` under SIL OFL 1.1, with their licence
/// texts beside them.
///
/// The names are the **Flutter family names declared in `pubspec.yaml`**, which is
/// what `TextStyle.fontFamily` resolves against — not the CSS names the design
/// uses. `Baloo Bhaijaan 2` in CSS is declared here as `BalooBhaijaan2`; a space
/// in the pubspec family would work but invites silent mismatches.
abstract final class OrganicFonts {
  static const latinDisplay = 'Caprasimo';
  static const latinBody = 'Figtree';
  static const arabicDisplay = 'BalooBhaijaan2';
  static const arabicBody = 'Tajawal';

  /// Families shipped as variable fonts. Their weight must be driven through
  /// `TextStyle.fontVariations` — `fontWeight` alone does not move an axis, a
  /// trap this project already hit once with Inter.
  static const variableFamilies = <String>{latinBody, arabicDisplay};

  static bool isVariable(String family) => variableFamilies.contains(family);

  static String display(OrganicScript s) =>
      s == OrganicScript.arabic ? arabicDisplay : latinDisplay;

  static String body(OrganicScript s) =>
      s == OrganicScript.arabic ? arabicBody : latinBody;

  /// Weights the prototype actually loads. Requesting others would synthesise.
  static const latinDisplayWeights = <FontWeight>[FontWeight.w400];
  static const latinBodyWeights = <FontWeight>[
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w600,
    FontWeight.w700,
  ];
  static const arabicDisplayWeights = <FontWeight>[
    FontWeight.w500,
    FontWeight.w700,
  ];
  static const arabicBodyWeights = <FontWeight>[
    FontWeight.w400,
    FontWeight.w500,
    FontWeight.w700,
  ];
}
