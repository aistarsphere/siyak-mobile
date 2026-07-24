import '../../data/models/game_snapshot.dart';
import '../../data/models/guess_response.dart';
import '../../data/models/hint_result.dart';
import '../../data/models/languages_info.dart';
import '../../data/models/modes_info.dart';
import '../../data/models/word_suggestions.dart';

abstract class GameRepository {
  Future<LanguagesInfo> languages();

  Future<ModesInfo> modes({required String language});

  Future<GameSnapshot> newGame({
    required String language,
    required String category,
    String? mode,
  });

  Future<GameSnapshot> game({required String gameId});

  Future<GuessResponse> guess({required String gameId, required String guess});

  Future<HintResult> hint({required String gameId, String? difficulty});

  Future<WordSuggestions> suggest({
    required String language,
    required String query,
    String? category,
    int limit,
  });

  /// Backend health check (used by the splash screen).
  Future<bool> health();
}
