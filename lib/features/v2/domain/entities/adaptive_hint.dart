/// An adaptive hint result. Never a user attempt; its rank is never the
/// player's best rank. Ranks 1–3 are never surfaced as adaptive hints.
class AdaptiveHint {
  const AdaptiveHint({
    required this.number,
    required this.word,
    required this.semanticRank,
    required this.hintsRemaining,
    this.bestUserGeneratedRank,
  });

  final int number;
  final String word;
  final int semanticRank;
  final int hintsRemaining;
  final int? bestUserGeneratedRank;
}
