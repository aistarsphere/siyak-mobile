import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/game/domain/translation/translation_service.dart';
import 'package:context_game/features/game/presentation/widgets/translation_assist.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_harness.dart';

/// Feature QA for the translation assistant: detection, candidates, explicit
/// pick, dismissal, gating.
void main() {
  group('script detection', () {
    test('classifies pure scripts and rejects mixed/none', () {
      expect(detectScript('سيارة'), DetectedScript.arabic);
      expect(detectScript('car'), DetectedScript.latin);
      expect(detectScript('carسيارة'), DetectedScript.mixed);
      expect(detectScript('123 !?'), DetectedScript.none);
      // Arabic punctuation/digits alone are not a word.
      expect(detectScript('٤٢؟'), DetectedScript.none);
    });

    test('triggers only for the other supported script', () {
      // English game, Arabic input → assist.
      expect(isLikelyOtherLanguage('سيارة', GameplayLanguage.english), isTrue);
      // English game, English input → no assist.
      expect(isLikelyOtherLanguage('car', GameplayLanguage.english), isFalse);
      // Arabic game, Latin input → assist.
      expect(isLikelyOtherLanguage('car', GameplayLanguage.arabic), isTrue);
      // Too short, digits, mixed → never.
      expect(isLikelyOtherLanguage('س', GameplayLanguage.english), isFalse);
      expect(isLikelyOtherLanguage('42', GameplayLanguage.arabic), isFalse);
      expect(isLikelyOtherLanguage('carس', GameplayLanguage.arabic), isFalse);
    });
  });

  group('dev adapter', () {
    const dev = DevTranslationAdapter();

    test('serves both directions deterministically', () async {
      final arToEn = await dev.suggest(
        text: 'سيارة',
        from: GameplayLanguage.arabic,
        to: GameplayLanguage.english,
      );
      expect(arToEn.map((c) => c.word), ['car', 'vehicle', 'automobile']);
      expect(arToEn.first.source, 'dev-fixture');

      final enToAr = await dev.suggest(
        text: 'Car',
        from: GameplayLanguage.english,
        to: GameplayLanguage.arabic,
      );
      expect(enToAr.map((c) => c.word), contains('سيارة'));
    });

    test('unknown input yields no candidates, not guesses', () async {
      final none = await dev.suggest(
        text: 'زرافة',
        from: GameplayLanguage.arabic,
        to: GameplayLanguage.english,
      );
      expect(none, isEmpty);
    });
  });

  group('assist panel in gameplay', () {
    testWidgets('typing the other script surfaces candidates', (t) async {
      final controller = TextEditingController();
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          controller: controller,
        ),
      );
      await t.pumpAndSettle();
      // (The header's language chip exists; candidate words do not yet.)
      expect(find.text('car'), findsNothing);

      await t.enterText(find.byType(TextField), 'سيارة');
      await t.pumpAndSettle();

      expect(find.text('car'), findsOneWidget);
      expect(find.text('vehicle'), findsOneWidget);
      expect(find.text('automobile'), findsOneWidget);
      // Original input shown, visibly distinct (quoted).
      expect(find.text('"سيارة"'), findsOneWidget);
    });

    testWidgets('picking a candidate fills the composer, never submits', (
      t,
    ) async {
      final controller = TextEditingController();
      final submitted = <String>[];
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          controller: controller,
          onSubmit: submitted.add,
        ),
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'سيارة');
      await t.pumpAndSettle();
      await t.tap(find.text('car'));
      await t.pumpAndSettle();

      expect(controller.text, 'car');
      expect(submitted, isEmpty, reason: 'a pick must never auto-submit');
      // Panel retires once the input matches the game language.
      expect(find.text('vehicle'), findsNothing);
    });

    testWidgets('same-script input never shows the panel', (t) async {
      final controller = TextEditingController();
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          controller: controller,
        ),
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'library');
      await t.pumpAndSettle();

      expect(find.byType(SiyaqTintedSurface), findsNothing);
    });

    testWidgets('unknown word states no-candidates instead of guessing', (
      t,
    ) async {
      final controller = TextEditingController();
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          controller: controller,
        ),
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'زرافة');
      await t.pumpAndSettle();

      expect(find.text('No suggestions for this word'), findsOneWidget);
    });

    testWidgets('dismiss hides the panel until the input changes', (t) async {
      final controller = TextEditingController();
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          controller: controller,
        ),
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'سيارة');
      await t.pumpAndSettle();
      expect(find.text('car'), findsOneWidget);

      await t.tap(find.byIcon(SiyaqIcons.close));
      await t.pumpAndSettle();
      expect(find.text('car'), findsNothing);

      // A different word re-arms the assist.
      await t.enterText(find.byType(TextField), 'كتاب');
      await t.pumpAndSettle();
      expect(find.text('book'), findsOneWidget);
    });

    testWidgets('disabled service (release gating) renders nothing', (t) async {
      await t.pumpWidget(
        ProviderScope(
          overrides: [translationServiceProvider.overrideWithValue(null)],
          child: MaterialApp(
            theme: SiyaqThemeData.dark(script: SiyaqScript.latin),
            supportedLocales: const [Locale('en')],
            localizationsDelegates: const [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(
              body: TranslationAssist(
                text: 'سيارة',
                gameLanguage: GameplayLanguage.english,
                noCandidatesLabel: 'none',
                onPick: (_) {},
              ),
            ),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqTintedSurface), findsNothing);
      expect(find.byType(SiyaqChip), findsNothing);
    });
  });
}
