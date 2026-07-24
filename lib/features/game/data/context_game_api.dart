import '../../../core/network/api_client.dart';
import 'models/game_snapshot.dart';
import 'models/guess_response.dart';
import 'models/hint_result.dart';
import 'models/languages_info.dart';
import 'models/modes_info.dart';
import 'models/word_suggestions.dart';

/// Endpoint bindings for the "Arabic English Context Game" backend.
/// The client's base URL already includes `/api/context-game`, so every
/// route here is relative to it.
class ContextGameApi {
  ContextGameApi(this._client);

  final ApiClient _client;

  Future<Map<String, dynamic>> health() => _client.getJson('/health');

  Future<Map<String, dynamic>> status() => _client.getJson('/status');

  Future<LanguagesInfo> languages() async =>
      LanguagesInfo.fromJson(await _client.getJson('/languages'));

  Future<ModesInfo> modes(String language) async => ModesInfo.fromJson(
    await _client.getJson('/modes', query: {'language': language}),
  );

  Future<GameSnapshot> newGame({
    required String language,
    required String category,
    String? mode,
  }) async => GameSnapshot.fromJson(
    await _client.postJson(
      '/new-game',
      body: {'language': language, 'category': category, 'mode': ?mode},
    ),
  );

  Future<GameSnapshot> game(String gameId) async =>
      GameSnapshot.fromJson(await _client.getJson('/game/$gameId'));

  Future<GuessResponse> guess({
    required String gameId,
    required String guess,
  }) async => GuessResponse.fromJson(
    await _client.postJson('/guess', body: {'game_id': gameId, 'guess': guess}),
  );

  Future<HintResult> hint({required String gameId, String? difficulty}) async =>
      HintResult.fromJson(
        await _client.postJson(
          '/hint',
          body: {'game_id': gameId, 'difficulty': ?difficulty},
        ),
      );

  Future<WordSuggestions> suggest({
    required String language,
    required String q,
    String? category,
    int limit = 8,
  }) async => WordSuggestions.fromJson(
    await _client.getJson(
      '/suggest',
      query: {
        'language': language,
        'q': q,
        'limit': limit,
        'category': ?category,
      },
    ),
  );
}
