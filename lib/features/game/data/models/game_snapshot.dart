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
    this.releaseId,
    this.activeReleaseId,
    this.releaseChanged = false,
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

  /// The word-data release this game is **pinned** to, exactly as the server
  /// spells it — an opaque identifier, never parsed.
  ///
  /// The backend resolves Arabic by locale and composes Iraq from `ar-MSA` +
  /// `ar-IQ`, but exposes the result as one id. Formats already vary in
  /// production (`siyak-ar-iq-corpus-v3-candidate` alongside
  /// `siyak-en-2026-07-26-v001`), so any structure read out of this string
  /// would be a client-side assumption the contract does not make.
  final String? releaseId;

  /// The release a **new** game would use right now. Differs from [releaseId]
  /// after an activation or rollback while this game keeps its original data.
  final String? activeReleaseId;

  /// Server's own statement that the active release moved on since this game
  /// was created. Taken verbatim — never recomputed by comparing the two ids.
  final bool releaseChanged;

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
    releaseId: j['release_id']?.toString(),
    activeReleaseId: j['active_release_id']?.toString(),
    releaseChanged: j['release_changed'] == true,
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
