/// A single hint from `POST /api/context-game/hint` (or an entry in a game's
/// `hints[]`). The backend gives structured fields — no text parsing needed.
/// {hint_number, difficulty, revealed_word, semantic_rank, similarity_score,
///  family_key}
class HintResult {
  const HintResult({
    required this.number,
    required this.word,
    required this.rank,
    this.difficulty,
    this.similarity,
    this.hintsUsed,
    this.hintsRemaining,
    this.maxHints,
  });

  final int number; // hint_number (1-based)
  final String word; // revealed_word — a semantic neighbor of the secret
  final int rank; // semantic_rank
  final String? difficulty;
  final double? similarity;

  final int? hintsUsed;
  final int? hintsRemaining;
  final int? maxHints;

  factory HintResult.fromJson(Map<String, dynamic> j) => HintResult(
        number: (j['hint_number'] as num?)?.toInt() ?? 0,
        word: j['revealed_word'] as String? ?? '',
        rank: (j['semantic_rank'] as num?)?.toInt() ?? 0,
        difficulty: j['difficulty'] as String?,
        similarity: (j['similarity_score'] as num?)?.toDouble(),
        hintsUsed: (j['hints_used'] as num?)?.toInt(),
        hintsRemaining: (j['hints_remaining'] as num?)?.toInt(),
        maxHints: (j['max_hints'] as num?)?.toInt(),
      );

  /// Parse an entry from a game's `hints[]` array.
  factory HintResult.fromEntry(Map<String, dynamic> j) => HintResult(
        number: (j['hint_number'] as num?)?.toInt() ?? 0,
        word: j['revealed_word'] as String? ?? '',
        rank: (j['semantic_rank'] as num?)?.toInt() ?? 0,
        difficulty: j['difficulty'] as String?,
        similarity: (j['similarity_score'] as num?)?.toDouble(),
      );
}
