import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/profile_harness.dart';

/// Behavioural coverage for the migrated Profile screen.
///
/// These assert *behaviour and content*, not pixels — the goldens cover
/// appearance. Together they establish that the presentation swap preserved the
/// product: same data, same actions, same localization, in both themes and both
/// directions.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

Future<void> _pump(
  WidgetTester t, {
  Brightness brightness = Brightness.dark,
  String lang = 'ar',
  bool signedIn = false,
  bool blocked = false,
  bool appleSupported = false,
  double textScale = 1.0,
  Size size = const Size(390, 1200),
}) async {
  t.view.physicalSize = size;
  t.view.devicePixelRatio = 1.0;
  addTearDown(t.view.reset);
  await t.pumpWidget(
    await buildProfile(
      brightness: brightness,
      lang: lang,
      account: blocked
          ? kBlockedAccount
          : signedIn
          ? kSampleAccount
          : null,
      appleSupported: appleSupported,
      textScale: textScale,
    ),
  );
  await t.pump();
  await t.pump(const Duration(milliseconds: 32));
}

void main() {
  group('data rendering', () {
    testWidgets('shows all four real stats from the profile', (t) async {
      await _pump(t, signedIn: true);
      // Values straight from kSampleProfile — no placeholder, no mock.
      expect(find.text('128'), findsOneWidget); // gamesPlayed
      expect(find.text('96'), findsOneWidget); // gamesSolved
      expect(find.text('17'), findsOneWidget); // roomsWon
      expect(find.text('#3'), findsOneWidget); // weeklyBestPlacement
      expect(find.byType(SiyaqStatCard), findsNWidgets(4));
    });

    testWidgets('renders the em-dash placeholder when there is no profile', (
      t,
    ) async {
      t.view.physicalSize = const Size(390, 1200);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        await buildProfile(brightness: Brightness.dark, profile: null),
      );
      await t.pump();
      await t.pump(const Duration(milliseconds: 32));
      expect(
        find.descendant(
          of: find.byType(SiyaqStatCard),
          matching: find.text('—'),
        ),
        findsNWidgets(4),
      );
      // The name and avatar initial also fall back to the placeholder, which is
      // correct — there is genuinely no name to show.
      expect(find.text('—'), findsNWidgets(6));
    });

    testWidgets('signed in: shows account name and public player id', (
      t,
    ) async {
      await _pump(t, signedIn: true);
      expect(find.text('كاظم العكبي'), findsOneWidget);
      expect(find.text('SYG-4F2A9'), findsOneWidget);
      expect(find.byType(SiyaqChip), findsOneWidget);
    });

    testWidgets('guest: shows the installation label and no player id chip', (
      t,
    ) async {
      await _pump(t);
      expect(find.text('كاظم'), findsOneWidget); // profile.label
      expect(find.byType(SiyaqChip), findsNothing);
    });
  });

  group('account section', () {
    testWidgets('guest offers Google, and Apple only when supported', (
      t,
    ) async {
      await _pump(t, lang: 'en');
      expect(find.text('Sign in with Google'), findsOneWidget);
      expect(find.text('Sign in with Apple'), findsNothing);

      await _pump(t, lang: 'en', appleSupported: true);
      expect(find.text('Sign in with Apple'), findsOneWidget);
    });

    testWidgets('signed in shows the linked provider and a sign-out action', (
      t,
    ) async {
      await _pump(t, lang: 'en', signedIn: true);
      expect(find.text('Linked with Google'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
      expect(find.text('Sign in with Google'), findsNothing);
    });

    testWidgets('a blocked account surfaces the status banner', (t) async {
      await _pump(t, lang: 'en', blocked: true);
      expect(find.byType(SiyaqTintedSurface), findsOneWidget);
      // Apple-linked blocked fixture still shows its provider row.
      expect(find.text('Linked with Apple'), findsOneWidget);
    });

    testWidgets(
      'sign-out opens a confirm dialog and cancel is non-destructive',
      (t) async {
        await _pump(t, lang: 'en', signedIn: true);
        await t.tap(find.text('Sign out'));
        await t.pumpAndSettle();
        // The dialog offers both actions; nothing has happened yet.
        expect(find.text('Cancel'), findsOneWidget);
        await t.tap(find.text('Cancel'));
        await t.pumpAndSettle();
        expect(find.text('Cancel'), findsNothing);
        expect(find.text('Linked with Google'), findsOneWidget);
      },
    );
  });

  group('name editing', () {
    testWidgets('edit opens a sheet with a text field prefilled', (t) async {
      await _pump(t, lang: 'en', signedIn: true);
      await t.tap(find.text('Edit name'));
      await t.pumpAndSettle();
      expect(find.byType(SiyaqTextField), findsOneWidget);
      expect(find.byType(SiyaqSheet), findsOneWidget);
      // Prefilled from the account's display name.
      expect(
        t.widget<TextField>(find.byType(TextField)).controller!.text,
        'كاظم العكبي',
      );
      expect(find.text('Save'), findsOneWidget);
    });
  });

  group('settings controls', () {
    testWidgets('appearance selector changes the persisted theme mode', (
      t,
    ) async {
      await _pump(t, lang: 'en', signedIn: true);
      final container = ProviderScope.containerOf(
        t.element(find.byType(SiyaqSegmentedControl<ThemeMode>)),
      );
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.system);

      await t.tap(find.text('Dark'));
      await t.pumpAndSettle();
      expect(container.read(appSettingsProvider).themeMode, ThemeMode.dark);
    });

    testWidgets('language selector changes the persisted language', (t) async {
      await _pump(t, lang: 'en', signedIn: true);
      final container = ProviderScope.containerOf(
        t.element(find.byType(SiyaqSegmentedControl<String>)),
      );
      expect(container.read(appSettingsProvider).lang, 'en');

      await t.tap(find.text('Arabic'));
      await t.pumpAndSettle();
      expect(container.read(appSettingsProvider).lang, 'ar');
    });

    testWidgets('player id chip copies to the clipboard', (t) async {
      final calls = <MethodCall>[];
      t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call);
          return null;
        },
      );
      addTearDown(
        () => t.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );

      await _pump(t, lang: 'en', signedIn: true);
      await t.tap(find.byType(SiyaqChip));
      await t.pumpAndSettle();

      final copy = calls.where((c) => c.method == 'Clipboard.setData');
      expect(copy, isNotEmpty, reason: 'tapping the id must copy it');
      expect(copy.first.arguments['text'], 'SYG-4F2A9');
    });
  });

  group('localization', () {
    testWidgets('Arabic renders RTL with Arabic copy', (t) async {
      await _pump(t, signedIn: true);
      final dir = Directionality.of(
        t.element(find.byType(SiyaqStatCard).first),
      );
      expect(dir, TextDirection.rtl);
      expect(find.text('تعديل الاسم'), findsOneWidget);
      expect(find.text('تسجيل الخروج'), findsOneWidget);
    });

    testWidgets('English renders LTR with English copy', (t) async {
      await _pump(t, lang: 'en', signedIn: true);
      final dir = Directionality.of(
        t.element(find.byType(SiyaqStatCard).first),
      );
      expect(dir, TextDirection.ltr);
      expect(find.text('Edit name'), findsOneWidget);
      expect(find.text('Sign out'), findsOneWidget);
    });

    testWidgets('no raw Arabic literal leaks in the English build', (t) async {
      await _pump(t, lang: 'en', signedIn: true);
      // The only Arabic on an English screen is user data (the account name).
      final arabic = RegExp(r'[؀-ۿ]');
      final leaked = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where((s) => arabic.hasMatch(s))
          .where((s) => s != kSampleAccount.displayName)
          // The avatar renders the first grapheme of that same name.
          .where((s) => s != kSampleAccount.displayName!.characters.first)
          .toList();
      expect(leaked, isEmpty, reason: 'hardcoded Arabic found: $leaked');
    });
  });

  group('themes and resilience', () {
    testWidgets('renders in both themes × both languages without error', (
      t,
    ) async {
      for (final brightness in Brightness.values) {
        for (final lang in ['ar', 'en']) {
          for (final signedIn in [false, true]) {
            await _pump(
              t,
              brightness: brightness,
              lang: lang,
              signedIn: signedIn,
              appleSupported: true,
            );
            expect(
              _takeError(),
              isNull,
              reason: '$brightness/$lang/signedIn=$signedIn',
            );
          }
        }
      }
    });

    testWidgets('320px at text scale 1.6 does not overflow', (t) async {
      // The pre-migration screen overflowed by ~83px here: four stat cards in a
      // bare Row of Expanded. The stat grid now reflows to 2x2 instead.
      await _pump(
        t,
        signedIn: true,
        textScale: 1.6,
        size: const Size(320, 2000),
      );
      expect(_takeError(), isNull);
    });

    testWidgets('320px at text scale 2.0 does not overflow', (t) async {
      await _pump(
        t,
        signedIn: true,
        textScale: 2.0,
        size: const Size(320, 2600),
      );
      expect(_takeError(), isNull);
    });
  });

  group('accessibility', () {
    testWidgets('stat cards announce label and value together', (t) async {
      await _pump(t, lang: 'en', signedIn: true);
      final handle = t.ensureSemantics();
      expect(find.bySemanticsLabel('Games: 128'), findsOneWidget);
      expect(find.bySemanticsLabel('Best: 3'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('every interactive control has an accessible name', (t) async {
      await _pump(t, lang: 'en', signedIn: true);
      final handle = t.ensureSemantics();
      for (final f in [find.byType(SiyaqButton), find.byType(SiyaqChip)]) {
        for (final element in t.elementList(f)) {
          final node = t.getSemantics(
            find.byElementPredicate((e) => e == element),
          );
          expect(
            node.label.trim(),
            isNotEmpty,
            reason: 'a control rendered without an accessible name',
          );
        }
      }
      handle.dispose();
    });

    testWidgets('no emoji is used as an icon', (t) async {
      await _pump(t, signedIn: true);
      // The migration replaced glyph icons with SiyaqIcons; emoji in UI chrome
      // are invisible to screen readers and cannot be tinted.
      final emoji = RegExp(
        r'[\u{1F300}-\u{1FAFF}\u{2600}-\u{27BF}]',
        unicode: true,
      );
      final found = t
          .widgetList<Text>(find.byType(Text))
          .map((w) => w.data ?? '')
          .where(emoji.hasMatch)
          .toList();
      expect(found, isEmpty, reason: 'emoji used as icon: $found');
    });
  });
}
