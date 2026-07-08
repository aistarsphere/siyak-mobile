import '../domain/repositories/game_repository.dart';
import 'context_game_api.dart';
import 'models/game_snapshot.dart';
import 'models/guess_response.dart';
import 'models/hint_result.dart';
import 'models/languages_info.dart';
import 'models/modes_info.dart';
import 'models/word_suggestions.dart';

class GameRepositoryImpl implements GameRepository {
  GameRepositoryImpl(this._api);

  final ContextGameApi _api;

  @override
  Future<LanguagesInfo> languages() => _api.languages();

  @override
  Future<ModesInfo> modes({required String language}) => _api.modes(language);

  @override
  Future<GameSnapshot> newGame({
    required String language,
    required String category,
    String? mode,
  }) =>
      _api.newGame(language: language, category: category, mode: mode);

  @override
  Future<GameSnapshot> game({required String gameId}) => _api.game(gameId);

  @override
  Future<GuessResponse> guess({
    required String gameId,
    required String guess,
  }) =>
      _api.guess(gameId: gameId, guess: guess);

  @override
  Future<HintResult> hint({required String gameId, String? difficulty}) =>
      _api.hint(gameId: gameId, difficulty: difficulty);

  @override
  Future<WordSuggestions> suggest({
    required String language,
    required String query,
    String? category,
    int limit = 8,
  }) =>
      _api.suggest(language: language, q: query, category: category, limit: limit);

  @override
  Future<bool> health() async {
    final res = await _api.health();
    return res['ok'] == true;
  }
}
