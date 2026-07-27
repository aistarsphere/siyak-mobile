import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/siyag/presentation/siyag_shell.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/multiplayer_hub_harness.dart';

/// Behavioural coverage for the migrated Multiplayer Hub.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

Future<void> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.dark,
  String lang = 'ar',
  bool signedIn = true,
  int invitationCount = 0,
  Object? invitationsError,
  bool invitationsLoading = false,
  bool hasActiveRoom = false,
  double textScale = 1.0,
  Size size = const Size(390, 1400),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    await buildHub(
      brightness: brightness,
      lang: lang,
      signedIn: signedIn,
      invitationCount: invitationCount,
      invitationsError: invitationsError,
      invitationsLoading: invitationsLoading,
      hasActiveRoom: hasActiveRoom,
      textScale: textScale,
    ),
  );
  if (invitationsLoading) {
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));
  } else {
    await t.pumpAndSettle();
  }
}

void main() {
  group('actions', () {
    testWidgets('renders the four primary actions', (t) async {
      await _pump(t, lang: 'en');
      expect(find.text('Create Game'), findsOneWidget);
      expect(find.text('Join Game'), findsOneWidget);
      expect(find.text('Competitive Match'), findsOneWidget);
      expect(find.text('Online Players'), findsOneWidget);
      expect(find.byType(SiyaqListRow), findsNWidgets(4));
    });

    testWidgets('each action is a tappable row with a chevron and icon tile', (
      t,
    ) async {
      await _pump(t, lang: 'en');
      final rows = t.widgetList<SiyaqListRow>(find.byType(SiyaqListRow));
      for (final r in rows) {
        expect(r.onTap, isNotNull);
        expect(r.showChevron, isTrue);
        expect(r.leading, isA<SiyaqIconTile>());
      }
      expect(find.byType(SiyaqIconTile), findsNWidgets(4));
    });

    testWidgets('resume action appears only with an active room', (t) async {
      await _pump(t, lang: 'en');
      expect(find.text('Resume room'), findsNothing);
      expect(find.byType(SiyaqListRow), findsNWidgets(4));
    });

    testWidgets('resume action shows the live join code', (t) async {
      await _pump(t, lang: 'en', hasActiveRoom: true);
      expect(find.byType(SiyaqListRow), findsNWidgets(5));
      expect(find.textContaining('AB12CD'), findsOneWidget);
    });
  });

  group('guest state', () {
    testWidgets('guest sees a sign-in notice with an action', (t) async {
      await _pump(t, lang: 'en', signedIn: false);
      expect(find.byType(SiyaqTintedSurface), findsOneWidget);
      expect(find.text('Sign In'), findsOneWidget);
    });

    testWidgets('the notice never hides or disables the actions', (t) async {
      // Create and join-by-code work without an account, and the Players screen
      // gates itself — so the hub informs rather than blocks.
      await _pump(t, lang: 'en', signedIn: false);
      expect(find.byType(SiyaqListRow), findsNWidgets(4));
      for (final r in t.widgetList<SiyaqListRow>(find.byType(SiyaqListRow))) {
        expect(r.onTap, isNotNull);
      }
    });

    testWidgets('sign-in pops the flow and selects the account tab', (t) async {
      await _pump(t, lang: 'en', signedIn: false);
      final container = ProviderScope.containerOf(
        t.element(find.byType(SiyaqListRow).first),
      );
      expect(container.read(siyagTabProvider), 0);

      await t.tap(find.text('Sign In'));
      await t.pumpAndSettle();
      // Mirrors the Players screen's existing behaviour: tab index 2 = Profile.
      expect(container.read(siyagTabProvider), 2);
    });

    testWidgets('signed-in users see no sign-in notice', (t) async {
      await _pump(t, lang: 'en');
      expect(find.text('Sign In'), findsNothing);
    });
  });

  group('invitations', () {
    testWidgets('a pending count renders a badge on the Players row', (
      t,
    ) async {
      await _pump(t, lang: 'en', invitationCount: 3);
      expect(find.byType(SiyaqCountBadge), findsOneWidget);
      expect(find.text('3'), findsOneWidget);
    });

    testWidgets('zero invitations renders no badge', (t) async {
      await _pump(t, lang: 'en');
      // The badge collapses itself rather than the caller guarding.
      expect(find.text('0'), findsNothing);
    });

    testWidgets('a badge caps at 99+', (t) async {
      await _pump(t, lang: 'en', invitationCount: 150);
      expect(find.text('99+'), findsOneWidget);
    });

    testWidgets('while loading, the badge is absent but actions remain', (
      t,
    ) async {
      await _pump(t, lang: 'en', invitationsLoading: true);
      expect(find.byType(SiyaqCountBadge), findsOneWidget); // collapsed
      expect(find.byType(SiyaqListRow), findsNWidgets(4));
      // A supplementary count must never gate the screen behind a spinner.
      expect(find.byType(SiyaqLoader), findsNothing);
    });

    testWidgets('an error is surfaced inline with retry, actions intact', (
      t,
    ) async {
      // Pre-migration `.asData?.value.length ?? 0` swallowed this entirely.
      await _pump(t, lang: 'en', invitationsError: Exception('network'));
      expect(find.byType(SiyaqTintedSurface), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      expect(find.byType(SiyaqListRow), findsNWidgets(4));
      await t.tap(find.text('Retry'));
      await t.pumpAndSettle();
      expect(_takeError(), isNull);
    });

    testWidgets('guests see no invitation error (provider short-circuits)', (
      t,
    ) async {
      await _pump(
        t,
        lang: 'en',
        signedIn: false,
        invitationsError: Exception('network'),
      );
      // Only the guest notice, not an error notice.
      expect(find.text('Retry'), findsNothing);
      expect(find.text('Sign In'), findsOneWidget);
    });
  });

  group('localization', () {
    testWidgets('Arabic renders RTL with Arabic copy', (t) async {
      await _pump(t);
      expect(
        Directionality.of(t.element(find.byType(SiyaqListRow).first)),
        TextDirection.rtl,
      );
      expect(find.text('إنشاء لعبة'), findsOneWidget);
    });

    testWidgets('English renders LTR with an auto-mirroring back glyph', (
      t,
    ) async {
      await _pump(t, lang: 'en');
      expect(
        Directionality.of(t.element(find.byType(SiyaqListRow).first)),
        TextDirection.ltr,
      );
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('no hardcoded Arabic leaks into the English build', (t) async {
      await _pump(t, lang: 'en', hasActiveRoom: true, invitationCount: 2);
      final arabic = RegExp(r'[؀-ۿ]');
      final leaked = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(arabic.hasMatch)
          .toList();
      expect(leaked, isEmpty, reason: 'hardcoded Arabic found: $leaked');
    });
  });

  group('themes and resilience', () {
    testWidgets('renders every state × theme × language without error', (
      t,
    ) async {
      for (final brightness in Brightness.values) {
        for (final lang in ['ar', 'en']) {
          for (final scenario in ['guest', 'signedIn', 'active', 'error']) {
            await _pump(
              t,
              brightness: brightness,
              lang: lang,
              signedIn: scenario != 'guest',
              hasActiveRoom: scenario == 'active',
              invitationsError: scenario == 'error' ? Exception('x') : null,
              invitationCount: scenario == 'signedIn' ? 2 : 0,
            );
            expect(_takeError(), isNull, reason: '$brightness/$lang/$scenario');
          }
        }
      }
    });

    testWidgets('320px at text scale 1.6 does not overflow', (t) async {
      await _pump(
        t,
        signedIn: false,
        hasActiveRoom: true,
        invitationCount: 3,
        textScale: 1.6,
        size: const Size(320, 2600),
      );
      expect(_takeError(), isNull);
    });

    testWidgets('320px at text scale 2.0 does not overflow', (t) async {
      await _pump(
        t,
        signedIn: false,
        hasActiveRoom: true,
        invitationCount: 3,
        textScale: 2.0,
        size: const Size(320, 3400),
      );
      expect(_takeError(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('each action announces its title and description', (t) async {
      await _pump(t, lang: 'en');
      final handle = t.ensureSemantics();
      expect(find.bySemanticsLabel(RegExp(r'^Create Game\.')), findsOneWidget);
      handle.dispose();
    });

    testWidgets('the pending count is part of the row announcement', (t) async {
      // The row is one interactive semantics node, so a badge nested inside it is
      // excluded. The count therefore has to live in the row's own label.
      await _pump(t, lang: 'en', invitationCount: 3);
      final handle = t.ensureSemantics();
      expect(
        find.bySemanticsLabel(RegExp(r'Online Players\..*3 invitations')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('the back button has an accessible name', (t) async {
      await _pump(t, lang: 'en');
      final handle = t.ensureSemantics();
      final node = t.getSemantics(find.byType(SiyaqIconButton));
      expect(node.label.trim(), isNotEmpty);
      handle.dispose();
    });
  });
}
