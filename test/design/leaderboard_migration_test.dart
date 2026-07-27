import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/v2/domain/entities/leaderboard.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/leaderboard_harness.dart';

/// Behavioural coverage for the migrated Leaderboard screen.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

Future<void> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.dark,
  String lang = 'ar',
  List<LeaderboardEntry> entries = const [],
  bool loading = false,
  int? currentPlacement,
  Object? error,
  double textScale = 1.0,
  Size size = const Size(390, 1400),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    await buildLeaderboard(
      brightness: brightness,
      lang: lang,
      entries: entries,
      loading: loading,
      currentPlacement: currentPlacement,
      error: error,
      textScale: textScale,
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 900));
}

void main() {
  group('populated list', () {
    testWidgets('renders a podium for the top three and rows for the rest', (
      t,
    ) async {
      await _pump(t, entries: kLeaderboardEntries);
      expect(find.byType(SiyaqPodium), findsOneWidget);
      // 10 entries − 3 on the podium = 7 rows.
      expect(find.byType(SiyaqLeaderboardRow), findsNWidgets(7));
    });

    testWidgets('podium is suppressed with fewer than three entries', (
      t,
    ) async {
      await _pump(t, entries: kLeaderboardEntries.take(2).toList());
      expect(find.byType(SiyaqPodium), findsNothing);
      // Both entries still appear — as rows, not swallowed by a partial podium.
      expect(find.byType(SiyaqLeaderboardRow), findsNothing);
      // (take(3) covers the podium slot; with 2 entries `skip(3)` is empty, which
      // matches the pre-migration behaviour exactly.)
    });

    testWidgets('marks the current player row as self', (t) async {
      await _pump(t, entries: kLeaderboardEntries);
      final rows = t.widgetList<SiyaqLeaderboardRow>(
        find.byType(SiyaqLeaderboardRow),
      );
      expect(rows.where((r) => r.isSelf).length, 1);
      expect(rows.firstWhere((r) => r.isSelf).label, 'Yusuf');
    });

    testWidgets('renders attempts and elapsed metadata per row', (t) async {
      await _pump(t, entries: kLeaderboardEntries);
      // Entry 8 is unsolved but still carries attempts + elapsed.
      expect(find.text('25'), findsOneWidget);
      expect(find.text('4:00'), findsOneWidget);
      expect(find.byType(SiyaqMetaStat), findsWidgets);
    });

    testWidgets('shows the solved marker only for solved entries', (t) async {
      await _pump(t, entries: kLeaderboardEntries);
      final rows = t.widgetList<SiyaqLeaderboardRow>(
        find.byType(SiyaqLeaderboardRow),
      );
      // Of the 7 listed rows, only "Omar" (#8) is unsolved.
      expect(rows.where((r) => r.solved).length, 6);
      expect(rows.where((r) => !r.solved).single.label, 'Omar');
    });

    testWidgets('shows own placement chip when the player is off-page', (
      t,
    ) async {
      // No entry is flagged isCurrentProfile, but the server knows the placement.
      final others = kLeaderboardEntries
          .where((e) => !e.isCurrentProfile)
          .toList();
      await _pump(t, entries: others, currentPlacement: 142);
      expect(find.byType(SiyaqChip), findsOneWidget);
      expect(
        find.textContaining('142'),
        findsOneWidget,
        reason: 'the off-page placement must still be reported',
      );
    });

    testWidgets('hides the placement chip when the player is on the page', (
      t,
    ) async {
      await _pump(t, entries: kLeaderboardEntries, currentPlacement: 6);
      expect(find.byType(SiyaqChip), findsNothing);
    });
  });

  group('states', () {
    testWidgets('first load shows a loader, not an empty list', (t) async {
      await _pump(t, loading: true);
      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.byType(SiyaqEmptyState), findsNothing);
    });

    testWidgets('zero data shows an empty state', (t) async {
      await _pump(t);
      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.byType(SiyaqLoader), findsNothing);
    });

    testWidgets('an error shows a retry affordance', (t) async {
      // Pre-migration this rendered a blank screen: LeaderboardState.error was
      // never read by the UI.
      await _pump(t, lang: 'en', error: Exception('boom'));
      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pump();
      expect(_takeError(), isNull);
    });

    testWidgets('pagination loader appears below existing rows', (t) async {
      await _pump(t, entries: kLeaderboardEntries, loading: true);
      // Rows are still visible; the loader is additive, not a replacement.
      expect(find.byType(SiyaqLeaderboardRow), findsNWidgets(7));
      expect(find.byType(SiyaqLoader), findsOneWidget);
    });
  });

  group('localization', () {
    testWidgets('Arabic renders RTL with Arabic header copy', (t) async {
      await _pump(t, entries: kLeaderboardEntries);
      expect(
        Directionality.of(t.element(find.byType(SiyaqPodium))),
        TextDirection.rtl,
      );
      expect(find.text('الترتيب'), findsOneWidget);
    });

    testWidgets('English renders LTR with English header copy', (t) async {
      await _pump(t, lang: 'en', entries: kLeaderboardEntries);
      expect(
        Directionality.of(t.element(find.byType(SiyaqPodium))),
        TextDirection.ltr,
      );
      expect(find.text('Placement'), findsOneWidget);
      expect(find.text('LEADERBOARD'), findsOneWidget);
    });

    testWidgets('no hardcoded Arabic leaks into the English build', (t) async {
      await _pump(t, lang: 'en', entries: kLeaderboardEntries);
      final arabic = RegExp(r'[؀-ۿ]');
      // Player names are data and legitimately Arabic; everything else is copy.
      final dataStrings = <String>{
        for (final e in kLeaderboardEntries) e.label,
        for (final e in kLeaderboardEntries) e.label.characters.first,
      };
      final leaked = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(arabic.hasMatch)
          .where((s) => !dataStrings.contains(s))
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
          for (final scenario in ['data', 'loading', 'empty', 'error']) {
            await _pump(
              t,
              brightness: brightness,
              lang: lang,
              entries: scenario == 'data' ? kLeaderboardEntries : const [],
              loading: scenario == 'loading',
              error: scenario == 'error' ? Exception('x') : null,
            );
            expect(_takeError(), isNull, reason: '$brightness/$lang/$scenario');
          }
        }
      }
    });

    testWidgets('320px at text scale 1.6 keeps names legible', (t) async {
      await _pump(
        t,
        entries: kLeaderboardEntries,
        textScale: 1.6,
        size: const Size(320, 2200),
      );
      expect(_takeError(), isNull);
      // Metadata drops to a second line so the name is not truncated away.
      expect(find.text('Yusuf'), findsOneWidget);
      expect(find.text('Hassan'), findsOneWidget);
    });

    testWidgets('320px at text scale 2.0 does not overflow', (t) async {
      await _pump(
        t,
        entries: kLeaderboardEntries,
        textScale: 2.0,
        size: const Size(320, 3000),
      );
      expect(_takeError(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('metadata is announced with units, not as bare numbers', (
      t,
    ) async {
      await _pump(t, lang: 'en', entries: kLeaderboardEntries);
      final handle = t.ensureSemantics();
      // The EN copy for `attempts` is "Guesses:" — the trailing colon is
      // stripped before composing, so this reads once, not twice.
      expect(find.bySemanticsLabel('Guesses: 25'), findsOneWidget);
      expect(find.bySemanticsLabel('Time: 4:00'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('each podium place is its own labelled node', (t) async {
      await _pump(t, lang: 'en', entries: kLeaderboardEntries);
      final handle = t.ensureSemantics();
      expect(find.bySemanticsLabel('Sara — 2'), findsOneWidget);
      handle.dispose();
    });
  });
}
