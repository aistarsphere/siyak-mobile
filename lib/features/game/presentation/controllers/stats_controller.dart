import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'app_settings_controller.dart';

/// Local, on-device gameplay stats shown in the Home mini-bento and the
/// stats screen (the backend keeps no per-player state).
class LocalStats {
  const LocalStats({
    this.totalAttempts = 0,
    this.bestRank = 0, // 0 = none yet
    this.gamesPlayed = 0,
    this.gamesSolved = 0,
  });

  final int totalAttempts;
  final int bestRank;
  final int gamesPlayed;
  final int gamesSolved;

  LocalStats copyWith({
    int? totalAttempts,
    int? bestRank,
    int? gamesPlayed,
    int? gamesSolved,
  }) =>
      LocalStats(
        totalAttempts: totalAttempts ?? this.totalAttempts,
        bestRank: bestRank ?? this.bestRank,
        gamesPlayed: gamesPlayed ?? this.gamesPlayed,
        gamesSolved: gamesSolved ?? this.gamesSolved,
      );
}

class StatsController extends Notifier<LocalStats> {
  static const _kAttempts = 'siyaq.stats.attempts';
  static const _kBest = 'siyaq.stats.best';
  static const _kPlayed = 'siyaq.stats.played';
  static const _kSolved = 'siyaq.stats.solved';

  @override
  LocalStats build() {
    final sp = ref.watch(sharedPreferencesProvider);
    return LocalStats(
      totalAttempts: sp.getInt(_kAttempts) ?? 0,
      bestRank: sp.getInt(_kBest) ?? 0,
      gamesPlayed: sp.getInt(_kPlayed) ?? 0,
      gamesSolved: sp.getInt(_kSolved) ?? 0,
    );
  }

  void _persist() {
    final sp = ref.read(sharedPreferencesProvider);
    sp.setInt(_kAttempts, state.totalAttempts);
    sp.setInt(_kBest, state.bestRank);
    sp.setInt(_kPlayed, state.gamesPlayed);
    sp.setInt(_kSolved, state.gamesSolved);
  }

  void recordAttempt(int rank) {
    final best = state.bestRank == 0 ? rank : (rank < state.bestRank ? rank : state.bestRank);
    state = state.copyWith(
      totalAttempts: state.totalAttempts + 1,
      bestRank: best,
    );
    _persist();
  }

  void recordGameStarted() {
    state = state.copyWith(gamesPlayed: state.gamesPlayed + 1);
    _persist();
  }

  void recordSolved() {
    state = state.copyWith(gamesSolved: state.gamesSolved + 1, bestRank: 1);
    _persist();
  }
}

final statsProvider =
    NotifierProvider<StatsController, LocalStats>(StatsController.new);
