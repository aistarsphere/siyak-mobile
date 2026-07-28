import 'package:flutter/material.dart';

/// ─── Siyaq semantic colour tokens ────────────────────────────────────────────
///
/// The single source of truth for colour. Registered on `ThemeData.extensions`
/// and read through `context.colors` (see `theme/context_tokens.dart`).
///
/// **Never read colour from a global.** There is no static cached palette: every
/// value resolves from the enclosing [Theme], so Light and Dark can render in the
/// same widget tree (previews, tests, the design-system gallery).
///
/// ## Value provenance
///
/// Structure (role names, groups, game-mode accents, focus + on-action roles)
/// follows the approved Figma system documented in `FIGMA_FLUTTER_UI_AUDIT.md`.
/// **Values are the app's existing graphite/gold identity**, carried over
/// verbatim from the previous `AppTokens` so Phase 1 is visually a no-op.
/// Adopting Figma's warm-stone/saffron values is product decision **D2** and is
/// deliberately *not* made here.
///
/// Roles that Figma specifies but the old palette lacked ([onAction],
/// [borderFocus], [surfaceDisabled], [textInverse], the `game*` accents and the
/// `*Subtle` fills) are new. They are additive — nothing in the app reads them
/// yet, so they cannot change current rendering.
@immutable
class SiyaqColors extends ThemeExtension<SiyaqColors> {
  const SiyaqColors({
    required this.brightness,
    required this.background,
    required this.surface,
    required this.surfaceElevated,
    required this.surfaceStrong,
    required this.surfaceDisabled,
    required this.textPrimary,
    required this.textSecondary,
    required this.textMuted,
    required this.textDisabled,
    required this.textInverse,
    required this.border,
    required this.borderStrong,
    required this.borderFocus,
    required this.divider,
    required this.iconPrimary,
    required this.iconSecondary,
    required this.primary,
    required this.primaryStrong,
    required this.primaryContainer,
    required this.onPrimary,
    required this.actionSecondary,
    required this.onActionSecondary,
    required this.actionDestructive,
    required this.onActionDestructive,
    required this.success,
    required this.successSubtle,
    required this.warning,
    required this.warningSubtle,
    required this.error,
    required this.errorSubtle,
    required this.info,
    required this.infoSubtle,
    required this.gameSolo,
    required this.gameWeekly,
    required this.gameMultiplayer,
    required this.gameRanked,
    required this.gamePractice,
    required this.shadow,
    required this.scrim,
  });

  final Brightness brightness;

  // ── Surfaces (background < surface < elevated < strong) ────────────────────
  final Color background;
  final Color surface;
  final Color surfaceElevated;
  final Color surfaceStrong;
  final Color surfaceDisabled;

  // ── Text ──────────────────────────────────────────────────────────────────
  final Color textPrimary;
  final Color textSecondary;
  final Color textMuted;
  final Color textDisabled;

  /// Text on an inverted surface (e.g. a dark toast in Light theme).
  final Color textInverse;

  // ── Lines ─────────────────────────────────────────────────────────────────
  final Color border;
  final Color borderStrong;

  /// Focus ring colour. Figma mandates a visible 2px ring on every interactive
  /// component but never defined the token; gold is the natural carrier here.
  final Color borderFocus;
  final Color divider;

  // ── Icons ─────────────────────────────────────────────────────────────────
  final Color iconPrimary;
  final Color iconSecondary;

  // ── Primary action (gold) ─────────────────────────────────────────────────
  final Color primary;
  final Color primaryStrong; // pressed / active
  final Color primaryContainer; // soft translucent gold fill

  /// Correct foreground for [primary] fills. Also exposed as [onAction].
  /// Contrast-correct in **both** themes.
  final Color onPrimary;

  /// Foreground for primary-action fills.
  ///
  /// Figma's `Gameplay` page binds `action/primary/text` to **white**, which
  /// measures only **3.19:1** on `action/primary/bg` `#d97706` — a WCAG AA
  /// failure for normal text. The graphite foreground kept here measures
  /// **5.49:1** on the same fill and **5.99:1** on the app's own gold, so it is
  /// retained deliberately in preference to the Figma value.
  Color get onAction => onPrimary;

  // ── Secondary / destructive actions ───────────────────────────────────────
  final Color actionSecondary;
  final Color onActionSecondary;
  final Color actionDestructive;
  final Color onActionDestructive;

  // ── Status ────────────────────────────────────────────────────────────────
  final Color success;
  final Color successSubtle;
  final Color warning;
  final Color warningSubtle;
  final Color error;
  final Color errorSubtle;
  final Color info;
  final Color infoSubtle;

