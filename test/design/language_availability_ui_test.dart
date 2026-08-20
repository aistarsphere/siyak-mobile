import 'dart:async';

import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/core/network/api_error.dart';
import 'package:context_game/core/sound/sound_player_adapter.dart';
import 'package:context_game/core/sound/sound_service.dart';
import 'package:context_game/features/game/data/models/game_snapshot.dart';
import 'package:context_game/features/game/data/models/guess_response.dart';
import 'package:context_game/features/game/data/models/hint_result.dart';
import 'package:context_game/features/game/data/models/languages_info.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/data/models/word_suggestions.dart';
import 'package:context_game/features/game/domain/languages/language_availability.dart';
import 'package:context_game/features/game/domain/languages/language_availability_repository.dart';
import 'package:context_game/features/game/domain/repositories/game_repository.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/language_availability_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/siyag/presentation/screens/siyag_practice_setup_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Acceptance scenarios for the Language Availability Contract v1.
///
/// The scenarios that matter are the ones where the old screen went wrong: an
/// unavailable language taking the selector down with it, an explicit choice
/// being quietly overruled, and an empty category being reported as if the whole
/// language were broken.

const _cats = [
  CategoryInfo(
    code: 'general',
    label: 'General',
    labelAr: 'عام',
    wordCount: 20000,
    playable: true,
  ),
  CategoryInfo(
    code: 'animals',
    label: 'Animals',
    labelAr: 'الحيوانات',
    wordCount: 0,
    playable: false,
  ),
];

LanguageAvailability _ar({required bool available}) => LanguageAvailability(
  code: 'ar',
  displayName: 'العربية',
  supported: true,
  available: available,
  state: available
      ? LanguageAvailabilityState.activeManaged
      : LanguageAvailabilityState.noActiveRelease,
);

LanguageAvailability _en({required bool available}) => LanguageAvailability(
  code: 'en',
  displayName: 'English',
  supported: true,
  available: available,
  state: available
      ? LanguageAvailabilityState.activeManaged
      : LanguageAvailabilityState.noActiveRelease,
);

LanguageCatalogue _catalogue({
  bool ar = false,
  bool en = true,
  String? defaultLanguage = 'en',
}) => LanguageCatalogue(
  contractVersion: '1.0.0',
  defaultLanguage: defaultLanguage,
  languages: [
    _ar(available: ar),
    _en(available: en),
  ],
);

/// Serves catalogues on demand so a test can change availability mid-session.
class _FakeLanguageRepo implements LanguageAvailabilityRepository {
  _FakeLanguageRepo(this._catalogue);

  LanguageCatalogue _catalogue;
  LanguageCatalogue? cached;
  Object? error;
  int fetches = 0;

  set next(LanguageCatalogue c) => _catalogue = c;

  @override
  Future<LanguageCatalogue> fetch() async {
    fetches++;
    if (error != null) throw error!;
    return _catalogue;
  }

  @override
  LanguageCatalogue? readCached() => cached;

  @override
  Future<void> writeCache(LanguageCatalogue catalogue) async {
    cached = catalogue;
  }
}

/// Records what `newGame` was asked for, and can fail on demand.
class _FakeGameRepo implements GameRepository {
  final startedLanguages = <String>[];
  final startedCategories = <String>[];
  Object? failWith;
  Completer<void>? gate;

  @override
  Future<GameSnapshot> newGame({
    required String language,
    required String category,
    String? mode,
  }) async {
    startedLanguages.add(language);
    startedCategories.add(category);
    if (gate != null) await gate!.future;
    if (failWith != null) throw failWith!;
    return GameSnapshot(
      gameId: 'g1',
      language: language,
      dir: language == 'ar' ? 'rtl' : 'ltr',
      category: category,
      mode: 'random',
      totalWords: 301,
      guessCount: 0,
      solved: false,
      guesses: const [],
      hints: const [],
      hintsUsed: 0,
      hintsRemaining: 3,
      maxHints: 3,
    );
  }

  @override
  Future<ModesInfo> modes({required String language}) async =>
      ModesInfo(language: language, categories: _cats);

  @override
  noSuchMethod(Invocation invocation) =>
      throw UnimplementedError('${invocation.memberName}');

