import 'heat.dart';

/// A single scored guess, as the UI consumes it. Built from either the top
/// level of a `/guess` response or an entry in `previous_guesses`.
class Guess {
  const Guess({
    required this.word,
    required this.rank,
    required this.proximity,
    required this.tier,
    required this.isSecret,
    this.originalWord,
    this.originalDiffers = false,
  });

  /// Canonical/matched word shown in the row.
  final String word;

  /// The word the player typed, when it normalized to a different canonical
  /// form (Iraqi dialect aliases, orthography variants…).
  final String? originalWord;
  final bool originalDiffers;

  final int rank;

  /// Server closeness 0–100 (higher = closer).
  final double proximity;
  final HeatTier tier;
  final bool isSecret;

  factory Guess.fromEntry(Map<String, dynamic> j) {
    final level = j['heat_level'] as String?;
    final prox = (j['proximity'] as num?)?.toDouble() ?? 0;
    final original = j['guess'] as String?;
    final word = (j['word'] ?? j['guess']) as String;
    return Guess(
      word: word,
      originalWord: original,
      originalDiffers: j['original_differs'] as bool? ?? false,
      rank: (j['rank'] as num?)?.toInt() ?? 0,
      proximity: prox,
      tier: Heat.fromLevel(level, prox),
      isSecret: j['solved'] as bool? ?? false,
    );
  }
}
