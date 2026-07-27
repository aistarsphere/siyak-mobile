import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_weekly_screen.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/weekly.dart';
import 'package:context_game/features/v2/presentation/controllers/weekly_controller.dart';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness for the Weekly Challenge screen.
///
/// Overrides only `weeklyChallengeProvider`; the widget tree, localization and
/// theme under test are the real ones.
WeeklyChallenge weeklyFixture({
  required GameplayLanguage lang,
  WeeklyState state = WeeklyState.active,
  Duration? timeRemaining = const Duration(days: 2, hours: 7, minutes: 41),
  bool participated = false,
  int? placement = 12,
}) => WeeklyChallenge(
  weekId: '2026-W30',
  language: lang,
  category: 'literature',
  categoryLabelAr: 'أدب',
  categoryLabelEn: 'Literature',
  state: state,
  timeRemaining: timeRemaining,
  participated: participated,
  placement: placement,
  totalWords: 22548,
);

/// Builds the Weekly screen inside a real MaterialApp.
///
/// Passing [error] renders the failure branch; [loading] holds the pending state.
Future<Widget> buildWeekly({
  required Brightness brightness,
  String lang = 'ar',
  WeeklyState state = WeeklyState.active,
  Duration? timeRemaining = const Duration(days: 2, hours: 7, minutes: 41),
  bool participated = false,
  int? placement = 12,
  Object? error,
  bool loading = false,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();

  // Inferred rather than annotated: the override type is not exported.
  overrideFor(GameplayLanguage l) {
    if (error != null) {
      // Throw *synchronously* in the create function: Riverpod converts it to
      // AsyncError on the first build. A rejected Future would need a real async
      // flush that `pump` does not provide, leaving the screen on its loading
      // branch.
      return weeklyChallengeProvider(l).overrideWith((ref) => throw error);
    }
    if (loading) {
      // Never completes — holds the loading branch for a deterministic shot.
      return weeklyChallengeProvider(
        l,
      ).overrideWith((ref) => Completer<WeeklyChallenge>().future);
    }
    return weeklyChallengeProvider(l).overrideWith(
      (ref) => weeklyFixture(
        lang: l,
        state: state,
        timeRemaining: timeRemaining,
        participated: participated,
        placement: placement,
      ),
    );
  }

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Both variants overridden so the override set is stable when a test loops
      // over languages.
      for (final l in GameplayLanguage.values) overrideFor(l),
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
          child: const SiyagWeeklyScreen(),
        ),
      ),
    ),
  );
}
