import 'package:flutter/material.dart';

import 'organic_tokens.dart';

/// ─── Siyaq semantic colour layer (`--sy-*`) ──────────────────────────────────
///
/// The prototype defines every `--sy-*` token twice — once for the light,
/// paper-like theme and once for a dark theme — so both are modelled here as one
/// `ThemeExtension` with two instances.
///
/// Read through `Theme.of(context).extension<OrganicColors>()`. As with the
/// shipping design system, **there is no static cached palette**: both themes can
/// render in the same widget tree, which is what makes side-by-side previews and
/// golden tests possible.
@immutable
class OrganicColors extends ThemeExtension<OrganicColors> {
  const OrganicColors({
    required this.brightness,
    required this.background,
    required this.frame,
    required this.surface,
    required this.text,
    required this.muted,
    required this.line,
    required this.gold,
    required this.hot,
    required this.indicator,
    required this.keyboard,
    required this.proximity,
    required this.sheetShadow,
  });

  final Brightness brightness;

  /// `--sy-bg`.
  final Color background;

  /// The app frame behind the screen — a shade deeper than [background]
  /// (`body { background: #e8dcc6 }` in the prototype).
  final Color frame;

  /// `--sy-surface` — cards, sheets, raised content.
  final Color surface;

  /// `--sy-text` / `--sy-muted`.
  final Color text;
  final Color muted;

  /// `--sy-line` — hairlines and dividers.
  final Color line;

  /// `--sy-gold` — the Siyaq brand carry-over.
  final Color gold;

  /// `--sy-hot` — the **background** of the best-guess row, not a foreground.
  /// Pale warm tint in light, deep brown at night; getting these the wrong way
  /// round turns the light theme's hot row almost black.
  final Color hot;

  /// `--sy-indicator` — page/step indicators in their inactive state.
  final Color indicator;

  /// `--sy-kb` — the on-screen keyboard bed.
  final Color keyboard;

  /// `--sy-p1 … --sy-p5`, ordered **far → closest**.
  ///
  /// Taken from `Siyaq Prototype.dc.html`, which is the authority. Note the two
  /// themes are **not** light/dark variants of one ramp: night reaches its
  /// strongest at `#e2704a` while light lands on the deeper `#a33f22`, because
  /// each has to hold its own against a different ground.
  ///
  /// Five tiers, not a continuous gradient. Colour is only one channel: the Orbit
  /// view must also vary radial distance, line weight, scale and the accessible
  /// label, so a player who cannot separate these hues still reads progress.
  final List<Color> proximity;

  /// `--sy-e3` — the upward sheet shadow, which differs per theme.
  final List<BoxShadow> sheetShadow;

  /// Convenience: the strongest tier, used for the closest guess and the target.
  Color get closest => proximity.last;

  /// Convenience: the weakest tier.
  Color get farthest => proximity.first;

  /// Tier colour for a normalised closeness in `[0, 1]`, where 1 is closest.
  ///
  /// Buckets rather than interpolates — the source defines five discrete steps,
  /// and blending them would invent colours the design does not contain.
  Color proximityAt(double t) {
    final clamped = t.isNaN ? 0.0 : t.clamp(0.0, 1.0);
    final index = (clamped * (proximity.length - 1)).round();
    return proximity[index];
  }

  bool get isDark => brightness == Brightness.dark;

  /// The paper theme.
  static const light = OrganicColors(
    brightness: Brightness.light,
    background: OrganicPalette.bg,
    frame: Color(0xFFE8DCC6),
    surface: Color(0xFFFFFAF1),
    text: OrganicPalette.text,
    muted: OrganicPalette.neutral600,
    line: OrganicPalette.neutral300,
    gold: Color(0xFFD9A441),
    hot: Color(0xFFF7E3D3),
    indicator: Color(0xFF3A342C),
    keyboard: Color(0xFFD6CBB8),
    proximity: <Color>[
      OrganicPalette.neutral400,
      OrganicPalette.accent2300,
      OrganicPalette.accent2500,
      OrganicPalette.accent,
      Color(0xFFA33F22),
    ],
    sheetShadow: OrganicElevation.sheetLight,
  );

  /// The dark theme.
  static const dark = OrganicColors(
    brightness: Brightness.dark,
    background: Color(0xFF1C1713),
    frame: Color(0xFF1C1713),
    surface: Color(0xFF2A231C),
    text: Color(0xFFF2E7D6),
    muted: OrganicPalette.neutral500,
    line: Color(0xFF3D342A),
    gold: Color(0xFFE8B559),
    hot: Color(0xFF3A2B20),
    indicator: Color(0xFF5A5046),
    keyboard: Color(0xFF241E18),
    proximity: <Color>[
      OrganicPalette.neutral600,
      OrganicPalette.accent2400,
      OrganicPalette.accent2300,
      OrganicPalette.accent400,
      Color(0xFFE2704A),
    ],
    sheetShadow: OrganicElevation.sheetDark,
  );

  static OrganicColors of(Brightness b) => b == Brightness.dark ? dark : light;

  @override
  OrganicColors copyWith({
    Brightness? brightness,
    Color? background,
    Color? frame,
    Color? surface,
    Color? text,
    Color? muted,
    Color? line,
    Color? gold,
    Color? hot,
    Color? indicator,
    Color? keyboard,
    List<Color>? proximity,
    List<BoxShadow>? sheetShadow,
  }) => OrganicColors(
    brightness: brightness ?? this.brightness,
    background: background ?? this.background,
    frame: frame ?? this.frame,
    surface: surface ?? this.surface,
    text: text ?? this.text,
    muted: muted ?? this.muted,
    line: line ?? this.line,
    gold: gold ?? this.gold,
    hot: hot ?? this.hot,
    indicator: indicator ?? this.indicator,
    keyboard: keyboard ?? this.keyboard,
    proximity: proximity ?? this.proximity,
    sheetShadow: sheetShadow ?? this.sheetShadow,
  );

  @override
  OrganicColors lerp(OrganicColors? other, double t) {
    if (other == null) return this;
    return OrganicColors(
      // Brightness is categorical; snap at the midpoint rather than pretending
      // there is a half-dark theme.
      brightness: t < 0.5 ? brightness : other.brightness,
      background: Color.lerp(background, other.background, t)!,
      frame: Color.lerp(frame, other.frame, t)!,
      surface: Color.lerp(surface, other.surface, t)!,
      text: Color.lerp(text, other.text, t)!,
      muted: Color.lerp(muted, other.muted, t)!,
      line: Color.lerp(line, other.line, t)!,
      gold: Color.lerp(gold, other.gold, t)!,
      hot: Color.lerp(hot, other.hot, t)!,
      indicator: Color.lerp(indicator, other.indicator, t)!,
      keyboard: Color.lerp(keyboard, other.keyboard, t)!,
      proximity: <Color>[
        for (var i = 0; i < proximity.length; i++)
          Color.lerp(proximity[i], other.proximity[i], t)!,
      ],
      sheetShadow: t < 0.5 ? sheetShadow : other.sheetShadow,
    );
  }
}
