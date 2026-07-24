import '../../domain/entities/guess.dart';
import 'hint_result.dart';

/// Full game state returned by `POST /api/context-game/new-game` and
/// `GET /api/context-game/game/{game_id}`. The backend is authoritative:
/// it holds the ordered history, attempt count, best rank, hints, and the
/// secret word (which stays null until solved).
class GameSnapshot {
  const GameSnapshot({
    required this.gameId,
    required this.language,
    required this.dir,
    required this.category,
    required this.mode,
    required this.totalWords,
    required this.guessCount,
    required this.solved,
    required this.guesses,
    required this.hints,
    required this.hintsUsed,
    required this.hintsRemaining,
    required this.maxHints,
    this.bestRank,
    this.secretWord,
    this.model,
  });

  final String gameId;
  final String language; // 'ar' | 'en'
  final String dir; // 'rtl' | 'ltr'
  final String category;
  final String mode;
  final int totalWords;
  final int guessCount;
  final bool solved;
  final List<Guess> guesses;
  final List<HintResult> hints;
  final int hintsUsed;
  final int hintsRemaining;
  final int maxHints;
  final int? bestRank;

  /// Only non-null once solved.
  final String? secretWord;
  final String? model;

  factory GameSnapshot.fromJson(Map<String, dynamic> j) => GameSnapshot(
    gameId: j['game_id'] as String,
    language: j['language'] as String? ?? 'ar',
    dir: j['dir'] as String? ?? 'rtl',
    category: j['category'] as String? ?? 'general',
    mode: j['mode'] as String? ?? 'random',
    totalWords: (j['total_words'] as num?)?.toInt() ?? 0,
    guessCount: (j['guess_count'] as num?)?.toInt() ?? 0,
    solved: j['solved'] as bool? ?? false,
    bestRank: (j['best_rank'] as num?)?.toInt(),
    secretWord: j['secret_word'] as String?,
    model: j['model'] as String?,
    guesses: (j['previous_guesses'] as List<dynamic>? ?? const [])
        .map((e) => Guess.fromEntry(e as Map<String, dynamic>))
        .toList(),
    hints: (j['hints'] as List<dynamic>? ?? const [])
        .map((e) => HintResult.fromEntry(e as Map<String, dynamic>))
        .toList(),
    hintsUsed: (j['hints_used'] as num?)?.toInt() ?? 0,
    hintsRemaining: (j['hints_remaining'] as num?)?.toInt() ?? 5,
    maxHints: (j['max_hints'] as num?)?.toInt() ?? 5,
  );
}
