import 'package:context_game/core/design/components/foundation/siyaq_button.dart';
import 'package:context_game/core/design/components/shared/siyaq_list_row.dart';
import 'package:context_game/core/design/components/shared/siyaq_player_row.dart';
import 'package:context_game/core/design/components/shared/siyaq_room_code.dart';
import 'package:context_game/core/design/components/shared/siyaq_screen_header.dart';
import 'package:context_game/core/design/components/shared/siyaq_select_tile.dart';
import 'package:context_game/core/design/components/shared/siyaq_stat_card.dart';
import 'package:context_game/core/design/components/shared/siyaq_states.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/room_harness.dart';

/// Non-null when the frame recorded a layout overflow (or any other framework
/// error). The same pattern the Profile/Hub suites use.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

/// Feature QA for the Room Lobby / Create Room / Join Room migration.
///
/// Scope is deliberately the three room screens plus the two shared components
/// this phase extended. Anything broader belongs to the regression suite.
void main() {
  // ── Room Lobby ──────────────────────────────────────────────────────────────
  group('Room Lobby', () {
    testWidgets('renders the join code, participants and host controls', (
      t,
    ) async {
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.dark,
          lang: 'en',
          roomState: room(
            participants: [
              participant('كاظم', isHost: true, isMe: true),
              participant('Sara'),
            ],
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqCodeDisplay), findsOneWidget);
      expect(find.text('A7X2'), findsOneWidget);
      expect(find.byType(SiyaqPlayerRow), findsNWidgets(2));
      expect(find.text('Host'), findsOneWidget);
      // maxPlayers present → the header counts against the cap.
      expect(find.textContaining('2/4'), findsOneWidget);
    });

    testWidgets('shows the empty state when nobody has joined', (t) async {
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.light,
          lang: 'en',
          roomState: room(participants: const []),
        ),
      );
      await t.pumpAndSettle();

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Waiting for players to join'), findsOneWidget);
      expect(find.byType(SiyaqPlayerRow), findsNothing);
    });

    testWidgets('holds the loader until the room resolves', (t) async {
      await t.pumpWidget(
        await buildLobby(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pump();

      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.byType(SiyaqCodeDisplay), findsNothing);
    });

    // One test per state: a second pumpWidget in the same test reuses the
    // ProviderScope element and keeps the first override.
    for (final (status, label) in const [
      (RoomConnStatus.connected, 'Connected'),
      (RoomConnStatus.reconnecting, 'Reconnecting...'),
      (RoomConnStatus.recovering, 'Reconnecting...'),
      (RoomConnStatus.connecting, 'Connecting'),
      (RoomConnStatus.idle, 'Connecting'),
    ]) {
      testWidgets('connection status $status announces "$label"', (t) async {
        await t.pumpWidget(
          await buildLobby(
            brightness: Brightness.dark,
            lang: 'en',
            roomState: room(participants: [participant('Sara')]),
            status: status,
          ),
        );
        await t.pump();
        expect(find.text(label), findsOneWidget);
      });
    }

    testWidgets('a player row announces name, role and connection as one', (
      t,
    ) async {
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          await buildLobby(
            brightness: Brightness.dark,
            lang: 'en',
            roomState: room(
              participants: [
                participant('Sara', isHost: true, connected: false),
              ],
            ),
          ),
        );
        await t.pumpAndSettle();

        expect(
          find.bySemanticsLabel(RegExp(r'Sara.*Host.*[Oo]ffline')),
          findsOneWidget,
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the join code stays LTR under Arabic', (t) async {
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.dark,
          roomState: room(participants: [participant('Sara')]),
        ),
      );
      await t.pumpAndSettle();

      final code = find.ancestor(
        of: find.text('A7X2'),
        matching: find.byType(Directionality),
      );
      expect(
        t.widget<Directionality>(code.first).textDirection,
        TextDirection.ltr,
      );
      // …while the screen itself is RTL.
      expect(
        Directionality.of(t.element(find.byType(SiyaqScreenHeader))),
        TextDirection.rtl,
      );
    });
  });

  // ── Join Room ───────────────────────────────────────────────────────────────
  group('Join Room', () {
    testWidgets('disables Join until a code is typed', (t) async {
      await t.pumpWidget(
        await buildJoin(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();

      expect(t.widget<SiyaqButton>(find.byType(SiyaqButton)).onPressed, isNull);

      await t.enterText(find.byType(TextField), 'a7x2');
      await t.pumpAndSettle();

      expect(
        t.widget<SiyaqButton>(find.byType(SiyaqButton)).onPressed,
        isNotNull,
      );
    });

    testWidgets('normalizes input to uppercase alphanumerics', (t) async {
      await t.pumpWidget(
        await buildJoin(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();

      await t.enterText(find.byType(TextField), 'a7-x 2!');
      await t.pumpAndSettle();

      expect(find.text('A7X2'), findsOneWidget);
    });

    testWidgets('shows the searching state while the join is in flight', (
      t,
    ) async {
      await t.pumpWidget(
        await buildJoin(brightness: Brightness.dark, lang: 'en', busy: true),
      );
      await t.pump();

      expect(find.text('Finding the game...'), findsOneWidget);
      expect(t.widget<SiyaqButton>(find.byType(SiyaqButton)).loading, isTrue);
    });

    testWidgets('the code field is a labelled text field', (t) async {
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          await buildJoin(brightness: Brightness.dark, lang: 'en'),
        );
        await t.pumpAndSettle();

        expect(
          find.bySemanticsLabel('Enter the game code'),
          findsAtLeastNWidgets(1),
        );
      } finally {
        handle.dispose();
      }
    });
  });

  // ── Create Room ─────────────────────────────────────────────────────────────
  group('Create Room', () {
    /// [settle] false pumps a fixed number of frames instead — the busy state
    /// keeps a progress indicator spinning, so the tree never settles.
    Future<void> tapNext(WidgetTester t, {bool settle = true}) async {
      await t.tap(find.text('Next'));
      if (settle) {
        await t.pumpAndSettle();
      } else {
        await t.pump();
        await t.pump(const Duration(milliseconds: 400));
      }
    }

    testWidgets('walks the five steps to the summary', (t) async {
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();

      expect(find.text('Choose Language'), findsOneWidget);
      await tapNext(t);
      expect(find.text('Choose Category'), findsOneWidget);
      await tapNext(t);
      expect(find.text('Choose Game Mode'), findsOneWidget);
      await tapNext(t);
      expect(find.text('Players Count'), findsOneWidget);
      await tapNext(t);

      expect(find.text('Ready'), findsOneWidget);
      // The summary is the stat grid, and the last step swaps Next for Create.
      expect(find.byType(SiyaqStatCard), findsNWidgets(4));
      expect(find.text('Create Game'), findsAtLeastNWidgets(1));
      expect(find.text('Next'), findsNothing);
    });

    testWidgets('only playable categories become tiles', (t) async {
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();
      await tapNext(t);

      expect(find.byType(SiyaqSelectTile), findsNWidgets(3));
      expect(find.text('Locked'), findsNothing);
      expect(find.text('General'), findsOneWidget);
    });

    testWidgets('selecting a category carries into the summary', (t) async {
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();
      await tapNext(t);

      await t.tap(find.text('Sports'));
      await t.pumpAndSettle();
      await tapNext(t);
      await tapNext(t);
      await tapNext(t);

      expect(find.text('Sports'), findsOneWidget);
    });

    testWidgets('mode and player choices carry into the summary', (t) async {
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();
      await tapNext(t);
      await tapNext(t);

      await t.tap(find.text('Competitive Mode'));
      await t.pumpAndSettle();
      await tapNext(t);

      await t.tap(find.text('6 Players'));
      await t.pumpAndSettle();
      await tapNext(t);

      expect(find.text('Competitive Mode'), findsOneWidget);
      expect(find.text('6'), findsOneWidget);
    });

    testWidgets('single-choice rows announce selection', (t) async {
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          await buildCreate(brightness: Brightness.dark, lang: 'en'),
        );
        await t.pumpAndSettle();

        // The gameplay language seeds from the app language, which is 'en' here.
        expect(
          t.getSemantics(find.text('English').first),
          isSemantics(isSelected: true),
        );
        expect(
          t.getSemantics(find.text('Arabic').first),
          isSemantics(isSelected: false),
        );

        await t.tap(find.text('Arabic'));
        await t.pumpAndSettle();
        expect(
          t.getSemantics(find.text('Arabic').first),
          isSemantics(isSelected: true),
        );
      } finally {
        handle.dispose();
      }
    });

    testWidgets('the catalogue error offers a retry, not a blank step', (
      t,
    ) async {
      await t.pumpWidget(
        await buildCreate(
          brightness: Brightness.dark,
          lang: 'en',
          categories: null,
        ),
      );
      await t.pumpAndSettle();
      await tapNext(t);

      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      // Next must not advance past a step with no categories.
      expect(
        t
            .widget<SiyaqButton>(find.widgetWithText(SiyaqButton, 'Next'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('an empty catalogue is an empty state, not a blank step', (
      t,
    ) async {
      await t.pumpWidget(
        await buildCreate(
          brightness: Brightness.dark,
          lang: 'en',
          categories: const [],
        ),
      );
      await t.pumpAndSettle();
      await tapNext(t);

      expect(find.text('Nothing here yet'), findsOneWidget);
      expect(
        t
            .widget<SiyaqButton>(find.widgetWithText(SiyaqButton, 'Next'))
            .onPressed,
        isNull,
      );
    });

    testWidgets('holds the loader while the catalogue is pending', (t) async {
      await t.pumpWidget(
        await buildCreate(
          brightness: Brightness.dark,
          lang: 'en',
          loading: true,
        ),
      );
      await t.pump();
      await t.tap(find.text('Next'));
      await t.pump();

      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.byType(SiyaqSelectTile), findsNothing);
    });

    testWidgets('the step dots announce the position', (t) async {
      final handle = t.ensureSemantics();
      try {
        await t.pumpWidget(
          await buildCreate(brightness: Brightness.dark, lang: 'en'),
        );
        await t.pumpAndSettle();
        expect(find.bySemanticsLabel('Step 1 of 5'), findsOneWidget);

        await tapNext(t);
        expect(find.bySemanticsLabel('Step 2 of 5'), findsOneWidget);
      } finally {
        handle.dispose();
      }
    });

    testWidgets('back walks the wizard rather than leaving the screen', (
      t,
    ) async {
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();
      await tapNext(t);
      expect(find.text('Choose Category'), findsOneWidget);

      await t.tap(find.bySemanticsLabel('Back'));
      await t.pumpAndSettle();
      expect(find.text('Choose Language'), findsOneWidget);
    });

    testWidgets('the create action shows its loading state', (t) async {
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en', busy: true),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        // The last step mounts the loading Create button, whose spinner never
        // settles — pump fixed frames for that transition.
        await tapNext(t, settle: i < 3);
      }

      expect(
        t
            .widget<SiyaqButton>(
              find.widgetWithText(SiyaqButton, 'Create Game'),
            )
            .loading,
        isTrue,
      );
    });
  });

  // ── Layout limits ───────────────────────────────────────────────────────────
  group('320 px × large text', () {
    Future<void> narrow(
      WidgetTester t,
      Widget app, {
      double height = 2400,
    }) async {
      t.view.physicalSize = Size(320, height);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(app);
      await t.pumpAndSettle();
    }

    testWidgets('lobby survives 320 px at 1.6×', (t) async {
      await narrow(
        t,
        await buildLobby(
          brightness: Brightness.dark,
          roomState: room(
            participants: [
              participant('كاظم', isHost: true, isMe: true),
              participant('Sara', connected: false),
            ],
          ),
          textScale: 1.6,
        ),
      );
      expect(_takeError(), isNull);
    });

    testWidgets('create summary survives 320 px at 2.0×', (t) async {
      await narrow(
        t,
        await buildCreate(
          brightness: Brightness.dark,
          lang: 'en',
          textScale: 2.0,
        ),
      );
      for (var i = 0; i < 4; i++) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
      }
      expect(find.byType(SiyaqStatCard), findsNWidgets(4));
      expect(_takeError(), isNull);
    });

    testWidgets('category grid survives 320 px at 2.0×', (t) async {
      await narrow(
        t,
        await buildCreate(
          brightness: Brightness.dark,
          lang: 'en',
          textScale: 2.0,
        ),
      );
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      expect(find.byType(SiyaqSelectTile), findsNWidgets(3));
      expect(_takeError(), isNull);
    });

    testWidgets('join survives 320 px at 2.0×', (t) async {
      await narrow(
        t,
        await buildJoin(
          brightness: Brightness.light,
          lang: 'en',
          textScale: 2.0,
        ),
      );
      expect(_takeError(), isNull);
    });
  });

  // ── Shared components extended this phase ───────────────────────────────────
  group('SiyaqListRow selection (used by Create Room)', () {
    testWidgets('the indicator reflects state and is not separately tappable', (
      t,
    ) async {
      var taps = 0;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SiyaqListRow(
              title: 'Option',
              selected: true,
              showSelectionIndicator: true,
              onTap: () => taps++,
            ),
          ),
        ),
      );
      expect(find.byIcon(Icons.check_circle_rounded), findsOneWidget);
      await t.tap(find.byIcon(Icons.check_circle_rounded));
      expect(taps, 1);
    });
  });
}
