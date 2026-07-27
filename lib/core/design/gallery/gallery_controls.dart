import 'package:flutter/material.dart';

import '../tokens/siyaq_typography.dart';

/// The validation axes the gallery can vary.
///
/// Every axis in the audit's gallery requirements (§19) is represented so a
/// component can be checked at Light/Dark × AR/EN × text-scale × viewport in one
/// place, rather than by launching the app repeatedly.
@immutable
class GalleryAxes {
  const GalleryAxes({
    this.themeMode = GalleryThemeMode.sideBySide,
    this.language = GalleryLanguage.both,
    this.textScale = 1.0,
    this.viewport = GalleryViewport.free,
    this.showTouchTargets = false,
  });

  final GalleryThemeMode themeMode;
  final GalleryLanguage language;
  final double textScale;
  final GalleryViewport viewport;

  /// Overlay the 44×44 minimum touch target on interactive samples.
  final bool showTouchTargets;

  GalleryAxes copyWith({
    GalleryThemeMode? themeMode,
    GalleryLanguage? language,
    double? textScale,
    GalleryViewport? viewport,
    bool? showTouchTargets,
  }) => GalleryAxes(
    themeMode: themeMode ?? this.themeMode,
    language: language ?? this.language,
    textScale: textScale ?? this.textScale,
    viewport: viewport ?? this.viewport,
    showTouchTargets: showTouchTargets ?? this.showTouchTargets,
  );
}

enum GalleryThemeMode {
  light('Light'),
  dark('Dark'),

  /// Follows the OS — validates `ThemeMode.system`.
  system('System'),

  /// Light and Dark rendered **simultaneously**. Impossible before the
  /// context-token refactor, and the primary regression check for theme work.
  sideBySide('Light + Dark');

  const GalleryThemeMode(this.label);
  final String label;
}

enum GalleryLanguage {
  arabic('العربية', 'ar', TextDirection.rtl, SiyaqScript.arabic),
  english('English', 'en', TextDirection.ltr, SiyaqScript.latin),

  /// Arabic RTL and English LTR side by side.
  both('AR + EN', 'ar', TextDirection.rtl, SiyaqScript.arabic);

  const GalleryLanguage(this.label, this.code, this.direction, this.script);

  final String label;
  final String code;
  final TextDirection direction;
  final SiyaqScript script;
}

/// Device widths worth validating. 320 px is the failure-prone floor.
enum GalleryViewport {
  free('Free', null),
  small('320', 320),
  standard('390', 390),
  large('430', 430),
  tablet('768', 768);

  const GalleryViewport(this.label, this.width);
  final String label;
  final double? width;
}

/// Text scales the gallery exposes, matching [SiyaqA11y.validationScales].
const kGalleryTextScales = <(String, double)>[
  ('1.0', 1.0),
  ('1.3', 1.3),
  ('2.0', 2.0),
];
