import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../theme/context_tokens.dart';
import '../theme/siyaq_theme_data.dart';
import '../tokens/siyaq_spacing.dart';
import '../tokens/siyaq_typography.dart';
import 'gallery_controls.dart';
import 'gallery_stage.dart';
import 'pages/component_pages.dart';
import 'pages/room_pages.dart';
import 'pages/shared_pages.dart';
import 'pages/token_pages.dart';

/// **Debug-only** design-system gallery.
///
/// The validation harness for the migration: it renders the token layer across
/// every axis the audit requires (§19) — Light/Dark/System, Arabic RTL and
/// English LTR, text scales up to 2.0, device widths down to 320px, and the
/// interaction/feedback states components will inherit.
///
/// Its defining capability is **Light + Dark (and AR + EN) simultaneously**,
/// which the old mutable global palette made impossible. That is the guard
/// against theme regressions for the rest of the migration.
///
/// Not reachable from production UI. Open it explicitly:
///
/// ```dart
/// Navigator.of(context).push(DesignSystemGallery.route());
/// ```
class DesignSystemGallery extends StatefulWidget {
  const DesignSystemGallery({super.key});

  static Route<void> route() => MaterialPageRoute(
    builder: (_) => const DesignSystemGallery(),
    settings: const RouteSettings(name: '/_design_system_gallery'),
  );

  @override
  State<DesignSystemGallery> createState() => _DesignSystemGalleryState();
}

class _DesignSystemGalleryState extends State<DesignSystemGallery> {
  GalleryAxes _axes = const GalleryAxes();
  int _tab = 0;

  static const _tabs = <String>[
    'Colour',
    'Type',
    'Layout',
    'States',
    'Buttons',
    'Components',
    'Shared',
    'Room',
  ];

