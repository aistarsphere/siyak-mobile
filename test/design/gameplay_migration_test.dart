import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/core/localization/app_localizations.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_harness.dart';

/// Non-null when the frame recorded a layout overflow.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

/// A middling set: best is not the newest, so Closest and Latest differ.
final _guesses = [
  guess('كتاب', 25, heat: 0.88), // best
  guess('قلم', 900, heat: 0.40),
  guess('سيارة', 4200, heat: 0.20), // latest
];

void main() {
  group('language support', () {
    testWidgets('gameplay content follows the game language, not the UI', (
      t,
    ) async {
      // Arabic app, English game — the crossing case.
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'ar',
          gameLanguage: GameplayLanguage.english,
          guesses: [guess('library', 25, heat: 0.88)],
        ),
      );
      await t.pumpAndSettle();

      // Chrome is RTL…
      expect(
        Directionality.of(t.element(find.byType(SiyaqScreenHeader))),
        TextDirection.rtl,
      );
      // …while the composer types LTR.
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.ltr);
    });

    testWidgets('an Arabic game inside an English app types RTL', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.arabic,
          guesses: [guess('كتاب', 25, heat: 0.88)],
        ),
      );
      await t.pumpAndSettle();

      expect(
        Directionality.of(t.element(find.byType(SiyaqScreenHeader))),
        TextDirection.ltr,
      );
      final field = t.widget<TextField>(find.byType(TextField));
      expect(field.textDirection, TextDirection.rtl);
    });

    testWidgets('the header states which vocabulary is being played', (
      t,
    ) async {
      await t.pumpWidget(
        buildGameplay(uiLang: 'en', gameLanguage: GameplayLanguage.arabic),
      );
      await t.pumpAndSettle();
      expect(find.text('Arabic'), findsOneWidget);

      await t.pumpWidget(
        buildGameplay(uiLang: 'en', gameLanguage: GameplayLanguage.english),
      );
      await t.pumpAndSettle();
      expect(find.text('English'), findsOneWidget);
    });

    testWidgets('closeness bands are localized, not hardcoded Arabic', (
      t,
    ) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          guesses: [guess('book', 3, heat: 0.92)],
        ),
      );
      await t.pumpAndSettle();
      // Bands are carried by icon visually and by the localized label in the
      // announcement — never by a hardcoded Arabic string.
      final handle = t.ensureSemantics();
      try {
        expect(find.bySemanticsLabel(RegExp(r'Blazing')), findsWidgets);
        expect(find.bySemanticsLabel(RegExp('ملتهب')), findsNothing);

        await t.pumpWidget(
          buildGameplay(uiLang: 'ar', guesses: [guess('كتاب', 3, heat: 0.92)]),
        );
        await t.pumpAndSettle();
        expect(find.bySemanticsLabel(RegExp('ملتهب')), findsWidgets);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('every band resolves to a real string in both languages', (
      t,
    ) async {
      for (final lang in ['ar', 'en']) {
        final loc = AppLocalizations(lang);
        for (final b in SiyaqHeatBand.values) {
          // AppLocalizations echoes the key when it is missing.
          expect(loc(b.labelKey), isNot(b.labelKey), reason: '$lang ${b.name}');
        }
        for (final key in const [
          'progFirst',
          'progBlazing',
          'progCloser',
          'progWarmer',
          'progKeepTrying',
        ]) {
          expect(loc(key), isNot(key), reason: '$lang $key');
        }
      }
    });
  });

  group('best and latest', () {
    testWidgets('both render, and they are different guesses', (t) async {
      await t.pumpWidget(
        buildGameplay(uiLang: 'en', guesses: _guesses, lastWord: 'سيارة'),
      );
      await t.pumpAndSettle();

      final highlights = find.byType(SiyaqGuessHighlight);
      expect(highlights, findsNWidgets(2));
      // Pinned between the timeline and the composer.
      expect(
        t.getCenter(highlights.at(0)).dy,
        greaterThan(t.getCenter(find.byType(SiyaqGuessRow).at(0)).dy),
      );
      expect(
        t.getCenter(highlights.at(1)).dy,
        lessThan(t.getCenter(find.byType(SiyaqGuessComposer)).dy),
      );
      expect(
        t.widget<SiyaqGuessHighlight>(highlights.at(0)).guess.word,
        'كتاب', // best by heat, not the newest
      );
      expect(
        t.widget<SiyaqGuessHighlight>(highlights.at(1)).guess.word,
        'سيارة',
      );
    });

    testWidgets('a worse new guess does not move Closest', (t) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: _guesses));
      await t.pumpAndSettle();
      final before = t
          .widget<SiyaqGuessHighlight>(find.byType(SiyaqGuessHighlight).first)
          .guess
          .word;

      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [..._guesses, guess('طاولة', 9000, heat: 0.05)],
        ),
      );
      await t.pumpAndSettle();

      expect(
        t
            .widget<SiyaqGuessHighlight>(find.byType(SiyaqGuessHighlight).first)
            .guess
            .word,
        before,
      );
      // …but Latest did move.
      expect(
        t
            .widget<SiyaqGuessHighlight>(find.byType(SiyaqGuessHighlight).at(1))
            .guess
            .word,
        'طاولة',
      );
    });

    testWidgets('pinned rows stay one compact line (40–48dp)', (t) async {
      await t.pumpWidget(
        buildGameplay(uiLang: 'en', guesses: _guesses, lastWord: 'سيارة'),
      );
      await t.pumpAndSettle();

      for (final hl in find.byType(SiyaqGuessHighlight).evaluate()) {
        final h = hl.size!.height;
        expect(h, greaterThanOrEqualTo(40));
        expect(
          h,
          lessThanOrEqualTo(48),
          reason:
              'Best/Latest are glanced-at rows, not cards — '
              'a second line here costs a history row',
        );
      }
    });

    testWidgets('Latest collapses when it is already the best', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [
            guess('قلم', 900, heat: 0.40),
            guess('كتاب', 25, heat: 0.88),
          ],
        ),
      );
      await t.pumpAndSettle();
      // Showing the same word twice teaches nothing, so only Closest renders.
      expect(find.byType(SiyaqGuessHighlight), findsOneWidget);
    });

    testWidgets('the solved guess reads as the answer', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [guess('كتاب', 1, heat: 1.0, solved: true)],
          solved: true,
        ),
      );
      await t.pumpAndSettle();
      final handle = t.ensureSemantics();
      try {
        expect(find.bySemanticsLabel(RegExp(r'Answer')), findsWidgets);
      } finally {
        handle.dispose();
      }
    });
  });

  group('history', () {
    testWidgets('is bottom-anchored: newest nearest the composer', (t) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: _guesses));
      await t.pumpAndSettle();

      final rows = find.byType(SiyaqGuessRow);
      expect(rows, findsNWidgets(3));
      // A reversed viewport builds index 0 first, and index 0 is the bottom
      // slot — so tree order is newest → oldest.
      expect(t.widget<SiyaqGuessRow>(rows.at(0)).guess.word, 'سيارة'); // newest
      expect(t.widget<SiyaqGuessRow>(rows.at(2)).guess.word, 'كتاب'); // oldest

      // …and geometrically the newest really is the lowest on screen.
      expect(
        t.getCenter(rows.at(0)).dy,
        greaterThan(t.getCenter(rows.at(2)).dy),
      );
    });

    testWidgets('it really is a reversed viewport, not a sorted list', (
      t,
    ) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: _guesses));
      await t.pumpAndSettle();
      expect(
        t.widget<ListView>(find.byType(ListView)).reverse,
        isTrue,
        reason:
            'faking bottom-anchoring by sorting scrolls the player away '
            'from their own last guess on every submit',
      );
    });

    testWidgets('the ordering toggle is gone', (t) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: _guesses));
      await t.pumpAndSettle();

      expect(find.byType(SiyaqSegmentedControl<dynamic>), findsNothing);
      // "Closest"/"Latest" survive only as the pinned rows' state labels.
      expect(find.text('Closest'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
    });

    testWidgets('a new guess takes the bottom slot and pushes older ones up', (
      t,
    ) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: _guesses));
      await t.pumpAndSettle();
      final oldestBefore = t.getCenter(
        find.ancestor(
          of: find.text('كتاب'),
          matching: find.byType(SiyaqGuessRow),
        ),
      );

      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [..._guesses, guess('طاولة', 9000, heat: 0.05)],
        ),
      );
      await t.pumpAndSettle();

      // The newcomer owns the slot nearest the composer…
      expect(
        t.widget<SiyaqGuessRow>(find.byType(SiyaqGuessRow).at(0)).guess.word,
        'طاولة',
      );
      // …and the existing rows moved *up*, which is the specified behaviour.
      expect(
        t
            .getCenter(
              find.ancestor(
                of: find.text('كتاب'),
                matching: find.byType(SiyaqGuessRow),
              ),
            )
            .dy,
        lessThan(oldestBefore.dy),
      );
    });

    testWidgets('submitting while scrolled up does not jump the viewport', (
      t,
    ) async {
      final many = [
        for (var i = 0; i < 30; i++)
          guess('word$i', (i + 1) * 100, heat: 1 - i / 31),
      ];
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: many));
      await t.pumpAndSettle();

      final scrollable = find.descendant(
        of: find.byType(ListView),
        matching: find.byType(Scrollable),
      );
      await t.drag(find.byType(ListView), const Offset(0, 220));
      await t.pumpAndSettle();
      final parked = t.state<ScrollableState>(scrollable).position.pixels;
      expect(parked, greaterThan(0), reason: 'should be scrolled into history');

      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [...many, guess('brandnew', 9999, heat: 0.02)],
        ),
      );
      await t.pumpAndSettle();

      // Offset is measured from the bottom in a reversed viewport, so inserting
      // at index 0 leaves the reader exactly where they were.
      expect(t.state<ScrollableState>(scrollable).position.pixels, parked);
    });

    testWidgets('rows carry no ordinal numbering, only rank', (t) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: _guesses));
      await t.pumpAndSettle();

      // Rank in the history row and in the Closest highlight — the same
      // convention in both, and nowhere an attempt ordinal.
      expect(find.text('#25'), findsNWidgets(2));
      expect(find.textContaining('Hint #'), findsNothing);
      expect(find.textContaining('Guess #'), findsNothing);
    });

    testWidgets('the empty game explains the rules instead of a blank list', (
      t,
    ) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en'));
      await t.pumpAndSettle();

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Start with any word'), findsOneWidget);
      expect(find.byType(SiyaqGuessRow), findsNothing);
      expect(find.byType(SiyaqGuessHighlight), findsNothing);
    });

    testWidgets('a row announces word, rank and closeness as one node', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          buildGameplay(uiLang: 'en', guesses: [guess('book', 25, heat: 0.88)]),
        );
        await t.pumpAndSettle();
        expect(
          find.bySemanticsLabel(RegExp(r'book, Rank 25, Blazing')),
          findsAtLeastNWidgets(1),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  group('hints', () {
    testWidgets('collapsed by default and hides the revealed words', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          hints: const [SiyaqHintData(word: 'مكتبة', rank: 42)],
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Hints'), findsOneWidget);
      expect(find.text('3 left'), findsOneWidget);
      expect(find.text('مكتبة'), findsNothing);
      expect(find.text('Reveal a hint'), findsNothing);
    });

    testWidgets('expanding reveals the hints and the request action', (
      t,
    ) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          hints: const [SiyaqHintData(word: 'مكتبة', rank: 42)],
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.bySemanticsLabel('Show hints'));
      await t.pumpAndSettle();

      expect(find.text('مكتبة'), findsOneWidget);
      expect(find.text('#42'), findsOneWidget);
      expect(find.text('Reveal a hint'), findsOneWidget);
      expect(find.bySemanticsLabel('Hide hints'), findsOneWidget);
    });

    testWidgets('exhausted hints disable the request but keep the list', (
      t,
    ) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          hintsRemaining: 0,
          hints: const [SiyaqHintData(word: 'مكتبة', rank: 42)],
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Show hints'));
      await t.pumpAndSettle();

      expect(find.text('No hints left'), findsOneWidget);
      expect(
        t
            .widget<SiyaqButton>(
              find.widgetWithText(SiyaqButton, 'Reveal a hint'),
            )
            .onPressed,
        isNull,
      );
    });

    testWidgets('no hints revealed yet is stated, not blank', (t) async {
      await t.pumpWidget(buildGameplay(uiLang: 'en'));
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Show hints'));
      await t.pumpAndSettle();

      expect(find.text('No hints revealed yet'), findsOneWidget);
    });

    testWidgets('requesting a hint calls back', (t) async {
      var asked = 0;
      await t.pumpWidget(
        buildGameplay(uiLang: 'en', onRequestHint: () => asked++),
      );
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Show hints'));
      await t.pumpAndSettle();
      await t.tap(find.text('Reveal a hint'));
      await t.pumpAndSettle();

      expect(asked, 1);
    });
  });

  group('composer', () {
    testWidgets('submit is inert until a word is typed', (t) async {
      final controller = TextEditingController();
      var submitted = <String>[];
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          controller: controller,
          onSubmit: submitted.add,
        ),
      );
      await t.pumpAndSettle();

      await t.tap(find.bySemanticsLabel('Submit guess'));
      await t.pumpAndSettle();
      expect(submitted, isEmpty);

      await t.enterText(find.byType(TextField), '  book  ');
      await t.pumpAndSettle();
      await t.tap(find.bySemanticsLabel('Submit guess'));
      await t.pumpAndSettle();

      expect(submitted, ['book']); // trimmed
    });

    testWidgets('a guess in flight blocks a second submit', (t) async {
      final controller = TextEditingController(text: 'book');
      var submitted = 0;
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          controller: controller,
          submitting: true,
          onSubmit: (_) => submitted++,
        ),
      );
      await t.pump();

      await t.tap(find.bySemanticsLabel('Submit guess'));
      await t.pump();
      expect(submitted, 0);
    });

    testWidgets('a rejected word shows why, inline', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          inputError: 'This word is not in the dictionary',
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('This word is not in the dictionary'), findsOneWidget);
    });

    testWidgets('suggestions are offered and tappable', (t) async {
      String? picked;
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          inputError: 'This word is not in the dictionary',
          suggestions: const ['book', 'books'],
          onSuggestionTap: (w) => picked = w,
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Did you mean:'), findsOneWidget);
      await t.tap(find.text('books'));
      await t.pumpAndSettle();
      expect(picked, 'books');
    });

    testWidgets('a solved game retires the composer', (t) async {
      final controller = TextEditingController(text: 'book');
      var submitted = 0;
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          controller: controller,
          solved: true,
          guesses: [guess('book', 1, heat: 1.0, solved: true)],
          onSubmit: (_) => submitted++,
        ),
      );
      await t.pumpAndSettle();

      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      await t.tap(find.bySemanticsLabel('Submit guess'));
      await t.pumpAndSettle();
      expect(submitted, 0);
    });

    testWidgets('the composer stays on screen when the keyboard is up', (
      t,
    ) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: List.generate(
            20,
            (i) => guess('word$i', i * 100 + 1, heat: 1 - i / 21),
          ),
        ),
      );
      await t.pumpAndSettle();

      final dry = t.getRect(find.byType(SiyaqGuessComposer));
      expect(dry.bottom, lessThanOrEqualTo(t.view.physicalSize.height));

      // Simulate the keyboard claiming the bottom 300px.
      t.view.viewInsets = const FakeViewPadding(bottom: 300 * 3);
      addTearDown(t.view.resetViewInsets);
      await t.pumpAndSettle();

      expect(find.byType(SiyaqGuessComposer), findsOneWidget);
      final wet = t.getRect(find.byType(SiyaqGuessComposer));
      expect(wet.bottom, lessThan(dry.bottom));
      // Best Guess is never sacrificed to the keyboard.
      expect(find.text('Closest'), findsOneWidget);
      expect(_takeError(), isNull);
    });
  });

  group('responsive', () {
    Future<void> narrow(WidgetTester t, Widget app, {double h = 1600}) async {
      t.view.physicalSize = Size(320, h);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app);
      await t.pumpAndSettle();
    }

    testWidgets('320px at 1.6x does not overflow', (t) async {
      await narrow(
        t,
        buildGameplay(uiLang: 'ar', guesses: _guesses, textScale: 1.6),
      );
      expect(_takeError(), isNull);
    });

    testWidgets('320px at 2.0x does not overflow', (t) async {
      await narrow(
        t,
        buildGameplay(
          uiLang: 'en',
          gameLanguage: GameplayLanguage.english,
          guesses: [guess('constitutional', 25, heat: 0.88)],
          hints: const [SiyaqHintData(word: 'parliamentary', rank: 42)],
          textScale: 2.0,
        ),
      );
      expect(_takeError(), isNull);
    });

    testWidgets('a long word truncates rather than breaking the row', (
      t,
    ) async {
      await narrow(
        t,
        buildGameplay(
          uiLang: 'ar',
          guesses: [
            guess('كلمة طويلة جداً لا تتسع أبداً في سطر واحد', 9, heat: 0.8),
          ],
        ),
      );
      expect(_takeError(), isNull);
    });
  });
}
