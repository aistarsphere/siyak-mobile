import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/ranked.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_modes_harness.dart';

/// Feature QA for the Room Game and Ranked Match migrations.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

final _sharedHistory = [
  shared('كتاب', 25, by: 'كاظم', isMine: true), // best
  shared('قلم', 900, by: 'Sara'),
  shared('مكتبة', 42, by: '—', isSystemHint: true), // hint, not a guess
  shared('سيارة', 4200, by: 'Sara'), // latest arrival
];

void main() {
  // ── Room Game ───────────────────────────────────────────────────────────────
  group('Room Game', () {
    testWidgets('renders the shared timeline with the gameplay components', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
        ),
      );
      await t.pumpAndSettle();

      // System hints are lifted out of the timeline into the panel.
      expect(find.byType(SiyaqGuessRow), findsNWidgets(3));
      expect(find.byType(SiyaqHintPanel), findsOneWidget);
      expect(find.byType(SiyaqGuessComposer), findsOneWidget);
      expect(find.byType(SiyaqGuessHighlight), findsNWidgets(2));
    });

    testWidgets('history is closest-first and carries rank + closeness', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
        ),
      );
      await t.pumpAndSettle();

      final rows = find.byType(SiyaqGuessRow);
      expect(t.widget<SiyaqGuessRow>(rows.at(0)).guess.word, 'كتاب'); // rank 25
      expect(t.widget<SiyaqGuessRow>(rows.at(2)).guess.word, 'سيارة'); // 4200
      expect(t.widget<SiyaqGuessRow>(rows.at(0)).guess.heat, isNotNull);
      expect(t.widget<SiyaqGuessRow>(rows.at(0)).bandLabel, isNotNull);
      expect(find.text('#25'), findsWidgets);
    });

    testWidgets('every row names its author, and the hint is not a player', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('كاظم'), findsWidgets);
      expect(find.text('Sara'), findsWidgets);
      for (final row in t.widgetList<SiyaqGuessRow>(
        find.byType(SiyaqGuessRow),
      )) {
        expect(row.attribution, isNotNull, reason: row.guess.word);
      }
    });

    testWidgets('Best is the closest rank, Latest is the newest arrival', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
        ),
      );
      await t.pumpAndSettle();

      final hl = find.byType(SiyaqGuessHighlight);
      expect(t.widget<SiyaqGuessHighlight>(hl.at(0)).guess.word, 'كتاب');
      expect(t.widget<SiyaqGuessHighlight>(hl.at(1)).guess.word, 'سيارة');
    });

    testWidgets('Latest collapses when the newest arrival is also the best', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(
            history: [
              shared('قلم', 900, by: 'Sara'),
              shared('كتاب', 25, by: 'كاظم', isMine: true),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.byType(SiyaqGuessHighlight), findsOneWidget);
    });

    testWidgets('system hints live in the panel, labelled by rank', (t) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('1 revealed'), findsOneWidget);
      expect(find.text('مكتبة'), findsNothing); // collapsed

      await t.tap(find.bySemanticsLabel('Show hints'));
      await t.pumpAndSettle();

      expect(find.text('مكتبة'), findsOneWidget);
      expect(find.text('#42'), findsOneWidget);
      expect(find.textContaining('Hint #'), findsNothing);
    });

    testWidgets('an empty timeline explains the rules', (t) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: const []),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Start with any word'), findsOneWidget);
      expect(find.byType(SiyaqGuessRow), findsNothing);
    });

    testWidgets('reconnecting is announced, and play continues', (t) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
          status: RoomConnStatus.reconnecting,
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Reconnecting...'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('a solved room retires the composer and shows the winner', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(
            history: [
              ..._sharedHistory,
              shared('قاموس', 1, by: 'كاظم', isMine: true, solved: true),
            ],
            state: RoomState.solved,
            winner: const RoomParticipant(
              participantId: 'p_كاظم',
              label: 'كاظم',
              isHost: true,
              isMe: true,
            ),
            secretWord: 'قاموس',
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('WINNER'), findsOneWidget);
      expect(find.text('The word'), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
    });

    testWidgets('holds the loader until the room snapshot arrives', (t) async {
      await t.pumpWidget(await buildRoomGame(uiLang: 'en'));
      await t.pump();

      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.byType(SiyaqGuessRow), findsNothing);
    });

    testWidgets('words follow the room language, chrome follows the app', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'ar',
          room: roomWith(
            history: [shared('library', 25, by: 'Sara')],
            language: GameplayLanguage.english,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(
        Directionality.of(t.element(find.byType(SiyaqScreenHeader))),
        TextDirection.rtl,
      );
      expect(
        t.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.ltr,
      );
    });
  });

  // ── Ranked Match ────────────────────────────────────────────────────────────
  group('Ranked Match', () {
    /// A ListView only builds what fits, so assertions about the whole history
    /// need a viewport that can hold it.
    void tall(WidgetTester t) {
      t.view.physicalSize = const Size(400, 1600);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
    }

    final guesses = [
      matchGuess('library', rank: 25, isYou: true, turn: 1), // best
      matchGuess('shelf', rank: 900, turn: 2),
      matchGuess('car', rank: 4200, isYou: true, turn: 3), // latest
    ];

    testWidgets('renders the match on the gameplay components', (t) async {
      tall(t);
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqGuessRow), findsNWidgets(3));
      expect(find.byType(SiyaqGuessHighlight), findsNWidgets(2));
      expect(find.byType(SiyaqGuessComposer), findsOneWidget);
      expect(find.byType(SiyaqPlayerRow), findsNWidgets(2));
    });

    testWidgets('rows are rank-only — no fabricated closeness band', (t) async {
      tall(t);
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses),
        ),
      );
      await t.pumpAndSettle();

      for (final row in t.widgetList<SiyaqGuessRow>(
        find.byType(SiyaqGuessRow),
      )) {
        expect(row.guess.heat, isNull, reason: row.guess.word);
        expect(row.bandLabel, isNull);
      }
      // The rank is still there, and it is the whole signal.
      expect(find.text('#25'), findsWidgets);
      expect(find.text('Blazing'), findsNothing);
    });

    testWidgets('history is closest-first, like every other mode', (t) async {
      tall(t);
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses),
        ),
      );
      await t.pumpAndSettle();

      final rows = find.byType(SiyaqGuessRow);
      expect(t.widget<SiyaqGuessRow>(rows.at(0)).guess.rank, 25);
      expect(t.widget<SiyaqGuessRow>(rows.at(2)).guess.rank, 4200);
    });

    testWidgets('Best is the lowest rank, Latest is the last submission', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses),
        ),
      );
      await t.pumpAndSettle();

      final hl = find.byType(SiyaqGuessHighlight);
      expect(t.widget<SiyaqGuessHighlight>(hl.at(0)).guess.word, 'library');
      expect(t.widget<SiyaqGuessHighlight>(hl.at(1)).guess.word, 'car');
    });

    testWidgets('an unscored guess can never be the best', (t) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            language: 'en',
            guesses: [
              matchGuess('scored', rank: 900, isYou: true, turn: 1),
              matchGuess('pending', isYou: true, turn: 2), // rank == null
            ],
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(
        t
            .widget<SiyaqGuessHighlight>(find.byType(SiyaqGuessHighlight).first)
            .guess
            .word,
        'scored',
      );
    });

    testWidgets('you versus opponent is attributed on every row', (t) async {
      tall(t);
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('You'), findsWidgets);
      expect(find.text('Opponent'), findsWidgets);
    });

    testWidgets('my turn enables the composer and states the countdown', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses, turnRemaining: 18),
        ),
      );
      await t.pumpAndSettle();

      expect(find.textContaining('Your turn'), findsWidgets);
      expect(find.textContaining('18'), findsWidgets);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isTrue);
    });

    testWidgets('the opponent turn disables the composer and says why', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: guesses, myTurn: false),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text("Opponent's turn"), findsOneWidget);
      expect(t.widget<TextField>(find.byType(TextField)).enabled, isFalse);
      // The placeholder carries the reason, so a dead field is never unexplained.
      expect(find.text('Wait your turn'), findsOneWidget);
    });

    testWidgets('preparing offers the ready action, and no composer yet', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(status: RankedMatchStatus.preparing, language: 'en'),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Get ready for the match'), findsOneWidget);
      expect(find.text("I'm ready"), findsOneWidget);
      expect(find.byType(SiyaqGuessComposer), findsNothing);
    });

    // Separate test: a second pumpWidget reuses the ProviderScope element and
    // keeps the first override.
    testWidgets('once ready, it waits on the opponent', (t) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            status: RankedMatchStatus.preparing,
            language: 'en',
            youReady: true,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Waiting for opponent…'), findsOneWidget);
      expect(find.text("I'm ready"), findsNothing);
    });

    testWidgets('a win shows the word and the rating change', (t) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            status: RankedMatchStatus.solved,
            language: 'en',
            guesses: guesses,
            winner: 'me',
            secretWord: 'bookshelf',
            ratingDelta: 24,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('You won!'), findsOneWidget);
      expect(find.text('bookshelf'), findsOneWidget);
      expect(find.textContaining('+24'), findsOneWidget);
      expect(find.byType(SiyaqGuessComposer), findsNothing);
    });

    testWidgets('a loss reads as ended, with a negative delta', (t) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            status: RankedMatchStatus.solved,
            language: 'en',
            winner: 'them',
            ratingDelta: -18,
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('Match over'), findsOneWidget);
      expect(find.textContaining('-18'), findsOneWidget);
    });

    testWidgets('holds the loader until the snapshot arrives', (t) async {
      await t.pumpWidget(await buildRankedMatch(uiLang: 'en'));
      await t.pump();
      expect(find.byType(SiyaqLoader), findsOneWidget);
    });

    testWidgets('words follow the match language, chrome follows the app', (
      t,
    ) async {
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            language: 'ar',
            guesses: [matchGuess('كتاب', rank: 25, isYou: true, turn: 1)],
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(
        Directionality.of(t.element(find.byType(SiyaqScreenHeader))),
        TextDirection.ltr,
      );
      expect(
        t.widget<TextField>(find.byType(TextField)).textDirection,
        TextDirection.rtl,
      );
    });
  });

  // ── Theme and layout limits ─────────────────────────────────────────────────
  group('theme and layout', () {
    for (final brightness in Brightness.values) {
      for (final lang in const ['ar', 'en']) {
        testWidgets('room renders in $brightness/$lang', (t) async {
          await t.pumpWidget(
            await buildRoomGame(
              brightness: brightness,
              uiLang: lang,
              room: roomWith(history: _sharedHistory),
            ),
          );
          await t.pumpAndSettle();
          expect(_takeError(), isNull);
        });

        testWidgets('ranked renders in $brightness/$lang', (t) async {
          await t.pumpWidget(
            await buildRankedMatch(
              brightness: brightness,
              uiLang: lang,
              snapshot: match(
                language: lang,
                guesses: [matchGuess('word', rank: 25, isYou: true, turn: 1)],
              ),
            ),
          );
          await t.pumpAndSettle();
          expect(_takeError(), isNull);
        });
      }
    }

    Future<void> narrow(WidgetTester t, Widget app, {double h = 2000}) async {
      t.view.physicalSize = Size(320, h);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app);
      await t.pumpAndSettle();
    }

    testWidgets('room survives 320px at 1.6x with long names', (t) async {
      await narrow(
        t,
        await buildRoomGame(
          uiLang: 'ar',
          room: roomWith(
            history: [
              shared(
                'كلمة طويلة جداً لا تتسع في سطر',
                25,
                by: 'Abdulrahman Al-Mutairi',
              ),
              shared('قلم', 18400, by: 'Sara'),
            ],
          ),
          textScale: 1.6,
        ),
      );
      expect(_takeError(), isNull);
    });

    testWidgets('room survives 320px at 2.0x', (t) async {
      await narrow(
        t,
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _sharedHistory),
          textScale: 2.0,
        ),
        h: 2800,
      );
      expect(_takeError(), isNull);
    });

    testWidgets('ranked survives 320px at 2.0x', (t) async {
      await narrow(
        t,
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            language: 'en',
            guesses: [
              matchGuess('constitutional', rank: 18400, isYou: true, turn: 1),
            ],
          ),
          textScale: 2.0,
        ),
        h: 2800,
      );
      expect(_takeError(), isNull);
    });
  });
}