  @override
  Widget build(BuildContext context) {
    // The chrome is deliberately fixed-dark so it never competes with the panes
    // being evaluated; only the stage reflects the selected axes.
    return Theme(
      data: SiyaqThemeData.dark(script: SiyaqScript.latin),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Builder(
          builder: (chrome) => Scaffold(
            backgroundColor: chrome.colors.background,
            body: SafeArea(
              child: Column(
                children: [
                  _Toolbar(
                    axes: _axes,
                    tab: _tab,
                    tabs: _tabs,
                    onAxes: (a) => setState(() => _axes = a),
                    onTab: (i) => setState(() => _tab = i),
                  ),
                  GalleryStage(axes: _axes, builder: (_) => _page()),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _page() => switch (_tab) {
    0 => const ColorTokensPage(),
    1 => const TypographyPage(),
    2 => const LayoutTokensPage(),
    3 => const StateFoundationPage(),
    4 => const ButtonGalleryPage(),
    5 => const ComponentGalleryPage(),
    6 => const SharedComponentsPage(),
    _ => const RoomComponentsPage(),
  };
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.axes,
    required this.tab,
    required this.tabs,
    required this.onAxes,
    required this.onTab,
  });

  final GalleryAxes axes;
  final int tab;
  final List<String> tabs;
  final ValueChanged<GalleryAxes> onAxes;
  final ValueChanged<int> onTab;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(SiyaqSpacing.md),
      decoration: BoxDecoration(
        color: c.surface,
        border: Border(bottom: BorderSide(color: c.border)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconButton(
                icon: const Icon(Icons.arrow_back_rounded),
                onPressed: () => Navigator.of(context).maybePop(),
                tooltip: 'Back',
              ),
              Text(
                'Siyaq Design System',
                style: context.type.role(SiyaqTextRole.headingSmall),
              ),
              const SizedBox(width: SiyaqSpacing.sm),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: SiyaqSpacing.sm,
                  vertical: 2,
                ),
                decoration: BoxDecoration(
                  color: c.primaryContainer,
                  borderRadius: BorderRadius.circular(SiyaqRadius.full),
                ),
                child: Text(
                  'DEBUG',
                  style: context.type.numeric(
                    SiyaqTextRole.labelSmall,
                    color: c.primary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: SiyaqSpacing.sm),
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                _Group(
                  label: 'Page',
                  child: _Segmented(labels: tabs, index: tab, onTap: onTab),
                ),
                _Group(
                  label: 'Theme',
                  child: _Segmented(
                    labels: GalleryThemeMode.values
                        .map((e) => e.label)
                        .toList(),
                    index: axes.themeMode.index,
                    onTap: (i) => onAxes(
                      axes.copyWith(themeMode: GalleryThemeMode.values[i]),
                    ),
                  ),
                ),
                _Group(
                  label: 'Language',
                  child: _Segmented(
                    labels: GalleryLanguage.values.map((e) => e.label).toList(),
                    index: axes.language.index,
                    onTap: (i) => onAxes(
                      axes.copyWith(language: GalleryLanguage.values[i]),
                    ),
                  ),
                ),
                _Group(
                  label: 'Text scale',
                  child: _Segmented(
                    labels: kGalleryTextScales.map((e) => e.$1).toList(),
                    index: kGalleryTextScales.indexWhere(
                      (e) => e.$2 == axes.textScale,
                    ),
                    onTap: (i) => onAxes(
                      axes.copyWith(textScale: kGalleryTextScales[i].$2),
                    ),
                  ),
                ),
                _Group(
                  label: 'Viewport',
                  child: _Segmented(
                    labels: GalleryViewport.values.map((e) => e.label).toList(),
                    index: axes.viewport.index,
                    onTap: (i) => onAxes(
                      axes.copyWith(viewport: GalleryViewport.values[i]),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Group extends StatelessWidget {
  const _Group({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsetsDirectional.only(end: SiyaqSpacing.xl),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label.toUpperCase(),
          style: context.type.numeric(
            SiyaqTextRole.labelSmall,
            color: context.colors.textMuted,
            letterSpacing: 1.2,
          ),
        ),
        const SizedBox(height: SiyaqSpacing.xxs),
        child,
      ],
    ),
  );
}

class _Segmented extends StatelessWidget {
  const _Segmented({
    required this.labels,
    required this.index,
    required this.onTap,
  });

  final List<String> labels;
  final int index;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Container(
      padding: const EdgeInsets.all(2),
      decoration: BoxDecoration(
        color: c.surfaceElevated,
        borderRadius: BorderRadius.circular(SiyaqRadius.md),
        border: Border.all(color: c.border),
      ),
      child: Row(
        children: [
          for (var i = 0; i < labels.length; i++)
            GestureDetector(
              onTap: () => onTap(i),
              child: Container(
                margin: const EdgeInsets.symmetric(horizontal: 1),
                padding: const EdgeInsets.symmetric(
                  horizontal: SiyaqSpacing.smd,
                  vertical: SiyaqSpacing.xs,
                ),
                decoration: BoxDecoration(
                  color: i == index ? c.primary : Colors.transparent,
                  borderRadius: BorderRadius.circular(SiyaqRadius.sm),
                ),
                child: Text(
                  labels[i],
                  style: context.type.role(
                    SiyaqTextRole.labelMedium,
                    // The chrome is Latin, but one control is labelled
                    // "العربية" — pick the Arabic family for it so the glyphs
                    // resolve instead of rendering as tofu boxes.
                    script: _hasArabic(labels[i])
                        ? SiyaqScript.arabic
                        : SiyaqScript.latin,
                    color: i == index ? c.onAction : c.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// Any Arabic-script codepoint in the main Arabic block.
bool _hasArabic(String s) => s.codeUnits.any((c) => c >= 0x0600 && c <= 0x06FF);

/// Debug-only entry point, safe to call from anywhere.
///
/// Compiles to a no-op in release builds so the gallery cannot be reached in
/// production and is tree-shaken out.
void openDesignSystemGallery(BuildContext context) {
  if (!kDebugMode) return;
  Navigator.of(context).push(DesignSystemGallery.route());
}
