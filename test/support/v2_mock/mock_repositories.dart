import 'package:context_game/features/game/domain/entities/guess.dart';
import 'package:context_game/features/v2/domain/entities/adaptive_hint.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/installation_profile.dart';
import 'package:context_game/features/v2/domain/entities/leaderboard.dart';
import 'package:context_game/features/v2/domain/entities/v2_capabilities.dart';
import 'package:context_game/features/v2/domain/entities/weekly.dart';
import 'package:context_game/features/v2/domain/errors/v2_error.dart';
import 'package:context_game/features/v2/domain/repositories/v2_repositories.dart';

import 'mock_fixtures.dart';

/// PLACEHOLDER capability repo. Configurable so tests can exercise both the
/// "V2 available" screens and the "unavailable → V1 fallback" path.
class MockCapabilitiesRepository implements CapabilitiesRepository {
  MockCapabilitiesRepository({this.capabilities = _defaultAvailable});

  static const _defaultAvailable = V2Capabilities(
    available: true,
    weeklyEnabled: true,
    multiplayerEnabled: true,
    adaptiveHintsEnabled: true,
    apiVersion: 'mock-2',
  );

  final V2Capabilities capabilities;

  @override
  Future<V2Capabilities> detect() async => capabilities;
}

class MockProfileRepository implements ProfileRepository {
  String? _name;

  @override
  Future<InstallationProfile> register({
    required String installationId,
    String? displayName,
  }) async {
    _name = displayName ?? _name;
    return _profile(installationId);
  }

  @override
  Future<InstallationProfile> updateDisplayName({
    required String installationId,
    required String displayName,
  }) async {
    _name = displayName;
    return _profile(installationId);
  }

  InstallationProfile _profile(String id) => InstallationProfile(
    installationId: id,
    // Fallback short code derived from the id (never shows the raw id).
    shortCode: 'لاعب-${id.replaceAll('-', '').substring(0, 4).toUpperCase()}',
    displayName: _name,
    gamesPlayed: 12,
    gamesSolved: 5,
    weeklyBestPlacement: 7,
  );
}

class MockWeeklyRepository implements WeeklyRepository {
  final Map<String, WeeklyRun> _runs = {};
  int _runSeq = 0;

  @override
  Future<WeeklyChallenge> current({required GameplayLanguage language}) async =>
      WeeklyChallenge(
        weekId: MockFixtures.weekId,
        language: language,
        category: 'technology',
        categoryLabelAr: 'التقنية',
        categoryLabelEn: 'Technology',
        state: WeeklyState.active,
        timeRemaining: const Duration(days: 3, hours: 4),
        participated: _runs.isNotEmpty,
        placement: _runs.isNotEmpty ? 7 : null,
        totalWords: 22548,
      );

  @override
  Future<WeeklyRun> startRun({
    required String weekId,
    required GameplayLanguage language,
    HintMode hintMode = HintMode.standard,
  }) async {
    final id = 'weekly-run-${++_runSeq}';
    final run = WeeklyRun(
      runId: id,
      weekId: weekId,
      language: language,
      category: 'technology',
      totalWords: 22548,
      guesses: const [],
      solved: false,
      hintsRemaining: 5,
      maxHints: 5,
    );
    _runs[id] = run;
    return run;
  }

  @override
  Future<WeeklyRun> resumeRun({required String runId}) async =>
      _runs[runId] ?? (throw const V2Exception(V2ErrorCode.weeklyExpired));

