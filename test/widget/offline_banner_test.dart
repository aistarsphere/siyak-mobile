import 'package:context_game/core/network/api_error.dart';
import 'package:context_game/features/game/data/models/game_snapshot.dart';
import 'package:context_game/features/game/data/models/guess_response.dart';
import 'package:context_game/features/game/data/models/hint_result.dart';
import 'package:context_game/features/game/data/models/languages_info.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/data/models/word_suggestions.dart';
import 'package:context_game/features/game/domain/repositories/game_repository.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/game/presentation/screens/home_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// A repository that always fails as if the tunnel were offline.
class _OfflineRepository implements GameRepository {
  @override
  Future<ModesInfo> modes({required String language}) async =>
      throw const ApiException(ApiErrorType.server, statusCode: 502);

  @override
  Future<bool> health() async => throw const ApiException(ApiErrorType.network);

  @override
  dynamic noSuchMethod(Invocation invocation) =>
      throw const ApiException(ApiErrorType.network);

  @override
  Future<LanguagesInfo> languages() =>
      throw const ApiException(ApiErrorType.network);
  @override
  Future<GameSnapshot> newGame({
    required String language,
    required String category,
    String? mode,
  }) => throw const ApiException(ApiErrorType.network);
  @override
  Future<GameSnapshot> game({required String gameId}) =>
      throw const ApiException(ApiErrorType.network);
  @override
  Future<GuessResponse> guess({
    required String gameId,
    required String guess,
  }) => throw const ApiException(ApiErrorType.network);
  @override
  Future<HintResult> hint({required String gameId, String? difficulty}) =>
      throw const ApiException(ApiErrorType.network);
  @override
  Future<WordSuggestions> suggest({
    required String language,
    required String query,
    String? category,
    int limit = 8,
  }) => throw const ApiException(ApiErrorType.network);
}

void main() {
  testWidgets(
    'backend-offline shows friendly banner with Retry + Change Server',
    (tester) async {
      SharedPreferences.setMockInitialValues({'siyaq.lang': 'ar'});
      final prefs = await SharedPreferences.getInstance();
      final container = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gameRepositoryProvider.overrideWithValue(_OfflineRepository()),
        ],
      );
      addTearDown(container.dispose);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: const MaterialApp(
            locale: Locale('ar'),
            supportedLocales: [Locale('ar'), Locale('en')],
            localizationsDelegates: [
              GlobalMaterialLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
            ],
            home: Scaffold(body: HomeScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // Friendly Arabic offline copy — no raw technical error.
      expect(find.text('الخادم غير متصل حالياً'), findsOneWidget);
      expect(find.text('قد يكون رابط النفق المؤقت متوقفاً'), findsOneWidget);
      expect(find.text('إعادة المحاولة'), findsOneWidget);
      expect(find.text('تغيير رابط الخادم'), findsOneWidget);
      // No unhandled exception surfaced.
      expect(tester.takeException(), isNull);
    },
  );
}
