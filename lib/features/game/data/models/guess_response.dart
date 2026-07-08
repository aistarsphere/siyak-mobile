import '../../domain/entities/guess.dart';
import '../../domain/entities/heat.dart';
import 'hint_result.dart';
import 'word_suggestions.dart';

/// `POST /api/context-game/guess` response.
///
/// The backend fully resolves the guess: it normalizes the input, flags
/// duplicates (`duplicate`/`already_guessed` — attempts are NOT re-counted
/// server-side), rejects out-of-vocabulary words (`accepted:false,
/// reason:"not_in_vocabulary"`) with `suggestions`, scores accepted guesses
/// with a `heat_level`/`proximity`, and returns the authoritative
/// `previous_guesses` history plus solved/secret state.
class GuessResponse {
  const GuessResponse({
    required this.accepted,
    required this.duplicate,
    required this.alreadyGuessed,
    required this.solved,
    required this.totalWords,
    required this.guessNumber,
    required this.previousGuesses,
    required this.hints,
    this.reason,
    this.message,
    this.originalGuess,
    this.canonicalWord,
    this.rank,
    this.proximity,
    this.heatLevel,
    this.suggestions = const [],
    this.secretWord,
    this.hintsUsed,
    this.hintsRemaining,
    this.maxHints,
  });

  final bool accepted;
  final bool duplicate;
  final bool alreadyGuessed;
  final bool solved;
  final int totalWords;

  /// Authoritative attempt count after this guess (unchanged on duplicates).
  final int guessNumber;

  final String? reason; // e.g. 'duplicate_canonical_guess', 'not_in_vocabulary'
  final String? message;
  final String? originalGuess;
  final String? canonicalWord;
  final int? rank;
  final double? proximity;
  final String? heatLevel;

  /// Present when [accepted] is false and the word was unknown.
  final List<String> suggestions;

  final String? secretWord;
  final int? hintsUsed;
  final int? hintsRemaining;
  final int? maxHints;

  /// Full server-ordered history (each already scored).
  final List<Guess> previousGuesses;
  final List<HintResult> hints;

  bool get unknownWord => !accepted && reason == 'not_in_vocabulary';

  /// The just-scored guess as a domain [Guess] (null when not accepted).
  Guess? get guess {
    if (!accepted || rank == null) return null;
    final prox = proximity ?? 0;
    return Guess(
      word: (canonicalWord ?? originalGuess) ?? '',
      originalWord: originalGuess,
      originalDiffers:
          originalGuess != null && canonicalWord != null && originalGuess != canonicalWord,
      rank: rank!,
      proximity: prox,
      tier: Heat.fromLevel(heatLevel, prox),
      isSecret: solved,
    );
  }

  factory GuessResponse.fromJson(Map<String, dynamic> j) => GuessResponse(
        accepted: j['accepted'] as bool? ?? false,
        duplicate: j['duplicate'] as bool? ?? false,
        alreadyGuessed: j['already_guessed'] as bool? ?? false,
        solved: j['solved'] as bool? ?? false,
        totalWords: (j['total_words'] as num?)?.toInt() ?? 0,
        guessNumber: (j['guess_number'] as num?)?.toInt() ?? 0,
        reason: j['reason'] as String?,
        message: j['message'] as String?,
        originalGuess: j['original_guess'] as String?,
        canonicalWord: j['canonical_word'] as String? ?? j['matched_word'] as String?,
        rank: (j['rank'] as num?)?.toInt(),
        proximity: (j['proximity'] as num?)?.toDouble(),
        heatLevel: j['heat_level'] as String?,
        suggestions: WordSuggestions.parseList(j['suggestions']),
        secretWord: j['secret_word'] as String?,
        hintsUsed: (j['hints_used'] as num?)?.toInt(),
        hintsRemaining: (j['hints_remaining'] as num?)?.toInt(),
        maxHints: (j['max_hints'] as num?)?.toInt(),
        previousGuesses: (j['previous_guesses'] as List<dynamic>? ?? const [])
            .map((e) => Guess.fromEntry(e as Map<String, dynamic>))
            .toList(),
        hints: (j['hints'] as List<dynamic>? ?? const [])
            .map((e) => HintResult.fromEntry(e as Map<String, dynamic>))
            .toList(),
      );
}
