import 'package:context_game/features/game/domain/entities/guess.dart';
import 'package:context_game/features/game/domain/entities/heat.dart';

/// Deterministic fixture data for the mock V2 layer. No randomness, no time
/// calls — safe for reproducible tests. TEST-ONLY (never shipped in the app).
class MockFixtures {
  MockFixtures._();

  /// A small scored vocabulary shared by weekly + room mocks:
  /// word → (rank, proximity 0–100, heat_level).
  static const vocab = <String, (int, double, String)>{
    'حاسوب': (2, 99.5, 'boiling'),
    'كود': (4, 96.0, 'hot'),
    'برنامج': (9, 88.0, 'hot'),
    'شبكة': (55, 62.0, 'warm'),
    'حرب': (152, 45.0, 'cold'),
    'بيت': (2170, 15.0, 'freezing'),
    'مدرسة': (3668, 9.0, 'freezing'),
    'house': (30, 70.0, 'warm'),
    'computer': (2, 99.0, 'boiling'),
  };

  static const secretWordAr = 'برمجة';
  static const secretWordEn = 'software';

  static const weekId = 'week-2026-28';
  static const roomJoinCode = 'AMBER7';

  static Guess scored(String word, {bool solved = false}) {
    final v = vocab[word] ?? (5000, 5.0, 'freezing');
    return Guess(
      word: word,
      rank: solved ? 1 : v.$1,
      proximity: solved ? 100 : v.$2,
      tier: Heat.fromLevel(solved ? 'boiling' : v.$3, solved ? 100 : v.$2),
      isSecret: solved,
    );
  }
}
