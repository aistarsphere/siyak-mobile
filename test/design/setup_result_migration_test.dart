import 'dart:async';

import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/core/sound/sound_player_adapter.dart';
import 'package:context_game/core/sound/sound_service.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_result_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Feature QA for the Result and Practice-Setup migrations.
Object? _takeError() => TestWidgetsFlutterBinding.instance.takeException();

const _cats = [
  CategoryInfo(
    code: 'general',
    label: 'General',
    labelAr: 'عام',
    wordCount: 22548,
    playable: true,
  ),
  CategoryInfo(
    code: 'animals',
    label: 'Animals',
    labelAr: 'حيوانات',
    wordCount: 900,
    playable: true,
  ),
];

Future<Widget> _app({
  required Widget child,
  Brightness brightness = Brightness.dark,
  String lang = 'ar',
  List<CategoryInfo>? categories = _cats,
  bool loading = false,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();

  modesOverride() {
    if (loading) {
      return modesByLanguageProvider.overrideWith(
        (ref, language) => Completer<ModesInfo>().future,
      );
    }
    if (categories == null) {
      return modesByLanguageProvider.overrideWith(
        (ref, language) => throw Exception('offline'),
      );
    }
    return modesByLanguageProvider.overrideWith(
      (ref, language) => ModesInfo(language: language, categories: categories),
    );
  }

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      soundPlayerAdapterProvider.overrideWithValue(const SilentSoundAdapter()),
      modesOverride(),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.of(
        brightness,
        script: SiyaqTypography.scriptForLocale(lang),
      ),
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Builder(
        builder: (context) => MediaQuery(
          data: MediaQuery.of(
            context,
          ).copyWith(textScaler: TextScaler.linear(textScale)),
          child: child,
        ),
      ),
    ),
  );
}

void main() {
  // The Practice-setup coverage now lives in language_availability_ui_test.dart,
  // which exercises the same screen against the Language Availability Contract.

  group('Result', () {
    Widget result({bool showLeaderboard = true}) => SiyagResultScreen(
      secretWord: 'مكتبة',
      attempts: 12,
      hintsUsed: 2,
      elapsed: const Duration(minutes: 3, seconds: 5),
      showLeaderboard: showLeaderboard,
    );

    testWidgets('renders word, stats and actions on the DS', (t) async {
      await t.pumpWidget(await _app(lang: 'en', child: result()));
      await t.pump(const Duration(seconds: 1));

      expect(find.text('مكتبة'), findsOneWidget);
      expect(find.byType(SiyaqStatCard), findsNWidgets(3));
      expect(find.text('12'), findsOneWidget);
      expect(find.text('3:05'), findsOneWidget);
      expect(find.byType(SiyaqIconTile), findsOneWidget);
      expect(find.widgetWithText(SiyaqButton, 'View my rank'), findsOneWidget);
      expect(find.widgetWithText(SiyaqButton, 'Return home'), findsOneWidget);
      // Confetti finishes.
      await t.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('practice variant hides the leaderboard action', (t) async {
      await t.pumpWidget(
        await _app(lang: 'en', child: result(showLeaderboard: false)),
      );
      await t.pump(const Duration(seconds: 1));

      expect(find.widgetWithText(SiyaqButton, 'View my rank'), findsNothing);
      expect(find.widgetWithText(SiyaqButton, 'Return home'), findsOneWidget);
      await t.pumpAndSettle(const Duration(seconds: 2));
    });

    testWidgets('reduced motion: no confetti, content settles instantly', (
      t,
    ) async {
      await t.pumpWidget(
        await _app(
          lang: 'en',
          child: MediaQuery(
            data: const MediaQueryData(disableAnimations: true),
            child: result(),
          ),
        ),
      );
      await t.pumpAndSettle();

      expect(find.text('مكتبة'), findsOneWidget);
      expect(
        find.descendant(
          of: find.byType(SiyagResultScreen),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
      expect(_takeError(), isNull);
    });

    testWidgets('survives 320px at 2.0x', (t) async {
      t.view.physicalSize = const Size(320, 1400);
      t.view.devicePixelRatio = 1.0;
      addTearDown(t.view.reset);
      await t.pumpWidget(
        await _app(lang: 'en', textScale: 2.0, child: result()),
      );
      await t.pumpAndSettle(const Duration(seconds: 6));
      expect(_takeError(), isNull);
    });
  });
}
