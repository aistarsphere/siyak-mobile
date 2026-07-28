@Tags(['golden'])
library;

import 'dart:io';

import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_harness.dart';

/// Golden coverage for core gameplay across theme × UI language × game language
/// × state.
///
/// Regenerate after an intentional visual change:
/// ```sh
/// flutter test --update-goldens test/design/gameplay_golden_test.dart
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

final _arabicGame = [
  guess('كتاب', 25, heat: 0.88),
  guess('قلم', 340, heat: 0.62),
  guess('ورقة', 900, heat: 0.44),
  guess('طاولة', 4200, heat: 0.22),
  guess('سيارة', 18400, heat: 0.06),
];

final _englishGame = [
  guess('library', 25, heat: 0.88),
  guess('shelf', 340, heat: 0.62),
  guess('paper', 900, heat: 0.44),
  guess('car', 18400, heat: 0.06),
];

void main() {
  setUpAll(_loadFonts);

  void sized(WidgetTester t, Size size) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  Future<void> shoot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  // The exact fixture from the beta device session that exposed the ordering
  // bug: played sun → moon → star, and the pinned row showed "moon". Kept as a
  // visual record of the corrected frame — Latest resolves from lastWord, the
  // rank carries the gameplay numeral role, and the tag is demoted.
  testWidgets('beta feel pass · rank-ordered response · English', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        uiLang: 'en',
        gameLanguage: GameplayLanguage.english,
        title: 'GENERAL',
        guesses: [
          guess('star', 11774, heat: 0.30),
          guess('sun', 17331, heat: 0.20),
          guess('moon', 20462, heat: 0.10),
        ],
        lastWord: 'sun',
        hints: const [SiyaqHintData(word: 'عساف', rank: 35)],
        hintsRemaining: 4,
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_feel_fixed_en');
  });

  testWidgets('Arabic game · Arabic UI · dark', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        guesses: _arabicGame,
        lastWord: 'سيارة',
        hints: const [SiyaqHintData(word: 'مكتبة', rank: 42)],
        hintsRemaining: 2,
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_ar_dark');
  });

  testWidgets('English game · English UI · light', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        brightness: Brightness.light,
        uiLang: 'en',
        gameLanguage: GameplayLanguage.english,
        title: 'General',
        guesses: _englishGame,
        lastWord: 'car',
        hintsRemaining: 3,
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_en_light');
  });

  testWidgets('English game inside an Arabic app · dark', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        uiLang: 'ar',
        gameLanguage: GameplayLanguage.english,
        guesses: _englishGame,
        lastWord: 'car',
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_crossed_lang_dark');
  });

  testWidgets('empty game · dark · Arabic', (t) async {
    sized(t, const Size(390, 900));
    await t.pumpWidget(buildGameplay());
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_empty_ar');
  });

  testWidgets('hints expanded · dark · English', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        uiLang: 'en',
        gameLanguage: GameplayLanguage.english,
        guesses: _englishGame,
        hints: const [
          SiyaqHintData(word: 'bookcase', rank: 42),
          SiyaqHintData(word: 'reading', rank: 118),
        ],
        hintsRemaining: 1,
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.bySemanticsLabel('Show hints'));
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_hints_open_en');
  });

  testWidgets('rejected word with suggestions · light · English', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        brightness: Brightness.light,
        uiLang: 'en',
        gameLanguage: GameplayLanguage.english,
        guesses: _englishGame,
        inputError: 'This word is not in the dictionary',
        suggestions: const ['bookshelf', 'booklet'],
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_rejected_en_light');
  });

  testWidgets('solved · dark · Arabic', (t) async {
    sized(t, const Size(390, 1000));
    await t.pumpWidget(
      buildGameplay(
        solved: true,
        guesses: [..._arabicGame, guess('مكتبة', 1, heat: 1.0, solved: true)],
        lastWord: 'مكتبة',
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_solved_ar');
  });

  testWidgets('320px at text scale 1.6 · Arabic', (t) async {
    sized(t, const Size(320, 1500));
    await t.pumpWidget(buildGameplay(guesses: _arabicGame, textScale: 1.6));
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_320_scale16_ar');
  });

  testWidgets('320px at text scale 2.0 · English', (t) async {
    sized(t, const Size(320, 1800));
    await t.pumpWidget(
      buildGameplay(
        uiLang: 'en',
        gameLanguage: GameplayLanguage.english,
        guesses: _englishGame,
        textScale: 2.0,
      ),
    );
    await t.pumpAndSettle();
    await shoot(t, 'gameplay_320_scale2_en');
  });
}
