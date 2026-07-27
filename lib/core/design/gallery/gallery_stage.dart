import 'package:flutter/material.dart';

import '../theme/context_tokens.dart';
import '../theme/siyaq_theme_data.dart';
import '../tokens/siyaq_spacing.dart';
import '../tokens/siyaq_typography.dart';
import 'gallery_controls.dart';

/// Renders gallery content under a specific set of validation axes.
///
/// Each pane installs its own [Theme], [Directionality], [Localizations] and
/// [MediaQuery] text scale, so several panes with **different themes and
/// directions coexist in one tree** — the capability the context-token refactor
/// unlocked.
class GalleryStage extends StatelessWidget {
  const GalleryStage({super.key, required this.axes, required this.builder});

  final GalleryAxes axes;

  /// Content, rebuilt once per pane.
  final WidgetBuilder builder;

  @override
  Widget build(BuildContext context) {
    final langs = axes.language == GalleryLanguage.both
        ? [GalleryLanguage.arabic, GalleryLanguage.english]
        : [axes.language];

    final brightnesses = switch (axes.themeMode) {
      GalleryThemeMode.light => [Brightness.light],
      GalleryThemeMode.dark => [Brightness.dark],
      GalleryThemeMode.system => [MediaQuery.platformBrightnessOf(context)],
      GalleryThemeMode.sideBySide => [Brightness.light, Brightness.dark],
    };

    final panes = <Widget>[
      for (final b in brightnesses)
        for (final l in langs) _pane(brightness: b, language: l),
    ];

    if (panes.length == 1) return Expanded(child: panes.first);
    return Expanded(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (var i = 0; i < panes.length; i++) ...[
            if (i > 0) const _PaneDivider(),
            Expanded(child: panes[i]),
          ],
        ],
      ),
    );
  }

  Widget _pane({
    required Brightness brightness,
    required GalleryLanguage language,
  }) {
    final theme = SiyaqThemeData.of(brightness, script: language.script);
    return Theme(
      data: theme,
      child: Builder(
        builder: (themedContext) {
          Widget content = Container(
            color: themedContext.colors.background,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _PaneHeader(brightness: brightness, language: language),
                Expanded(child: Builder(builder: (inner) => builder(inner))),
              ],
            ),
          );

          // Constrain to the selected device width, centred, so small-screen
          // clipping is visible rather than hidden by a wide desktop window.
          final w = axes.viewport.width;
          if (w != null) {
            content = Align(
              alignment: Alignment.topCenter,
              child: SizedBox(width: w, child: content),
            );
          }

          return Localizations.override(
            context: themedContext,
            locale: Locale(language.code),
            child: Directionality(
              textDirection: language.direction,
              child: Builder(
                builder: (c) => MediaQuery(
                  data: MediaQuery.of(
                    c,
                  ).copyWith(textScaler: TextScaler.linear(axes.textScale)),
                  child: content,
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _PaneDivider extends StatelessWidget {
  const _PaneDivider();

  @override
  Widget build(BuildContext context) =>
      SizedBox(width: 1, child: ColoredBox(color: context.colors.borderStrong));
}

class _PaneHeader extends StatelessWidget {
  const _PaneHeader({required this.brightness, required this.language});

  final Brightness brightness;
  final GalleryLanguage language;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final label =
        '${brightness == Brightness.dark ? 'DARK' : 'LIGHT'} · '
        '${language == GalleryLanguage.arabic ? 'AR · RTL' : 'EN · LTR'}';
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(
        horizontal: SiyaqSpacing.md,
        vertical: SiyaqSpacing.sm,
      ),
      color: c.surfaceElevated,
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: context.type.role(
          SiyaqTextRole.labelSmall,
          script: SiyaqScript.mono,
          color: c.textMuted,
        ),
      ),
    );
  }
}
