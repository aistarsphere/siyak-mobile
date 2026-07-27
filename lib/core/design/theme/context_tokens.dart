import 'package:flutter/material.dart';

import '../tokens/siyaq_colors.dart';
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

  /// `true` when the effective theme is dark.
  bool get isDarkTheme => colors.isDark;

  /// Layout direction of the nearest [Directionality]. Prefer this over
  /// inspecting the locale — a subtree may deliberately override direction.
  TextDirection get direction => Directionality.of(this);

  bool get isRtl => direction == TextDirection.rtl;
}
