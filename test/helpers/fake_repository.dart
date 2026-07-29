import 'package:context_game/features/game/data/models/game_snapshot.dart';
import 'package:context_game/features/game/data/models/guess_response.dart';
import 'package:context_game/features/game/data/models/hint_result.dart';
import 'package:context_game/features/game/data/models/languages_info.dart';
import 'package:context_game/features/game/data/models/modes_info.dart';
import 'package:context_game/features/game/data/models/word_suggestions.dart';
import 'package:context_game/core/network/api_error.dart';
import 'package:context_game/features/game/domain/repositories/game_repository.dart';

/// Scripted in-memory backend mirroring the real `/api/context-game` schema:
/// server-authoritative history, duplicate flagging (attempts unchanged),
/// out-of-vocabulary rejection with suggestions, structured hints, and a
/// secret-word reveal on solve.
class FakeGameRepository implements GameRepository {
  static const secretWord = 'برمجة';

  /// word → (rank, proximity, heat_level)
  static const Map<String, (int, double, String)> vocab = {
    'حاسوب': (2, 99.5, 'boiling'),
    'كود': (4, 96.0, 'hot'),
    'بيت': (18607, 17.5, 'freezing'),
    'البيت': (18607, 17.5, 'freezing'), // alias → same canonical 'بيت'
    'حرب': (152, 60.0, 'warm'),
  };

  int newGameCalls = 0;

  /// Composed release the fake "activates" — mirrors the live Arabic shape
  /// `ar-MSA + ar-IQ`. Tests reassign this to simulate an activation/rollback.
  String activeReleaseId =
      'siyak-ar-msa-corpus-v3-candidate+siyak-ar-iq-corpus-v3-candidate';

  /// Release each created game was pinned to, by game id.
  final Map<String, String> pinnedRelease = {};

  /// When true, `game()` answers like the live 404 `GAME_NOT_FOUND`.
  bool gameNotFound = false;
  final Map<String, List<Map<String, dynamic>>> _history = {};
  final Map<String, List<Map<String, dynamic>>> _hints = {};

  @override
  Future<bool> health() async => true;

  @override
  Future<LanguagesInfo> languages() async => LanguagesInfo.fromJson(const {
    'languages': [
      {
        'code': 'ar',
        'name': 'Arabic',
        'native_name': 'العربية',
        'dir': 'rtl',
        'ready': true,
      },
      {
        'code': 'en',
        'name': 'English',
        'native_name': 'English',
        'dir': 'ltr',
        'ready': true,
      },
    ],
  });

  @override
  Future<ModesInfo> modes({required String language}) async {
    if (language == 'en') {
      return ModesInfo.fromJson(const {
        'language': 'en',
        'modes': [
          {
            'code': 'general',
            'label': 'General',
            'label_ar': 'عام',
            'word_count': 100,
            'playable': true,
          },
          {
            'code': 'animals',
            'label': 'Animals',
            'label_ar': 'الحيوانات',
            'word_count': 50,
            'playable': true,
          },
        ],
      });
    }
    return ModesInfo.fromJson(const {
      'language': 'ar',
      'modes': [
        {
          'code': 'general',
          'label': 'General',
          'label_ar': 'عام',
          'word_count': 22433,
          'playable': true,
        },
        {
          'code': 'animals',
          'label': 'Animals',
          'label_ar': 'الحيوانات',
          'word_count': 159,
          'playable': true,
        },
        {
          'code': 'sports',
          'label': 'Sports',
          'label_ar': 'الرياضة',
          'word_count': 2155,
          'playable': true,
        },
      ],
    });
  }

  Map<String, dynamic> _entry(
    int attempt,
    String word,
    int rank,
    double prox,
    String level, {
    bool solved = false,
  }) => {
    'attempt': attempt,
    'guess': word,
    'word': word,
    'original_differs': false,
    'rank': rank,
    'proximity': prox,
    'heat_level': level,
    'solved': solved,
  };

  @override
  Future<GameSnapshot> newGame({
    required String language,
    required String category,
    String? mode,
  }) async {
    newGameCalls++;
    final id = 'game-$newGameCalls';
    _history[id] = [];
    _hints[id] = [];
    // A game is pinned to whatever is active at creation time.
    pinnedRelease[id] = activeReleaseId;
    return GameSnapshot.fromJson({
      'game_id': id,
      'release_id': activeReleaseId,
      'active_release_id': activeReleaseId,
      'release_changed': false,
      'language': language,
      'dir': language == 'ar' ? 'rtl' : 'ltr',
      'category': category,
      'mode': mode ?? 'random',
      'total_words': 22548,
      'guess_count': 0,
      'solved': false,
      'best_rank': null,
      'secret_word': null,
      'previous_guesses': [],
      'hints_used': 0,
      'hints_remaining': 5,
      'max_hints': 5,
      'hints': [],
    });
  }

