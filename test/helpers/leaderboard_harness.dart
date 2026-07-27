import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_leaderboard_screen.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/leaderboard.dart';
import 'package:context_game/features/v2/domain/entities/weekly.dart';
import 'package:context_game/features/v2/presentation/controllers/leaderboard_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/weekly_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Test harness for the Leaderboard screen.
///
/// Overrides the leaderboard and weekly-challenge providers only; the widget
/// tree, localization and theme under test are the real ones.
class FakeLeaderboardController extends LeaderboardController {
  FakeLeaderboardController(this._state);
  final LeaderboardState _state;

  @override
  LeaderboardState build() => _state;

  // The screen calls these on scroll / week change; they must be inert here so a
  // test renders a fixed state.
  @override
  Future<void> load(String weekId) async {}

  @override
  Future<void> loadMore() async {}
}

LeaderboardEntry _entry(
  int placement,
  String label, {
  bool solved = true,
  int attempts = 12,
  int seconds = 95,
  bool isSelf = false,
}) => LeaderboardEntry(
  placement: placement,
  label: label,
  solved: solved,
  attempts: attempts,
  hintsUsed: 1,
  elapsed: Duration(seconds: seconds),
  isCurrentProfile: isSelf,
);

/// Ten entries with a mix of names, including a long one and the player's own.
final kLeaderboardEntries = <LeaderboardEntry>[
  _entry(1, 'كاظم العكبي', attempts: 8, seconds: 62),
  _entry(2, 'Sara', attempts: 11, seconds: 88),
  _entry(3, 'مصطفى', attempts: 13, seconds: 104),
  _entry(4, 'Abdulrahman Al-Hashimi', attempts: 15, seconds: 130),
  _entry(5, 'نور', attempts: 16, seconds: 141),
  _entry(6, 'Yusuf', attempts: 18, seconds: 158, isSelf: true),
  _entry(7, 'ليلى', attempts: 19, seconds: 166),
  _entry(8, 'Omar', solved: false, attempts: 25, seconds: 240),
  _entry(9, 'زينب', attempts: 21, seconds: 190),
  _entry(10, 'Hassan', attempts: 22, seconds: 201),
];

WeeklyChallenge kSampleWeekly(GameplayLanguage lang) => WeeklyChallenge(
  weekId: '2026-W30',
  language: lang,
  category: 'general',
  categoryLabelAr: 'عام',
  categoryLabelEn: 'General',
  state: WeeklyState.active,
);

/// Builds the Leaderboard screen inside a real MaterialApp.
Future<Widget> buildLeaderboard({
  required Brightness brightness,
  String lang = 'ar',
  List<LeaderboardEntry> entries = const [],
  bool loading = false,
  int? currentPlacement,
  Object? error,
  double textScale = 1.0,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();

  return ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      leaderboardControllerProvider.overrideWith(
        () => FakeLeaderboardController(
          LeaderboardState(
            entries: entries,
            loading: loading,
            currentPlacement: currentPlacement,
            error: error,
          ),
        ),
      ),
      // Both language variants are overridden so the override *set* is identical
      // regardless of `lang`. Riverpod rejects a scope whose overrides change
      // between rebuilds of the same element, which happens when a test loops
      // over languages.
      for (final l in GameplayLanguage.values)
        weeklyChallengeProvider(l).overrideWith((ref) => kSampleWeekly(l)),
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
          child: const Scaffold(body: SiyagLeaderboardScreen()),
        ),
      ),
    ),
  );
}