  @override
  Future<({WeeklyRun run, V2GuessOutcome outcome})> guess({
    required String runId,
    required String word,
  }) async {
    final run =
        _runs[runId] ?? (throw const V2Exception(V2ErrorCode.weeklyExpired));
    final secret = run.language.isArabic
        ? MockFixtures.secretWordAr
        : MockFixtures.secretWordEn;

    if (word == secret) {
      final solvedGuess = MockFixtures.scored(word, solved: true);
      final updated = _copy(
        run,
        guesses: [...run.guesses, solvedGuess],
        solved: true,
        secretWord: secret,
        bestRank: 1,
        elapsed: const Duration(minutes: 4, seconds: 12),
        placement: 3,
      );
      _runs[runId] = updated;
      return (
        run: updated,
        outcome: V2GuessOutcome(
          accepted: true,
          duplicate: false,
          unknown: false,
          canonicalWord: word,
          rank: 1,
          proximity: 100,
          heatLevel: 'boiling',
          solved: true,
          secretWord: secret,
        ),
      );
    }

    if (!MockFixtures.vocab.containsKey(word)) {
      return (
        run: run,
        outcome: const V2GuessOutcome(
          accepted: false,
          duplicate: false,
          unknown: true,
          suggestions: ['حاسوب', 'برنامج', 'كود'],
        ),
      );
    }

    // Canonical duplicate: same word already guessed → no new attempt.
    final canonical = word == 'ساعدني' ? 'ساعد' : word;
    final already = run.guesses.any((g) => g.word == canonical);
    if (already) {
      return (
        run: run,
        outcome: V2GuessOutcome(
          accepted: true,
          duplicate: true,
          unknown: false,
          canonicalWord: canonical,
          originalWord: word,
        ),
      );
    }

    final g = MockFixtures.scored(canonical);
    final newBest = run.bestUserGeneratedRank == null
        ? g.rank
        : (g.rank < run.bestUserGeneratedRank!
              ? g.rank
              : run.bestUserGeneratedRank!);
    final updated = _copy(run, guesses: [...run.guesses, g], bestRank: newBest);
    _runs[runId] = updated;
    return (
      run: updated,
      outcome: V2GuessOutcome(
        accepted: true,
        duplicate: false,
        unknown: false,
        canonicalWord: canonical,
        rank: g.rank,
        proximity: g.proximity,
        heatLevel: g.tier.name,
      ),
    );
  }

  @override
  Future<AdaptiveHint> hint({
    required String runId,
    required HintMode mode,
  }) async {
    final run =
        _runs[runId] ?? (throw const V2Exception(V2ErrorCode.weeklyExpired));
    if (run.hintsExhausted) {
      throw const V2Exception(V2ErrorCode.hintLimit);
    }
    // Adaptive hint anchored on the player's best rank; never ranks 1–3.
    final base = run.bestUserGeneratedRank ?? 200;
    final rank = base <= 6 ? 4 : (base ~/ 2).clamp(4, 999);
    final n = run.hintsUsed + 1;
    _runs[runId] = _copy(
      run,
      hintsUsed: n,
      hintsRemaining: run.hintsRemaining - 1,
    );
    return AdaptiveHint(
      number: n,
      word: mode == HintMode.adaptive ? 'خوارزمية' : 'شبكة',
      semanticRank: rank,
      hintsRemaining: run.hintsRemaining - 1,
      bestUserGeneratedRank: run.bestUserGeneratedRank,
    );
  }

  @override
  Future<LeaderboardPage> leaderboard({
    required String weekId,
    int page = 0,
    int pageSize = 20,
  }) async {
    final entries = List.generate(pageSize, (i) {
      final placement = page * pageSize + i + 1;
      return LeaderboardEntry(
        placement: placement,
        label: placement == 7 ? 'لاعب-AMB1' : 'لاعب-${1000 + placement}',
        solved: placement <= 40,
        attempts: 5 + (placement % 12),
        hintsUsed: placement % 3,
        elapsed: Duration(minutes: 3 + placement % 7, seconds: placement % 60),
        isCurrentProfile: placement == 7,
      );
    });
    return LeaderboardPage(
      entries: entries,
      page: page,
      hasMore: page < 2,
      currentPlacement: 7,
    );
  }

  WeeklyRun _copy(
    WeeklyRun r, {
    List<Guess>? guesses,
    bool? solved,
    String? secretWord,
    int? hintsUsed,
    int? hintsRemaining,
    int? bestRank,
    Duration? elapsed,
    int? placement,
  }) => WeeklyRun(
    runId: r.runId,
    weekId: r.weekId,
    language: r.language,
    category: r.category,
    totalWords: r.totalWords,
    guesses: guesses ?? r.guesses,
    solved: solved ?? r.solved,
    attempts: (guesses ?? r.guesses).length,
    hintsUsed: hintsUsed ?? r.hintsUsed,
    hintsRemaining: hintsRemaining ?? r.hintsRemaining,
    maxHints: r.maxHints,
    bestUserGeneratedRank: bestRank ?? r.bestUserGeneratedRank,
    secretWord: secretWord ?? r.secretWord,
    elapsed: elapsed ?? r.elapsed,
    placement: placement ?? r.placement,
  );
}