  @override
  Future<GameSnapshot> game({required String gameId}) async {
    if (gameNotFound) {
      // Exactly how the live API answers for an expired game, or one whose
      // release was withdrawn: 404 GAME_NOT_FOUND, which the client maps to
      // ApiErrorType.server (400/422 are the only badRequest codes).
      throw const ApiException(
        ApiErrorType.server,
        detail: 'game_not_found',
        statusCode: 404,
      );
    }
    final hist = _history[gameId] ?? [];
    final pinned = pinnedRelease[gameId] ?? activeReleaseId;
    return GameSnapshot.fromJson({
      'game_id': gameId,
      'release_id': pinned,
      'active_release_id': activeReleaseId,
      'release_changed': pinned != activeReleaseId,
      'language': 'ar',
      'dir': 'rtl',
      'category': 'general',
      'mode': 'random',
      'total_words': 22548,
      'guess_count': hist.length,
      'solved': hist.any((g) => g['solved'] == true),
      'best_rank': hist.isEmpty
          ? null
          : hist.map((g) => g['rank'] as int).reduce((a, b) => a < b ? a : b),
      'secret_word': null,
      'previous_guesses': hist,
      'hints_used': (_hints[gameId] ?? []).length,
      'hints_remaining': 5 - (_hints[gameId] ?? []).length,
      'max_hints': 5,
      'hints': _hints[gameId] ?? [],
    });
  }

  @override
  Future<GuessResponse> guess({
    required String gameId,
    required String guess,
  }) async {
    final hist = _history[gameId]!;
    if (guess == secretWord) {
      hist.add(
        _entry(hist.length + 1, secretWord, 1, 100, 'boiling', solved: true),
      );
      return GuessResponse.fromJson({
        'accepted': true,
        'duplicate': false,
        'already_guessed': false,
        'solved': true,
        'total_words': 22548,
        'guess_number': hist.length,
        'canonical_word': secretWord,
        'original_guess': secretWord,
        'rank': 1,
        'proximity': 100,
        'heat_level': 'boiling',
        'secret_word': secretWord,
        'previous_guesses': hist,
        'hints': _hints[gameId] ?? [],
      });
    }
    final v = vocab[guess];
    if (v == null) {
      return GuessResponse.fromJson({
        'accepted': false,
        'duplicate': false,
        'already_guessed': false,
        'reason': 'not_in_vocabulary',
        'message': 'That word is not in the game\'s dictionary.',
        'original_guess': guess,
        'solved': false,
        'total_words': 22548,
        'guess_number': hist.length,
        'suggestions': [
          {'word': 'سيارة'},
          {'word': 'السيارة'},
          {'word': 'سيارات'},
        ],
        'previous_guesses': hist,
        'hints': _hints[gameId] ?? [],
      });
    }
    final canonical = guess == 'البيت' ? 'بيت' : guess;
    final already = hist.any((g) => g['word'] == canonical);
    if (!already) {
      hist.add(_entry(hist.length + 1, canonical, v.$1, v.$2, v.$3));
    }
    return GuessResponse.fromJson({
      'accepted': true,
      'duplicate': already,
      'already_guessed': already,
      'reason': already ? 'duplicate_canonical_guess' : null,
      'solved': false,
      'total_words': 22548,
      'guess_number': hist.length,
      'canonical_word': canonical,
      'original_guess': guess,
      'rank': v.$1,
      'proximity': v.$2,
      'heat_level': v.$3,
      'previous_guesses': hist,
      'hints': _hints[gameId] ?? [],
    });
  }

  @override
  Future<HintResult> hint({required String gameId, String? difficulty}) async {
    final hints = _hints[gameId]!;
    final n = hints.length + 1;
    hints.add({
      'hint_number': n,
      'difficulty': difficulty ?? 'medium',
      'revealed_word': 'حرب',
      'semantic_rank': 152,
      'similarity_score': 0.64,
    });
    return HintResult.fromJson({
      'ok': true,
      'game_id': gameId,
      'hint_number': n,
      'difficulty': difficulty ?? 'medium',
      'revealed_word': 'حرب',
      'semantic_rank': 152,
      'similarity_score': 0.64,
      'hints_used': n,
      'hints_remaining': 5 - n,
      'max_hints': 5,
    });
  }

  @override
  Future<WordSuggestions> suggest({
    required String language,
    required String query,
    String? category,
    int limit = 8,
  }) async => WordSuggestions.fromJson(const {
    'language': 'ar',
    'query': 'سيا',
    'suggestions': [
      {'word': 'سيارة'},
      {'word': 'سياج'},
      {'word': 'سياق'},
    ],
  });
}