  // ── Game-mode accents ─────────────────────────────────────────────────────
  //
  // Figma reuses one palette for game modes *and* status, so `game/ranked` is
  // pixel-identical to `status/error` and `game/practice` to `status/success`
  // (audit §11-10). These are deliberately kept distinct from the status roles
  // so a ranked surface can never be mistaken for an error surface.
  final Color gameSolo;
  final Color gameWeekly;
  final Color gameMultiplayer;
  final Color gameRanked;
  final Color gamePractice;

  // ── Depth ─────────────────────────────────────────────────────────────────
  final Color shadow;
  final Color scrim;

  bool get isDark => brightness == Brightness.dark;

  /// Game-mode accent by key, for data-driven mode rendering.
  Color gameAccent(String mode) => switch (mode.toLowerCase()) {
    'weekly' => gameWeekly,
    'multiplayer' || 'room' || 'social' => gameMultiplayer,
    'ranked' => gameRanked,
    'practice' => gamePractice,
    _ => gameSolo,
  };

  // ── Semantic distance ramp (gameplay) ─────────────────────────────────────
  //
  // The six `distance/*` tokens now bound on Figma's `Gameplay` page — the one
  // page in the file with real variable bindings, added after the audit was
  // written. Provided here so Phase 3's gameplay components have a canonical
  // ramp; **nothing reads them yet**. The app still renders the continuous
  // [SiyaqHeat] ramp, and switching to discrete bands is decision **D3**.
  //
  // ⚠️ These are **indicator** colours, not text colours. Measured against
  // `surface/base` `#ffffff` they range 1.69:1–2.80:1, so all six fail WCAG AA
  // as text — yet Figma's own Guess Card uses them for a 20px bold number.
  // Use them for bars, rails and dots; pair with [textPrimary] for the numeral.
  static const distanceVeryFar = Color(0xFFFB7185);
  static const distanceFar = Color(0xFFF97316);
  static const distanceCloser = Color(0xFFF59E0B);
  static const distanceClose = Color(0xFFF9BD4E);
  static const distanceVeryClose = Color(0xFF34D399);
  static const distanceCorrect = Color(0xFF10B981);

  /// The ramp cold → hot, ordered far → correct.
  static const distanceRamp = <Color>[
    distanceVeryFar,
    distanceFar,
    distanceCloser,
    distanceClose,
    distanceVeryClose,
    distanceCorrect,
  ];

  // ── Brand constants ───────────────────────────────────────────────────────
  // Gameplay closeness ramp (cold → warm → hot). Interpolated continuously by
  // `SiyaqHeat.color`; identical in both themes because "hot" must read hot on
  // any background. Kept here so every palette value in the app lives in one
  // file, not scattered through the gameplay layer.
  static const heatCold = Color(0xFF2DD4E8);
  static const heatWarm = Color(0xFFFF8A4A);
  static const heatHot = Color(0xFFFF4436);

  /// The gameplay heat ramp in order, for gallery/documentation use.
  static const heatRamp = <(String, Color)>[
    ('heatCold', heatCold),
    ('heatWarm', heatWarm),
    ('heatHot', heatHot),
  ];

  static const graphiteDeep = Color(0xFF1B1D22);
  static const _onDark = Color(0xFFF5F6F8);
  static const goldDark = Color(0xFFDDB75F);
  static const goldLight = Color(0xFFCDA34B);

  /// Contrast-correct foreground for an arbitrary [fill].
  ///
  /// Picks whichever of the two brand foregrounds achieves the higher WCAG
  /// contrast ratio, rather than guessing from a luminance threshold. Use this
  /// for dynamic fills (game accents, heat colours) where no fixed `on*` token
  /// exists. For the primary action use [onAction].
  Color foregroundOn(Color fill) =>
      _contrast(graphiteDeep, fill) >= _contrast(_onDark, fill)
      ? graphiteDeep
      : _onDark;