  @override
  Future<LanguagesInfo> languages() => throw UnimplementedError();
  @override
  Future<GameSnapshot> game({required String gameId}) =>
      throw UnimplementedError();
  @override
  Future<GuessResponse> guess({
    required String gameId,
    required String guess,
  }) => throw UnimplementedError();
  @override
  Future<HintResult> hint({required String gameId, String? difficulty}) =>
      throw UnimplementedError();
  @override
  Future<WordSuggestions> suggest({
    required String language,
    required String query,
    String? category,
    int limit = 8,
  }) => throw UnimplementedError();
  @override
  Future<bool> health() async => true;
}

/// Never answers until the test says so.
class _PendingLanguageRepo implements LanguageAvailabilityRepository {
  final completer = Completer<LanguageCatalogue>();

  @override
  Future<LanguageCatalogue> fetch() => completer.future;

  @override
  LanguageCatalogue? readCached() => null;

  @override
  Future<void> writeCache(LanguageCatalogue catalogue) async {}
}

class _Harness {
  _Harness(this.languageRepo, this.gameRepo, this.widget);

  final _FakeLanguageRepo languageRepo;
  final _FakeGameRepo gameRepo;
  final Widget widget;
}

Future<_Harness> _host({
  LanguageCatalogue? catalogue,
  String uiLang = 'ar',
  Map<String, Object> prefs = const {},
  Map<String, List<CategoryInfo>>? perLanguage,
}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': uiLang, ...prefs});
  final sp = await SharedPreferences.getInstance();
  final languageRepo = _FakeLanguageRepo(catalogue ?? _catalogue());
  final gameRepo = _FakeGameRepo();

  final widget = ProviderScope(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sp),
      soundPlayerAdapterProvider.overrideWithValue(const SilentSoundAdapter()),
      languageAvailabilityRepositoryProvider.overrideWithValue(languageRepo),
      gameRepositoryProvider.overrideWithValue(gameRepo),
      modesByLanguageProvider.overrideWith(
        (ref, language) => ModesInfo(
          language: language,
          categories: perLanguage?[language] ?? _cats,
        ),
      ),
    ],
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.of(
        Brightness.dark,
        script: SiyaqTypography.scriptForLocale(uiLang),
      ),
      locale: Locale(uiLang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SiyagPracticeSetupScreen(),
    ),
  );
  return _Harness(languageRepo, gameRepo, widget);
}

SiyaqButton _button(WidgetTester t, String label) =>
    t.widget<SiyaqButton>(find.widgetWithText(SiyaqButton, label).first);

