@Tags(['golden'])
library;

import 'dart:io';

import 'package:context_game/features/v2/domain/entities/weekly.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/weekly_harness.dart';

/// Golden coverage for the Weekly Challenge screen across theme × language ×
/// state.
///
/// Regenerate after an intentional visual change:
/// ```sh
/// flutter test --update-goldens test/design/weekly_golden_test.dart
/// ```
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'NotoNaskhArabic': [
      'assets/fonts/siyag/NotoNaskhArabic-400.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-500.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-600.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-700.ttf',
    ],
    'PlusJakartaSans': [
      'assets/fonts/siyag/PlusJakartaSans-400.ttf',
      'assets/fonts/siyag/PlusJakartaSans-500.ttf',
      'assets/fonts/siyag/PlusJakartaSans-600.ttf',
      'assets/fonts/siyag/PlusJakartaSans-700.ttf',
    ],
    'DMMono': [
      'assets/fonts/siyag/DMMono-400.ttf',
      'assets/fonts/siyag/DMMono-500.ttf',
    ],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      '/Users/devalqaasem/development/flutter';
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(
    WidgetTester t,
    String name, {
    required Brightness brightness,
    String lang = 'ar',
    WeeklyState state = WeeklyState.active,
    bool participated = false,
    Object? error,
    bool loading = false,
    double textScale = 1.0,
    Size size = const Size(390, 1000),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      await buildWeekly(
        brightness: brightness,
        lang: lang,
        state: state,
        participated: participated,
        error: error,
        loading: loading,
        textScale: textScale,
      ),
    );
    if (loading) {
      await t.pump();
      await t.pump(const Duration(milliseconds: 32));
    } else {
      await t.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('active · dark · Arabic', (t) async {
    await shoot(t, 'weekly_dark_ar', brightness: Brightness.dark);
  });

  testWidgets('active · light · English', (t) async {
    await shoot(t, 'weekly_light_en', brightness: Brightness.light, lang: 'en');
  });

  testWidgets('completed · dark · English', (t) async {
    await shoot(
      t,
      'weekly_completed_dark_en',
      brightness: Brightness.dark,
      lang: 'en',
      state: WeeklyState.completed,
      participated: true,
      size: const Size(390, 1100),
    );
  });

  testWidgets('loading · dark · Arabic', (t) async {
    await shoot(
      t,
      'weekly_loading_dark_ar',
      brightness: Brightness.dark,
      loading: true,
      size: const Size(390, 600),
    );
  });

  testWidgets('error · light · English', (t) async {
    await shoot(
      t,
      'weekly_error_light_en',
      brightness: Brightness.light,
      lang: 'en',
      error: Exception('network'),
      size: const Size(390, 600),
    );
  });

  testWidgets('320px at text scale 1.6 · Arabic', (t) async {
    await shoot(
      t,
      'weekly_320_scale16_ar',
      brightness: Brightness.dark,
      textScale: 1.6,
      size: const Size(320, 1900),
    );
  });
}
