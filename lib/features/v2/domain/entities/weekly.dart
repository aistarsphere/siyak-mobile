import '../../../game/domain/entities/guess.dart';
import 'gameplay_language.dart';

enum WeeklyState { active, completed, notStarted }

/// Overview of the current weekly challenge (no secret is ever exposed here).
class WeeklyChallenge {
  const WeeklyChallenge({
    required this.weekId,
    required this.language,
    required this.category,
    required this.categoryLabelAr,
    required this.categoryLabelEn,
    required this.state,
    this.timeRemaining,
    this.participated = false,
    this.placement,
    this.totalWords = 0,
  });

  final String weekId;
  final GameplayLanguage language;
  final String category;
  final String categoryLabelAr;
  final String categoryLabelEn;
  final WeeklyState state;
  final Duration? timeRemaining;
  final bool participated;
  final int? placement;
  final int totalWords;

  String categoryLabel(bool arabic) =>
      arabic ? categoryLabelAr : categoryLabelEn;
}

/// The player's personal run against a weekly challenge.
class WeeklyRun {
  const WeeklyRun({
    required this.runId,
    required this.weekId,
    required this.language,
    required this.category,
    required this.totalWords,
    required this.guesses,
    required this.solved,
    this.attempts = 0,
    this.hintsUsed = 0,
    this.hintsRemaining = 5,
    this.maxHints = 5,
    this.bestUserGeneratedRank,
    this.secretWord,
    this.elapsed,
    this.placement,
  });

  final String runId;
  final String weekId;
  final GameplayLanguage language;
  final String category;
  final int totalWords;

  /// Only the player's own accepted guesses — never system hints.
  final List<Guess> guesses;
  final bool solved;
  final int attempts;
  final int hintsUsed;
  final int hintsRemaining;
  final int maxHints;

  /// The player's best rank reached by their OWN guesses (drives adaptive
  /// hints; distinct from any hint-revealed rank).
  final int? bestUserGeneratedRank;

  /// Non-null only once solved (server-revealed).
  final String? secretWord;
  final Duration? elapsed;
  final int? placement;

  bool get hintsExhausted => hintsRemaining <= 0;

  int get bestRank => guesses.isEmpty
      ? (bestUserGeneratedRank ?? 0)
      : guesses.map((g) => g.rank).reduce((a, b) => a < b ? a : b);

  List<Guess> get sortedGuesses =>
      [...guesses]..sort((a, b) => a.rank.compareTo(b.rank));

  Guess? get bestGuess {
    Guess? best;
    for (final g in guesses) {
      if (best == null || g.rank < best.rank) best = g;
    }
    return best;
  }
}
