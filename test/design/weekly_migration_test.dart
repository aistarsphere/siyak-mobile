import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_weekly_screen.dart';
import 'package:context_game/features/v2/domain/entities/weekly.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/weekly_harness.dart';

/// Behavioural coverage for the migrated Weekly Challenge screen.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

Future<void> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.dark,
  String lang = 'ar',
  WeeklyState state = WeeklyState.active,
  Duration? timeRemaining = const Duration(days: 2, hours: 7, minutes: 41),
  bool participated = false,
  int? placement = 12,
  Object? error,
  bool loading = false,
  double textScale = 1.0,
  Size size = const Size(390, 1200),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    await buildWeekly(
      brightness: brightness,
      lang: lang,
      state: state,
      timeRemaining: timeRemaining,
      participated: participated,
      placement: placement,
      error: error,
      loading: loading,
      textScale: textScale,
    ),
  );
  if (loading) {
    // The loading branch hosts an indeterminate spinner, so the tree never
    // reaches quiescence — pump fixed frames instead of settling.
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));
  } else {
    // pumpAndSettle is required for the error branch: it lets Riverpod publish
    // AsyncError and the AnimatedSwitcher finish its cross-fade.
    await t.pumpAndSettle();
  }
}

void main() {
  group('week progress derivation', () {
    test('maps remaining time to elapsed fraction of the week', () {
      // Pure function over the server's `timeRemaining` — no new API field.
      expect(SiyagWeeklyScreen.weekProgress(null), isNull);
      expect(SiyagWeeklyScreen.weekProgress(const Duration(days: 7)), 0.0);
      expect(SiyagWeeklyScreen.weekProgress(Duration.zero), 1.0);
      expect(
        SiyagWeeklyScreen.weekProgress(const Duration(days: 3, hours: 12)),
        closeTo(0.5, 0.001),
      );
    });

    test('clamps a remaining time longer than a week', () {
      expect(SiyagWeeklyScreen.weekProgress(const Duration(days: 30)), 0.0);
    });
  });

  group('data rendering', () {
    testWidgets('renders hero, countdown, progress and meta stats', (t) async {
      await _pump(t, lang: 'en');
      expect(find.byType(SiyaqProgressBar), findsOneWidget);
      // 3 countdown cards + 3 meta cards.
      expect(find.byType(SiyaqStatCard), findsNWidgets(6));
      expect(find.byType(SiyaqStatGrid), findsNWidgets(2));
      // Countdown from the fixture: 2d 07h 41m.
      expect(find.text('02'), findsOneWidget);
      expect(find.text('07'), findsOneWidget);
      expect(find.text('41'), findsOneWidget);
    });

    testWidgets('shows the localized category and placement', (t) async {
      await _pump(t, lang: 'en');
      expect(find.text('Literature'), findsOneWidget);
      expect(find.text('#12'), findsOneWidget);
    });

    testWidgets('shows the Arabic category label in Arabic', (t) async {
      await _pump(t);
      expect(find.text('أدب'), findsOneWidget);
    });

    testWidgets('placement falls back to a placeholder when absent', (t) async {
      await _pump(t, lang: 'en', placement: null);
      expect(find.text('#12'), findsNothing);
      expect(find.text('—'), findsOneWidget);
    });

    testWidgets('countdown shows dashes when the server sends no duration', (
      t,
    ) async {
      await _pump(t, lang: 'en', timeRemaining: null);
      expect(find.text('--'), findsNWidgets(3));
      // No progress bar without a duration to derive it from.
      expect(find.byType(SiyaqProgressBar), findsNothing);
    });
  });

  group('participation states', () {
    // Separate tests: re-pumping in one test reuses the ProviderScope element,
    // so the provider keeps its first value and the second fixture never applies.
    testWidgets('not started shows Start', (t) async {
      await _pump(t, lang: 'en');
      expect(find.text('Start challenge'), findsOneWidget);
      expect(find.text('Resume challenge'), findsNothing);
    });

    testWidgets('participated shows Resume', (t) async {
      await _pump(t, lang: 'en', participated: true);
      expect(find.text('Resume challenge'), findsOneWidget);
      expect(find.text('Start challenge'), findsNothing);
    });

    testWidgets('completed shows a success banner and tinted state', (t) async {
      await _pump(t, lang: 'en', state: WeeklyState.completed);
      expect(find.byType(SiyaqTintedSurface), findsOneWidget);
      expect(find.text('Completed'), findsWidgets);
    });

    testWidgets('active shows no completed banner', (t) async {
      await _pump(t, lang: 'en');
      expect(find.byType(SiyaqTintedSurface), findsNothing);
    });
  });

  group('states', () {
    testWidgets('loading shows a loader, not a blank screen', (t) async {
      await _pump(t, loading: true);
      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.byType(SiyaqStatCard), findsNothing);
    });

    testWidgets('error shows a retry affordance', (t) async {
      await _pump(t, lang: 'en', error: Exception('network'));
      expect(find.byType(SiyaqEmptyState), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
      await t.tap(find.text('Retry'));
      await t.pump();
      expect(_takeError(), isNull);
    });

    testWidgets('the header stays visible in every state', (t) async {
      for (final scenario in ['data', 'loading', 'error']) {
        await _pump(
          t,
          lang: 'en',
          loading: scenario == 'loading',
          error: scenario == 'error' ? Exception('x') : null,
        );
        expect(
          find.byType(SiyaqScreenHeader),
          findsOneWidget,
          reason: 'header missing in $scenario',
        );
      }
    });
  });

  group('localization', () {
    testWidgets('Arabic renders RTL', (t) async {
      await _pump(t);
      expect(
        Directionality.of(t.element(find.byType(SiyaqProgressBar))),
        TextDirection.rtl,
      );
    });

    testWidgets('English renders LTR with a correct back affordance', (
      t,
    ) async {
      await _pump(t, lang: 'en');
      expect(
        Directionality.of(t.element(find.byType(SiyaqProgressBar))),
        TextDirection.ltr,
      );
      // One glyph in both directions: `arrow_back` declares matchTextDirection,
      // so Flutter mirrors it for RTL. The old top bar hardcoded a right-pointing
      // chevron that was wrong in LTR.
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(find.byIcon(Icons.arrow_forward_rounded), findsNothing);
    });

    testWidgets('Arabic uses the same auto-mirroring back glyph', (t) async {
      await _pump(t);
      expect(find.byIcon(Icons.arrow_back_rounded), findsOneWidget);
      expect(
        Icons.arrow_back_rounded.matchTextDirection,
        isTrue,
        reason: 'mirroring must come from the glyph, not a manual branch',
      );
    });

    testWidgets('no hardcoded Arabic leaks into the English build', (t) async {
      await _pump(t, lang: 'en');
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
          for (final state in WeeklyState.values) {
            await _pump(
              t,
              brightness: brightness,
              lang: lang,
              state: state,
              participated: state != WeeklyState.notStarted,
            );
            expect(_takeError(), isNull, reason: '$brightness/$lang/$state');
          }
        }
      }
    });

    testWidgets('320px at text scale 1.6 does not overflow', (t) async {
      await _pump(t, textScale: 1.6, size: const Size(320, 2000));
      expect(_takeError(), isNull);
    });

    testWidgets('320px at text scale 2.0 does not overflow', (t) async {
      await _pump(t, textScale: 2.0, size: const Size(320, 2600));
      expect(_takeError(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('progress is announced as a percentage', (t) async {
      await _pump(t, lang: 'en');
      final handle = t.ensureSemantics();
      // 2d 7h 41m remaining of 7 days ≈ 66% elapsed.
      expect(
        find.bySemanticsLabel(RegExp(r'Time remaining: \d+%')),
        findsOneWidget,
      );
      handle.dispose();
    });

    testWidgets('meta stats announce label and value together', (t) async {
      await _pump(t, lang: 'en');
      final handle = t.ensureSemantics();
      expect(find.bySemanticsLabel('Category: Literature'), findsOneWidget);
      expect(find.bySemanticsLabel('Your placement: 12'), findsOneWidget);
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
