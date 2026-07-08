import 'package:context_game/core/network/api_error.dart';
import 'package:context_game/features/game/data/models/game_meta.dart';
import 'package:context_game/features/game/data/models/guess_result.dart';
import 'package:context_game/features/game/data/models/hint_result.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/data/models/reveal_result.dart';
import 'package:context_game/features/game/data/models/word_suggestions.dart';
import 'package:context_game/features/game/domain/repositories/game_repository.dart';

/// Scripted in-memory backend mirroring the real API's semantics:
/// canonical normalization (ال-prefix collapses), 400 on non-dictionary
/// input, secret guess, hints with parseable text, and suggestions.
class FakeGameRepository implements GameRepository {
  static const secretWord = 'برمجة';

  /// raw → (canonical, rank)
  static const Map<String, (String, int)> vocab = {
    'حاسوب': ('حاسوب', 2),
    'كود': ('كود', 4),
    'بيت': ('بيت', 50),
    'البيت': ('بيت', 50), // dialect/orthographic alias → same canonical
    'حرب': ('حرب', 152),
    'شجرة': ('شجرة', 1200),
  };

  int newGameCalls = 0;

  @override
  Future<ModesInfo> modes({required String lang}) async {
    if (lang == 'en') {
      return ModesInfo.fromJson(const {
        'lang': 'en',
        'dir': 'ltr',
        'languages': [
          {'id': 'ar', 'label': 'العربية', 'dir': 'rtl'},
          {'id': 'en', 'label': 'English', 'dir': 'ltr'},
        ],
        'groups': [
          {
            'id': 'en_general',
            'label': 'General',
            'categories': [
              {'id': 'en_general', 'label': 'General'},
              {'id': 'en_animals', 'label': 'Animals'},
            ],
          },
        ],
        'default': 'en_general',
        'difficulties': [
          {'id': 'easy', 'label': 'Easy'},
          {'id': 'medium', 'label': 'Medium'},
          {'id': 'hard', 'label': 'Hard'},
        ],
        'defaultDifficulty': 'medium',
      });
    }
    return ModesInfo.fromJson(const {
      'lang': 'ar',
      'dir': 'rtl',
      'languages': [
        {'id': 'ar', 'label': 'العربية', 'dir': 'rtl'},
        {'id': 'en', 'label': 'English', 'dir': 'ltr'},
      ],
      'groups': [
        {
          'id': 'general',
          'label': 'عام',
          'categories': [
            {'id': 'general', 'label': 'متنوّع'},
            {'id': 'animals', 'label': 'حيوانات'},
          ],
        },
        {
          'id': 'football',
          'label': 'كرة القدم',
          'categories': [
            {'id': 'football', 'label': 'كرة القدم'},
          ],
        },
      ],
      'default': 'general',
      'difficulties': [
        {'id': 'easy', 'label': 'سهل'},
        {'id': 'medium', 'label': 'متوسط'},
        {'id': 'hard', 'label': 'صعب'},
      ],
      'defaultDifficulty': 'medium',
    });
  }

  GameMeta _meta(String mode, String difficulty) => GameMeta.fromJson({
        'mode': mode,
        'label': mode == 'general' ? 'متنوّع' : mode,
        'lang': mode.startsWith('en_') ? 'en' : 'ar',
        'difficulty': difficulty,
        'gameId': 3,
        'poolSize': 40,
        'totalWords': 8000,
      });

  @override
  Future<GameMeta> newGame(
      {required String mode, required String difficulty}) async {
    newGameCalls++;
    return _meta(mode, difficulty);
  }

  @override
  Future<GameMeta> gameInfo(
          {required String mode,
          required String difficulty,
          required int gameId}) async =>
      _meta(mode, difficulty);

  @override
  Future<GuessResult> guess({
    required String word,
    required String mode,
    required String difficulty,
    required int gameId,
  }) async {
    if (word == secretWord) {
      return GuessResult.fromJson(const {
        'word': secretWord,
        'rank': 1,
        'totalWords': 8000,
        'isSecret': true,
        'inVocab': true,
      });
    }
    if (word == 'مبرمج') {
      // Root match win: server reveals the actual secret.
      return GuessResult.fromJson(const {
        'word': 'مبرمج',
        'rank': 1,
        'totalWords': 8000,
        'isSecret': true,
        'inVocab': true,
        'rootMatch': true,
        'secret': secretWord,
      });
    }
    final entry = vocab[word];
    if (entry == null) {
      throw const ApiException(ApiErrorType.badRequest,
          detail: 'يرجى إدخال كلمة عربية صحيحة واحدة.', statusCode: 400);
    }
    return GuessResult.fromJson({
      'word': entry.$1,
      'rank': entry.$2,
      'totalWords': 8000,
      'isSecret': false,
      'inVocab': true,
    });
  }

  @override
  Future<HintResult> hint({
    required String mode,
    required String difficulty,
    required int gameId,
    required int level,
  }) async =>
      HintResult.fromJson({
        'mode': mode,
        'gameId': gameId,
        'level': level,
        'maxLevel': 5,
        'text': 'كلمة قريبة من الكلمة السرية (ترتيبها 152): «حرب»',
      });

  @override
  Future<RevealResult> giveUp(
          {required String mode,
          required String difficulty,
          required int gameId}) async =>
      RevealResult.fromJson(const {'secret': secretWord});

  @override
  Future<WordSuggestions> suggest({
    required String query,
    required String lang,
    String? mode,
    int limit = 8,
  }) async =>
      WordSuggestions.fromJson(const {
        'total': 3,
        'limit': 6,
        'offset': 0,
        'items': [
          {'word': 'سيارة', 'idx': 10, 'modes': []},
          {'word': 'السيارة', 'idx': 11, 'modes': []},
          {'word': 'سيارات', 'idx': 12, 'modes': []},
        ],
      });
}
