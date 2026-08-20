import 'dart:async';

import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/game/domain/translation/translation_suggestion.dart';
import 'package:context_game/features/game/domain/translation/translation_suggestion_repository.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/translation_suggestion_controller.dart';
import 'package:context_game/features/game/presentation/widgets/translation_assist.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Widget behaviour of the Arabic → English panel.
///
/// The controller is injected so each visual state can be produced exactly,
/// rather than by racing a real debounce.
class _ManualRepository implements TranslationSuggestionRepository {
  Completer<List<TranslationSuggestion>>? pending;
  int calls = 0;

  @override
  Future<List<TranslationSuggestion>> suggest({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? locale,
  }) {
    calls++;
    return (pending = Completer<List<TranslationSuggestion>>()).future;
  }
}

Future<Widget> _host(
  TranslationSuggestionController controller, {
  required String text,
  String lang = 'en',
  ValueChanged<String>? onPick,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();
  return ProviderScope(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
    child: MaterialApp(
      locale: Locale(lang),
      supportedLocales: const [Locale('en'), Locale('ar')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      theme: SiyaqThemeData.dark(script: SiyaqScript.latin),
      home: Scaffold(
        body: Directionality(
          textDirection: lang == 'ar' ? TextDirection.rtl : TextDirection.ltr,
          child: TranslationAssist(
            text: text,
            gameLanguage: GameplayLanguage.english,
            controllerOverride: controller,
            onPick: onPick ?? (_) {},
          ),
        ),
      ),
    ),
  );
}

TranslationSuggestionController _controller(
  TranslationSuggestionRepository repo, {
  GameplayLanguage language = GameplayLanguage.english,
}) => TranslationSuggestionController(
  repository: repo,
  gameLanguage: language,
  debounce: const Duration(milliseconds: 1),
);

void main() {
  group('visual states', () {
    testWidgets('loading shows progress without hiding the field', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'كتاب'));
      await t.pump(const Duration(milliseconds: 5));

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Finding translations…'), findsOneWidget);

      // Settle the in-flight request so the timeout timer does not outlive the
      // test — a pending timer fails teardown, and it is the controller doing
      // its job rather than a leak.
      repo.pending!.complete(const []);
      await t.pumpAndSettle();
    });

    testWidgets('success renders one chip per sense, with its Arabic gloss', (
      t,
    ) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'ذهب'));
      await t.pump(const Duration(milliseconds: 5));

      repo.pending!.complete(const [
        TranslationSuggestion(
          text: 'gold',
          sense: 'noun',
          confidence: 0.94,
          label: 'ذهب كمعدن',
        ),
        TranslationSuggestion(text: 'went', sense: 'verb', confidence: 0.82),
        TranslationSuggestion(text: 'go', sense: 'verb', confidence: 0.71),
      ]);
      await t.pumpAndSettle();

      expect(find.text('gold'), findsOneWidget);
      expect(find.text('went'), findsOneWidget);
      expect(find.text('go'), findsOneWidget);
      // The Arabic sense label distinguishes the ambiguous senses.
      expect(find.text('ذهب كمعدن'), findsOneWidget);
      // The source is echoed so the player can see what was detected.
      expect(find.text('"ذهب"'), findsOneWidget);
    });

    testWidgets('empty states plainly rather than looking broken', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'كتاب'));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.complete(const []);
      await t.pumpAndSettle();

      expect(find.text('No suggestions for this word'), findsOneWidget);
    });

    testWidgets('error offers retry and re-asks when tapped', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'كتاب'));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.completeError(StateError('offline'));
      await t.pumpAndSettle();

      expect(find.text("Couldn't load translations"), findsOneWidget);
      expect(repo.calls, 1);

      await t.tap(find.text('Try again'));
      await t.pumpAndSettle();
      expect(repo.calls, 2, reason: 'retry must actually re-request');
    });
  });

  group('layout', () {
    testWidgets('long live sense labels neither overflow nor cover the composer', (
      t,
    ) async {
      // Reproduces a defect only a physical device exposed: the deployed
      // lexicon returns a whole enumeration as `sense_label`, not the short
      // gloss the drafted contract implied. Each chip then spanned the row, the
      // panel grew past the composer, and the frame overflowed by 128px.
      const gloss = 'letter, note, paper, piece of writing, message — اسم';
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'كتاب'));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.complete(const [
        TranslationSuggestion(text: 'book', label: gloss),
        TranslationSuggestion(text: 'letter', label: gloss),
        TranslationSuggestion(text: 'paper', label: gloss),
        TranslationSuggestion(text: 'message', label: gloss),
        TranslationSuggestion(text: 'note', label: gloss),
        TranslationSuggestion(text: 'record', label: gloss),
      ]);
      await t.pumpAndSettle();

      expect(t.takeException(), isNull, reason: 'no RenderFlex overflow');

      // The panel must stay small enough to sit above a composer and keyboard.
      final panel = t.getSize(find.byType(TranslationAssist));
      expect(
        panel.height,
        lessThan(240),
        reason: 'a verbose backend must not grow the panel over the input',
      );
      // Every suggestion is still reachable, by scrolling if need be.
      expect(find.text('book'), findsOneWidget);
      expect(find.text('record'), findsOneWidget);
    });
  });

  group('selection', () {
    testWidgets('tapping a chip fills the composer and never submits', (
      t,
    ) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      final picked = <String>[];
      await t.pumpWidget(await _host(c, text: 'كتاب', onPick: picked.add));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.complete(const [
        TranslationSuggestion(text: 'book'),
        TranslationSuggestion(text: 'volume'),
      ]);
      await t.pumpAndSettle();

      await t.tap(find.text('book'));
      await t.pumpAndSettle();

      // Only the English word leaves the panel — never the Arabic source.
      expect(picked, ['book']);
      expect(picked.single, isNot('كتاب'));
      // And the panel retires.
      expect(find.text('volume'), findsNothing);
    });

    testWidgets('dismissing hides the panel', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'كتاب'));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.complete(const [TranslationSuggestion(text: 'book')]);
      await t.pumpAndSettle();
      expect(find.text('book'), findsOneWidget);

      await t.tap(find.byIcon(SiyaqIcons.close));
      await t.pumpAndSettle();
      expect(find.text('book'), findsNothing);
    });

    testWidgets('a chip announces its word together with its sense', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'ذهب'));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.complete(const [
        TranslationSuggestion(text: 'gold', sense: 'noun', label: 'ذهب كمعدن'),
      ]);
      await t.pumpAndSettle();

      expect(
        find.bySemanticsLabel('gold, noun, ذهب كمعدن'),
        findsOneWidget,
        reason: 'one node, not three fragments',
      );
    });
  });

  group('direction', () {
    testWidgets('English suggestions stay LTR inside an Arabic UI', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'كتاب', lang: 'ar'));
      await t.pump(const Duration(milliseconds: 5));
      repo.pending!.complete(const [TranslationSuggestion(text: 'book')]);
      await t.pumpAndSettle();

      expect(
        Directionality.of(t.element(find.text('book'))),
        TextDirection.ltr,
        reason: 'an English word must not be reordered by an RTL ancestor',
      );
      // The Arabic source echo runs RTL.
      expect(
        Directionality.of(t.element(find.text('"كتاب"'))),
        TextDirection.rtl,
      );
    });
  });

  group('gating', () {
    testWidgets('an Arabic game renders nothing at all', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo, language: GameplayLanguage.arabic);
      await t.pumpWidget(await _host(c, text: 'كتاب'));
      await t.pump(const Duration(milliseconds: 20));

      expect(repo.calls, 0);
      expect(find.byType(SiyaqTintedSurface), findsNothing);
    });

    testWidgets('English input in an English game renders nothing', (t) async {
      final repo = _ManualRepository();
      final c = _controller(repo);
      await t.pumpWidget(await _host(c, text: 'book'));
      await t.pump(const Duration(milliseconds: 20));

      expect(repo.calls, 0);
      expect(find.byType(SiyaqTintedSurface), findsNothing);
    });
  });
}
