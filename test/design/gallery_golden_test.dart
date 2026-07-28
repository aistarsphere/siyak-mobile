@Tags(['golden'])
library;

import 'dart:io';

import 'package:context_game/core/design/gallery/design_system_gallery.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Golden coverage for the design-system gallery.
///
/// Runs the token layer through the axes that matter most and snapshots them, so
/// a future change to a colour, type role or spacing step shows up as an image
/// diff rather than being noticed by eye. This is the dual-theme regression guard
/// the audit asked for (§19) and it only became possible once colour resolution
/// moved into the widget tree.
///
/// Regenerate after an intentional token change:
/// ```sh
/// flutter test --update-goldens test/design/gallery_golden_test.dart
/// ```
Future<void> _loadBundledFonts() async {
  // Golden runs use the Ahem placeholder font unless the real families are
  // registered, which would make every snapshot unreadable boxes.
  const families = <String, List<String>>{
    'IBMPlexSansArabic': [
      'assets/fonts/siyag/IBMPlexSansArabic-Regular.ttf',
      'assets/fonts/siyag/IBMPlexSansArabic-Medium.ttf',
      'assets/fonts/siyag/IBMPlexSansArabic-SemiBold.ttf',
      'assets/fonts/siyag/IBMPlexSansArabic-Bold.ttf',
    ],
    'Inter': ['assets/fonts/siyag/Inter.ttf'],
    'NotoNaskhArabic': [
      'assets/fonts/siyag/NotoNaskhArabic-400.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-700.ttf',
    ],
    'DMMono': [
      'assets/fonts/siyag/DMMono-400.ttf',
      'assets/fonts/siyag/DMMono-500.ttf',
    ],
  };
  for (final entry in families.entries) {
    final loader = FontLoader(entry.key);
    for (final path in entry.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }

  // Icons are glyphs too: without MaterialIcons every Icon renders as an empty
  // box, which would make the snapshots misleading about icon coverage.
  final flutterRoot =
      Platform.environment['FLUTTER_ROOT'] ??
      _dirname(_dirname(File(Platform.resolvedExecutable).path));
  final icons = File(
    '$flutterRoot/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

String _dirname(String path) {
  final i = path.lastIndexOf(Platform.pathSeparator);
  return i <= 0 ? path : path.substring(0, i);
}

Widget _host() => MaterialApp(
  debugShowCheckedModeBanner: false,
  locale: const Locale('ar'),
  supportedLocales: const [Locale('ar'), Locale('en')],
  localizationsDelegates: const [
    GlobalMaterialLocalizations.delegate,
    GlobalWidgetsLocalizations.delegate,
    GlobalCupertinoLocalizations.delegate,
  ],
  home: const DesignSystemGallery(),
);

Future<void> _frames(WidgetTester t) async {
  for (var i = 0; i < 3; i++) {
    await t.pump(const Duration(milliseconds: 32));
  }
}

Future<void> _select(WidgetTester t, String label) async {
  await t.tap(find.text(label).first, warnIfMissed: false);
  await _frames(t);
}

void main() {
  setUpAll(_loadBundledFonts);

  Future<void> shoot(
    WidgetTester t,
    String name,
    Size size,
    List<String> taps,
  ) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_host());
    await _frames(t);
    for (final tap in taps) {
      await _select(t, tap);
    }
    await expectLater(
      find.byType(DesignSystemGallery),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('colour tokens · Light + Dark side by side', (t) async {
    await shoot(t, 'tokens_colour_light_dark', const Size(1500, 1500), []);
  });

  testWidgets('typography · Arabic RTL + English LTR', (t) async {
    await shoot(t, 'tokens_type_ar_en', const Size(1500, 1600), [
      'Type',
      'Dark',
      'AR + EN',
    ]);
  });

  testWidgets('layout tokens · spacing, radius, elevation, motion, icons', (
    t,
  ) async {
    await shoot(t, 'tokens_layout', const Size(1400, 1700), [
      'Layout',
      'Dark',
      'English',
    ]);
  });

  testWidgets('state foundation · Light + Dark', (t) async {
    await shoot(t, 'tokens_states_light_dark', const Size(1500, 1300), [
      'States',
    ]);
  });

  testWidgets('buttons · 4 types x states · Light + Dark', (t) async {
    await shoot(t, 'components_buttons_light_dark', const Size(2000, 1700), [
      'Buttons',
    ]);
  });

  testWidgets('buttons · Arabic RTL + English LTR', (t) async {
    await shoot(t, 'components_buttons_ar_en', const Size(2000, 1700), [
      'Buttons',
      'Dark',
      'AR + EN',
    ]);
  });

  testWidgets('components · icon buttons, surfaces, dividers', (t) async {
    await shoot(t, 'components_surfaces_light_dark', const Size(1600, 2100), [
      'Components',
    ]);
  });

  testWidgets('buttons · worst case 320px at text scale 2.0', (t) async {
    await shoot(t, 'components_buttons_320_scale2', const Size(1200, 1800), [
      'Buttons',
      'Dark',
      '2.0',
      '320',
    ]);
  });

  testWidgets('shared components · Light + Dark', (t) async {
    await shoot(t, 'shared_light_dark', const Size(1700, 7200), ['Shared']);
  });

  testWidgets('shared components · Arabic RTL + English LTR', (t) async {
    await shoot(t, 'shared_ar_en', const Size(1700, 7200), [
      'Shared',
      'Dark',
      'AR + EN',
    ]);
  });

  testWidgets('shared components · 320px at text scale 2.0', (t) async {
    await shoot(t, 'shared_320_scale2', const Size(1200, 7200), [
      'Shared',
      'Dark',
      '2.0',
      '320',
    ]);
  });

  testWidgets('worst case · 320px viewport at text scale 2.0', (t) async {
    await shoot(t, 'tokens_states_320_scale2', const Size(1200, 1500), [
      'States',
      'Dark',
      '2.0',
      '320',
    ]);
  });
}
