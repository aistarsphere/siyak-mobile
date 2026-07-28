import 'package:context_game/core/design/siyaq_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_harness.dart';

/// Regressions for defects the beta feel pass found on a physical device.
///
/// Each test here exists because live play surfaced something the golden and
/// migration suites could not: they render one static frame with tidy fixtures,
/// and these are ordering, timing and interaction bugs.
void main() {
  group('pinned Latest row', () {
    // The API returns `previous_guesses` ordered by rank, so the last element is
    // the *worst* guess. These fixtures mirror the device session that exposed
    // it: played sun → moon → star, and the row showed "moon".
    final rankOrdered = [
      guess('star', 11774, heat: 0.30),
      guess('sun', 17331, heat: 0.20),
      guess('moon', 20462, heat: 0.10),
    ];

    testWidgets('shows the word actually played last, not the list tail', (
      t,
    ) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: rankOrdered,
          lastWord: 'star', // the true latest
        ),
      );
      await t.pumpAndSettle();

      // 'star' is both best and latest here, so the Latest row collapses —
      // that is the correct outcome, and the bug was it showing 'moon'.
      expect(find.text('Latest'), findsNothing);
      expect(find.text('Closest'), findsOneWidget);
    });

    testWidgets('pins the true latest when it is not the best', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: rankOrdered,
          lastWord: 'sun', // played last, ranked middle
        ),
      );
      await t.pumpAndSettle();

      final latestRow = find.ancestor(
        of: find.text('Latest'),
        matching: find.byType(SiyaqGuessHighlight),
      );
      expect(latestRow, findsOneWidget);
      expect(
        find.descendant(of: latestRow, matching: find.text('sun')),
        findsOneWidget,
        reason: 'Latest must be the word played last',
      );
      expect(
        find.descendant(of: latestRow, matching: find.text('moon')),
        findsNothing,
        reason: 'the list tail is the worst-ranked guess, not the newest',
      );
    });

    testWidgets('falls back to the tail when no lastWord is known', (t) async {
      // Resumed session: nothing in the payload records what came last.
      await t.pumpWidget(buildGameplay(uiLang: 'en', guesses: rankOrdered));
      await t.pumpAndSettle();

      expect(find.text('Closest'), findsOneWidget);
      expect(find.text('Latest'), findsOneWidget);
    });
  });

  group('timeline ordering', () {
    testWidgets('is deterministic regardless of response order', (t) async {
      // Same three guesses, shuffled: the rendered order must not change.
      List<String> render(List<SiyaqGuessData> g) =>
          g.map((x) => x.word).toList();

      final a = [
        guess('star', 11774, heat: 0.30),
        guess('sun', 17331, heat: 0.20),
        guess('moon', 20462, heat: 0.10),
      ];
      final b = [
        guess('moon', 20462, heat: 0.10),
        guess('star', 11774, heat: 0.30),
        guess('sun', 17331, heat: 0.20),
      ];

      for (final fixture in [a, b]) {
        await t.pumpWidget(
          buildGameplay(uiLang: 'en', guesses: fixture, lastWord: 'star'),
        );
        await t.pumpAndSettle();
        expect(
          find.byType(SiyaqGuessRow),
          findsNWidgets(3),
          reason: render(fixture).toString(),
        );

        // Asserted by on-screen position, not tree order: the viewport is
        // reversed, so index 0 is built first but painted at the bottom.
        double y(String word) => t
            .getCenter(
              find.ancestor(
                of: find.text(word),
                matching: find.byType(SiyaqGuessRow),
              ),
            )
            .dy;

        expect(
          y('star'),
          lessThan(y('sun')),
          reason: 'best guess sits furthest from the composer',
        );
        expect(
          y('sun'),
          lessThan(y('moon')),
          reason: 'weakest guess sits nearest the composer',
        );
      }
    });
  });

  group('hint panel', () {
    testWidgets('opens on the first tap even with the keyboard up', (t) async {
      // The panel stays collapsed while typing so it cannot eat the timeline,
      // which made the header inert: on device the tap did nothing and the panel
      // sprang open later, whenever the keyboard happened to close.
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [guess('sun', 17331, heat: 0.2)],
          hintsRemaining: 3,
          // Keyboard raised, but with room left for the panel: the 800x600
          // test surface sheds hints entirely below ~400dp of body height,
          // which a full-size keyboard inset would trigger on its own.
          viewInsetsBottom: 120,
        ),
      );
      await t.pumpAndSettle();

      // Collapsed: the reveal action is not reachable yet.
      expect(find.text('Reveal a hint'), findsNothing);

      await t.tap(find.text('Hints'));
      await t.pumpAndSettle();

      // The tap drops focus; the harness keeps viewInsets fixed, so this asserts
      // the state flipped rather than relying on the keyboard animating away.
      final panel = t.widget<SiyaqHintPanel>(find.byType(SiyaqHintPanel));
      expect(
        panel.expanded || find.text('Reveal a hint').evaluate().isNotEmpty,
        isTrue,
        reason: 'one tap must produce one visible result',
      );
    });

    testWidgets('toggles freely when no keyboard is up', (t) async {
      await t.pumpWidget(
        buildGameplay(uiLang: 'en', guesses: [guess('sun', 17331, heat: 0.2)]),
      );
      await t.pumpAndSettle();

      await t.tap(find.text('Hints'));
      await t.pumpAndSettle();
      expect(find.text('Reveal a hint'), findsOneWidget);

      await t.tap(find.text('Hints'));
      await t.pumpAndSettle();
      expect(find.text('Reveal a hint'), findsNothing);
    });
  });

  group('score prominence', () {
    testWidgets('pinned rank uses the gameplay numeral role', (t) async {
      await t.pumpWidget(
        buildGameplay(
          uiLang: 'en',
          guesses: [guess('sun', 17331, heat: 0.2)],
          lastWord: 'sun',
        ),
      );
      await t.pumpAndSettle();

      final rank = t.widget<Text>(
        find.descendant(
          of: find.byType(SiyaqGuessHighlight),
          matching: find.text('#17331'),
        ),
      );
      // The rank is the score; it must not render smaller than the word.
      expect(rank.style?.fontSize, SiyaqTextRole.gameDistance.size);
      expect(rank.style?.fontSize, greaterThan(SiyaqTextRole.bodyLarge.size));
    });
  });
}
