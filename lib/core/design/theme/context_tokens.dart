import 'package:flutter/material.dart';

import '../tokens/siyaq_colors.dart';
import '../tokens/siyaq_motion.dart';
import '../tokens/siyaq_typography.dart';

/// Context-based design-token access — the replacement for the old mutable
/// static palette (`SC`).
///
/// Every value resolves from the enclosing [Theme] via
/// `dependOnInheritedWidgetOfExactType`, which means:
///
///  * **Light and Dark can coexist in one widget tree** — required by the
///    design-system gallery, previews and dual-theme golden tests.
///  * Colour-dependent widgets are correctly invalidated when the theme changes;
///    correctness no longer depends on the app root rebuilding the whole subtree.
///  * A widget rendered in isolation (a test, a `showDialog` with its own theme)
///    gets that theme's palette, not whatever was last set globally.
///
/// ```dart
/// Container(color: context.colors.surface)
/// Text('مرحبا', style: context.type.headingMedium)
/// ```
extension SiyaqThemeContext on BuildContext {
  /// Semantic colours for the nearest enclosing theme.
  ///
  /// Falls back to the brightness-appropriate palette if the extension is
  /// missing, so a widget can never render with the wrong-brightness colours.
  SiyaqColors get colors {
    final theme = Theme.of(this);
    return theme.extension<SiyaqColors>() ?? SiyaqColors.of(theme.brightness);
  }

  /// Typography resolved for the active locale's script and text colour.
  SiyaqTypography get type {
    final theme = Theme.of(this);
    final registered = theme.extension<SiyaqTypography>();
    if (registered != null) return registered;
    final c = colors;
    return SiyaqTypography(
      script: SiyaqTypography.scriptForLocale(
        Localizations.localeOf(this).languageCode,
      ),
      defaultColor: c.textPrimary,
    );
  }

  /// Motion roles resolved against the platform's reduce-motion setting.
  ///
  /// When the user has asked the OS to remove animations
  /// ([MediaQuery.disableAnimationsOf]), every role collapses to
  /// [Duration.zero] — implicit animations legally snap to their end value in
  /// one frame — and [SiyaqMotionResolved.celebrationsEnabled] turns off
  /// pure-decoration effects like confetti. Uses the aspect-scoped MediaQuery
  /// lookup, so widgets do not rebuild on unrelated inset/size changes.
  SiyaqMotionResolved get motion =>
      SiyaqMotionResolved(reduced: MediaQuery.disableAnimationsOf(this));

  /// `true` when the effective theme is dark.
  bool get isDarkTheme => colors.isDark;

  /// Layout direction of the nearest [Directionality]. Prefer this over
  /// inspecting the locale — a subtree may deliberately override direction.
  TextDirection get direction => Directionality.of(this);

  bool get isRtl => direction == TextDirection.rtl;
}

/// Motion roles resolved for the current accessibility settings.
///
/// The raw numbers live in [SiyaqMotion]; this type is the *policy* — the same
/// role reads as its full duration normally and as zero when the platform asks
/// for reduced motion. Call sites hold onto the role, never the raw token, so
/// honouring reduce-motion is not something each screen has to remember.
@immutable
class SiyaqMotionResolved {
  const SiyaqMotionResolved({required this.reduced});

  /// The platform reduce-motion / remove-animations setting.
  final bool reduced;

  Duration _d(Duration full) => reduced ? Duration.zero : full;

  // ── Roles ──────────────────────────────────────────────────────────────────

  /// Instant feedback — press states, selection ticks.
  Duration get instant => _d(SiyaqMotion.instant);

  /// Short interaction — cross-fades, chip/panel state changes.
  Duration get short => _d(SiyaqMotion.short);

  /// Standard transition — route/screen-level swaps.
  Duration get standard => _d(SiyaqMotion.standard);

  /// Emphasized transition — content entrances the eye should follow.
  Duration get emphasized => _d(SiyaqMotion.emphasized);

  /// Attention pulse on an existing element (duplicate-guess row).
  Duration get pulse => _d(SiyaqMotion.pulse);

  /// Rejection nudge (composer shake).
  Duration get nudge => _d(SiyaqMotion.nudge);

  /// Reward flash (Best improved, result-screen pop).
  Duration get reward => _d(SiyaqMotion.reward);

  /// Dwell time for a transient status message. **Not** collapsed under
  /// reduced motion — shortening how long text stays readable would hurt the
  /// people the setting exists for. Reduced motion removes movement, not time.
  Duration get messageDwell => SiyaqMotion.messageDwell;

  // ── Existing scale, resolved ──────────────────────────────────────────────

  Duration get tap => _d(SiyaqMotion.tap);
  Duration get quick => _d(SiyaqMotion.quick);
  Duration get route => _d(SiyaqMotion.route);
  Duration get rowIn => _d(SiyaqMotion.rowIn);
  Duration get summaryIn => _d(SiyaqMotion.summaryIn);
  Duration get barFill => _d(SiyaqMotion.barFill);

  /// Whether pure-decoration celebration effects (confetti) should run at all.
  /// A particle system at duration zero is meaningless, so under reduced
  /// motion celebrations are skipped rather than snapped.
  bool get celebrationsEnabled => !reduced;
}