  // `onColorLegacy` — the old `SC.onColor` luminance-threshold rule, which was
  // measurably wrong in Light theme (2.19:1 on the primary button) — was
  // retired once its last call site migrated to [onAction]/[foregroundOn].
  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance(), lb = b.computeLuminance();
    final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
    return (hi + 0.05) / (lo + 0.05);
  }

  // ── Dark ──────────────────────────────────────────────────────────────────
  static const dark = SiyaqColors(
    brightness: Brightness.dark,
    background: Color(0xFF17191E),
    surface: Color(0xFF23262D),
    surfaceElevated: Color(0xFF2C3038),
    surfaceStrong: Color(0xFF343944),
    surfaceDisabled: Color(0xFF23262D),
    textPrimary: Color(0xFFF4F1EA), // warm near-white
    textSecondary: Color(0xFFC4C8CE),
    textMuted: Color(0xFF8C929C),
    textDisabled: Color(0xFF5C626C),
    textInverse: Color(0xFF262A31),
    border: Color(0xFF313640),
    borderStrong: Color(0xFF3C424D),
    borderFocus: goldDark,
    divider: Color(0xFF262A31),
    iconPrimary: Color(0xFFF4F1EA),
    iconSecondary: Color(0xFF8C929C),
    primary: goldDark,
    primaryStrong: Color(0xFFC79B45),
    primaryContainer: Color(0x29DDB75F), // gold @ ~16%
    onPrimary: graphiteDeep,
    actionSecondary: Color(0xFF2C3038),
    onActionSecondary: Color(0xFFF4F1EA),
    // The dark error red is light enough that a *graphite* label out-contrasts a
    // white one (5.21:1 vs 2.99:1). Chosen by measurement, not by convention.
    actionDestructive: Color(0xFFE06B6B),
    onActionDestructive: graphiteDeep,
    success: Color(0xFF57B37E),
    successSubtle: Color(0x2957B37E),
    warning: goldDark,
    warningSubtle: Color(0x29DDB75F),
    error: Color(0xFFE06B6B),
    errorSubtle: Color(0x29E06B6B),
    info: Color(0xFF7FA0BE),
    infoSubtle: Color(0x297FA0BE),
    gameSolo: goldDark,
    gameWeekly: Color(0xFFA78BFA), // violet
    gameMultiplayer: Color(0xFF4ECDC4), // teal
    gameRanked: Color(0xFFF0709B), // rose — distinct from `error`
    gamePractice: Color(0xFFA3D977), // lime — distinct from `success`
    shadow: Color(0x66000000),
    scrim: Color(0x99000000),
  );

  // ── Light ─────────────────────────────────────────────────────────────────
  static const light = SiyaqColors(
    brightness: Brightness.light,
    background: Color(0xFFF7F5F0),
    surface: Color(0xFFFFFFFF),
    surfaceElevated: Color(0xFFF1ECE2),
    surfaceStrong: Color(0xFFE8E2D5),
    surfaceDisabled: Color(0xFFEDEAE3),
    textPrimary: Color(0xFF262A31), // deep charcoal, not black
    textSecondary: Color(0xFF58606B),
    textMuted: Color(0xFF6E747E), // AA-readable muted (not disabled)
    textDisabled: Color(0xFFAEB2BA),
    textInverse: Color(0xFFF4F1EA),
    border: Color(0xFFE4E0D7),
    borderStrong: Color(0xFFD4CFC3),
    borderFocus: Color(0xFFB78D3A),
    divider: Color(0xFFECE8DF),
    iconPrimary: Color(0xFF262A31),
    iconSecondary: Color(0xFF58606B),
    primary: goldLight,
    primaryStrong: Color(0xFFB78D3A),
    primaryContainer: Color(0x24CDA34B), // gold @ ~14%
    onPrimary: Color(0xFF262A31),
    actionSecondary: Color(0xFFF1ECE2),
    onActionSecondary: Color(0xFF262A31),
    // Deliberately deeper than the light `error` red (`#C85A5A`), which cannot
    // reach AA with *either* foreground (4.07:1 graphite / 3.83:1 white). This
    // fill gives 5.04:1 with a white label. `error` itself is unchanged, so
    // existing status text keeps its current appearance.
    actionDestructive: Color(0xFFB34545),
    onActionDestructive: _onDark,
    success: Color(0xFF3E9A66),
    successSubtle: Color(0x243E9A66),
    warning: Color(0xFFB78D3A),
    warningSubtle: Color(0x24B78D3A),
    error: Color(0xFFC85A5A),
    errorSubtle: Color(0x24C85A5A),
    info: Color(0xFF5B7C9E),
    infoSubtle: Color(0x245B7C9E),
    gameSolo: Color(0xFFB78D3A),
    gameWeekly: Color(0xFF7C4DBF),
    gameMultiplayer: Color(0xFF0E7C74),
    gameRanked: Color(0xFFC2185B),
    gamePractice: Color(0xFF5E8C3A),
    shadow: Color(0x14000000),
    scrim: Color(0x66000000),
  );

  static SiyaqColors of(Brightness b) => b == Brightness.dark ? dark : light;

  @override
  SiyaqColors copyWith({Brightness? brightness}) => this;

  @override
  SiyaqColors lerp(ThemeExtension<SiyaqColors>? other, double t) {
    if (other is! SiyaqColors) return this;
    // The two palettes are distinct identities, not a continuous ramp; snap at
    // the midpoint to avoid muddy intermediate greys during a toggle.
    return t < 0.5 ? this : other;
  }
}
