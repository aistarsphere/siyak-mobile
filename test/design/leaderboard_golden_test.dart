@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/leaderboard_harness.dart';

/// Golden coverage for the Leaderboard screen across theme × language × state.
///
/// Regenerate after an intentional visual change:
/// ```sh
/// flutter test --update-goldens test/design/leaderboard_golden_test.dart
/// ```
Future<void> _loadFonts() async {
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
    List<dynamic> entries = const [],
    bool loading = false,
    int? currentPlacement,
    Object? error,
    double textScale = 1.0,
    Size size = const Size(390, 1100),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      await buildLeaderboard(
        brightness: brightness,
        lang: lang,
        entries: entries.cast(),
        loading: loading,
        currentPlacement: currentPlacement,
        error: error,
        textScale: textScale,
      ),
    );
    await t.pump();
    // Let the podium risers finish animating so the shot is stable.
    await t.pump(const Duration(milliseconds: 900));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('populated · dark · Arabic', (t) async {
    await shoot(
      t,
      'leaderboard_dark_ar',
      brightness: Brightness.dark,
      entries: kLeaderboardEntries,
    );
  });

  testWidgets('populated · light · English', (t) async {
    await shoot(
      t,
      'leaderboard_light_en',
      brightness: Brightness.light,
      lang: 'en',
      entries: kLeaderboardEntries,
    );
  });

  testWidgets('first load spinner · dark · Arabic', (t) async {
    await shoot(
      t,
      'leaderboard_loading_dark_ar',
      brightness: Brightness.dark,
      loading: true,
      size: const Size(390, 600),
    );
  });

  testWidgets('empty · dark · Arabic', (t) async {
    await shoot(
      t,
      'leaderboard_empty_dark_ar',
      brightness: Brightness.dark,
      size: const Size(390, 600),
    );
  });

  testWidgets('error · light · English', (t) async {
    await shoot(
      t,
      'leaderboard_error_light_en',
      brightness: Brightness.light,
      lang: 'en',
      error: Exception('network'),
      size: const Size(390, 600),
    );
  });

  testWidgets('320px at text scale 1.6 · Arabic', (t) async {
    await shoot(
      t,
      'leaderboard_320_scale16_ar',
      brightness: Brightness.dark,
      entries: kLeaderboardEntries,
      textScale: 1.6,
      size: const Size(320, 1700),
    );
  });
}