void main() {
  group('Scenario A — Arabic unavailable, English available', () {
    testWidgets('both languages stay visible and Arabic keeps its own state', (
      t,
    ) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'ar',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      // Both options rendered, each in its own language.
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);

      // Arabic's own message, not a global one.
      expect(
        find.text('لا توجد حاليًا نسخة كلمات فعالة للغة العربية.'),
        findsOneWidget,
      );
      expect(find.text('لا توجد لغة لعب متاحة حاليًا.'), findsNothing);
    });

    testWidgets('English is reachable and plays', (t) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'ar',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      await t.tap(find.text('اختيار English'));
      await t.pumpAndSettle();

      expect(find.byType(SiyaqSelectTile), findsOneWidget);
      expect(_button(t, 'ابدأ اللعب').onPressed, isNotNull);
    });
  });

  group('Scenario B — an explicit choice is never overruled', () {
    testWidgets('Arabic stays selected and Play is disabled with a reason', (
      t,
    ) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'ar',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      final control = t.widget<SiyaqSegmentedControl<String>>(
        find.byType(SiyaqSegmentedControl<String>).first,
      );
      expect(
        control.value,
        'ar',
        reason: 'the app must not switch away from an explicit choice',
      );
      expect(_button(t, 'ابدأ اللعب').onPressed, isNull);
      // Disabled with a stated reason, not silently.
      expect(find.textContaining('اللعب غير متاح'), findsOneWidget);
      expect(h.gameRepo.startedLanguages, isEmpty);
    });

    testWidgets('with no explicit choice, an available language is picked', (
      t,
    ) async {
      // UI language is Arabic and Arabic is unavailable — the old code took
      // that as the game language and dead-ended.
      final h = await _host();
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      final control = t.widget<SiyaqSegmentedControl<String>>(
        find.byType(SiyaqSegmentedControl<String>).first,
      );
      expect(control.value, 'en');
      expect(_button(t, 'ابدأ اللعب').onPressed, isNotNull);
    });
  });

  group('Scenario C — an empty category is not an unavailable language', () {
    testWidgets('shows the category message and keeps the language available', (
      t,
    ) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'en',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      h.gameRepo.failWith = const ApiException(
        ApiErrorType.server,
        statusCode: 409,
        body: {
          'code': 'NO_PLAYABLE_SECRETS_FOR_CATEGORY',
          'language': 'en',
          'category': 'general',
          'retryable': false,
          'available_categories': ['other'],
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      await t.tap(find.widgetWithText(SiyaqButton, 'ابدأ اللعب'));
      await t.pumpAndSettle();

      expect(
        find.text('لا توجد كلمات متاحة لهذا التصنيف حاليًا.'),
        findsOneWidget,
      );
      // Emphatically *not* the language story.
      expect(find.textContaining('نسخة كلمات فعالة'), findsNothing);
      expect(find.text('English'), findsOneWidget);

      // And there is a way forward.
      await t.tap(find.text('اختر تصنيفًا آخر'));
      await t.pumpAndSettle();
      expect(find.byType(SiyaqSelectTile), findsOneWidget);
    });
  });

  group('Scenario D — availability changes after startup', () {
    testWidgets('retry picks up the new state and the selection holds', (
      t,
    ) async {
      final h = await _host(
        catalogue: _catalogue(ar: false),
        prefs: const {
          'siyaq.gameLanguage': 'ar',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();
      expect(find.textContaining('نسخة كلمات فعالة'), findsOneWidget);

      // Arabic comes back on the server.
      h.languageRepo.next = _catalogue(ar: true);
      await t.tap(find.widgetWithText(SiyaqButton, 'إعادة المحاولة'));
      await t.pumpAndSettle();

      expect(h.languageRepo.fetches, greaterThan(1));
      final control = t.widget<SiyaqSegmentedControl<String>>(
        find.byType(SiyaqSegmentedControl<String>).first,
      );
      expect(control.value, 'ar', reason: 'refresh must not move the choice');
      expect(_button(t, 'ابدأ اللعب').onPressed, isNotNull);
    });

    testWidgets('a NO_ACTIVE_RELEASE on start re-reads availability', (
      t,
    ) async {
      final h = await _host(
        catalogue: _catalogue(ar: true),
        prefs: const {
          'siyaq.gameLanguage': 'ar',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      h.gameRepo.failWith = const ApiException(
        ApiErrorType.server,
        statusCode: 503,
        body: {
          'code': 'NO_ACTIVE_RELEASE',
          'language': 'ar',
          'retryable': true,
          'available_languages': ['en'],
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();
      final before = h.languageRepo.fetches;

      // The catalogue still claims Arabic works; the server disagrees.
      h.languageRepo.next = _catalogue(ar: false);
      await t.tap(find.widgetWithText(SiyaqButton, 'ابدأ اللعب'));
      await t.pumpAndSettle();

      expect(
        h.languageRepo.fetches,
        greaterThan(before),
        reason: 'stale availability must be re-read, not trusted',
      );
      expect(find.textContaining('نسخة كلمات فعالة'), findsOneWidget);
    });
  });

  group('both languages unavailable', () {
    testWidgets('states it globally and still shows both options', (t) async {
      final h = await _host(catalogue: _catalogue(ar: false, en: false));
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      expect(find.text('لا توجد لغة لعب متاحة حاليًا.'), findsOneWidget);
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      expect(_button(t, 'ابدأ اللعب').onPressed, isNull);
    });
  });

  group('Play never fails silently', () {
    testWidgets('submits the explicit language, never an inferred one', (
      t,
    ) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'en',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      await t.tap(find.widgetWithText(SiyaqButton, 'ابدأ اللعب'));
      await t.pumpAndSettle();

      expect(h.gameRepo.startedLanguages, ['en']);
      expect(h.gameRepo.startedCategories, ['general']);
    });

    testWidgets('a second tap while starting does not start twice', (t) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'en',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      h.gameRepo.gate = Completer<void>();
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      final play = find.widgetWithText(SiyaqButton, 'ابدأ اللعب');
      await t.tap(play);
      await t.pump();
      // Visibly busy, and refusing further taps.
      expect(_button(t, 'ابدأ اللعب').loading, isTrue);
      expect(_button(t, 'ابدأ اللعب').onPressed, isNull);

      await t.tap(play, warnIfMissed: false);
      await t.pump();
      expect(h.gameRepo.startedLanguages, ['en']);

      h.gameRepo.gate!.complete();
      await t.pumpAndSettle();
    });

    testWidgets('an untyped failure surfaces instead of vanishing', (t) async {
      final h = await _host(
        prefs: const {
          'siyaq.gameLanguage': 'en',
          'siyaq.gameLanguage.explicit': true,
        },
      );
      h.gameRepo.failWith = const ApiException(ApiErrorType.network);
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      await t.tap(find.widgetWithText(SiyaqButton, 'ابدأ اللعب'));
      await t.pumpAndSettle();

      expect(t.takeException(), isNull);
      expect(find.byType(SiyaqTintedSurface), findsWidgets);
      // The button recovers rather than staying stuck.
      expect(_button(t, 'ابدأ اللعب').loading, isFalse);
      expect(_button(t, 'ابدأ اللعب').onPressed, isNotNull);
    });
  });

  group('resilience', () {
    testWidgets('a cached catalogue keeps the selector usable when the '
        'network fails', (t) async {
      final h = await _host();
      h.languageRepo.cached = _catalogue();
      h.languageRepo.error = const ApiException(ApiErrorType.network);
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('English'), findsOneWidget);
      // Cache is a fallback, not an override of a fresh answer.
      expect(find.text('لا توجد لغة لعب متاحة حاليًا.'), findsNothing);
    });

    testWidgets('no cache and no network is a network error, not "no '
        'languages"', (t) async {
      final h = await _host();
      h.languageRepo.error = const ApiException(ApiErrorType.network);
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      expect(find.text('إعادة المحاولة'), findsWidgets);
      expect(find.text('لا توجد لغة لعب متاحة حاليًا.'), findsNothing);
    });
  });

  group('category catalogue', () {
    testWidgets(
      'a category-load failure offers a retry rather than a dead end',
      (t) async {
        SharedPreferences.setMockInitialValues({
          'siyaq.lang': 'ar',
          'siyaq.gameLanguage': 'en',
          'siyaq.gameLanguage.explicit': true,
        });
        final sp = await SharedPreferences.getInstance();
        final languageRepo = _FakeLanguageRepo(_catalogue());

        await t.pumpWidget(
          ProviderScope(
            overrides: [
              sharedPreferencesProvider.overrideWithValue(sp),
              soundPlayerAdapterProvider.overrideWithValue(
                const SilentSoundAdapter(),
              ),
              languageAvailabilityRepositoryProvider.overrideWithValue(
                languageRepo,
              ),
              gameRepositoryProvider.overrideWithValue(_FakeGameRepo()),
              modesByLanguageProvider.overrideWith(
                (ref, language) => throw Exception('offline'),
              ),
            ],
            child: const MaterialApp(
              locale: Locale('ar'),
              supportedLocales: [Locale('ar'), Locale('en')],
              localizationsDelegates: [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              home: SiyagPracticeSetupScreen(),
            ),
          ),
        );
        await t.pumpAndSettle();

        expect(find.byType(SiyaqEmptyState), findsOneWidget);
        expect(find.text('إعادة المحاولة'), findsWidgets);
        // The language selector survives a category failure.
        expect(find.text('العربية'), findsOneWidget);
        expect(find.text('English'), findsOneWidget);
      },
    );

    testWidgets('holds a loader while the catalogue is still pending', (
      t,
    ) async {
      SharedPreferences.setMockInitialValues({'siyaq.lang': 'ar'});
      final sp = await SharedPreferences.getInstance();
      final pending = _PendingLanguageRepo();

      await t.pumpWidget(
        ProviderScope(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(sp),
            soundPlayerAdapterProvider.overrideWithValue(
              const SilentSoundAdapter(),
            ),
            languageAvailabilityRepositoryProvider.overrideWithValue(pending),
            gameRepositoryProvider.overrideWithValue(_FakeGameRepo()),
          ],
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: [Locale('ar'), Locale('en')],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: SiyagPracticeSetupScreen(),
          ),
        ),
      );
      await t.pump();

      expect(find.byType(SiyaqLoader), findsOneWidget);
      expect(find.byType(SiyaqEmptyState), findsNothing);

      pending.completer.complete(_catalogue());
      await t.pumpAndSettle();
    });
  });

  group('direction', () {
    testWidgets('renders LTR in an English UI without losing either option', (
      t,
    ) async {
      final h = await _host(uiLang: 'en');
      await t.pumpWidget(h.widget);
      await t.pumpAndSettle();

      expect(
        Directionality.of(t.element(find.text('English').first)),
        TextDirection.ltr,
      );
      expect(find.text('العربية'), findsOneWidget);
      expect(find.text('Start game'), findsOneWidget);
    });
  });
}
