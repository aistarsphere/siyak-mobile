import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../domain/entities/adaptive_hint.dart';
import '../../domain/entities/gameplay_language.dart';
import '../../domain/entities/hint_mode.dart';
import '../../domain/entities/weekly.dart';
import 'v2_providers.dart';

/// Current weekly challenge overview for a chosen gameplay language.
final weeklyChallengeProvider =
    FutureProvider.family<WeeklyChallenge, GameplayLanguage>((ref, lang) {
      return ref.watch(weeklyRepositoryProvider).current(language: lang);
    });

class WeeklyRunState {
  const WeeklyRunState({
    this.run,
    this.hints = const [],
    this.submitting = false,
    this.hintLoading = false,
    this.error,
    this.unknownWord,
    this.unknownSuggestions = const [],
    this.duplicateCanonical,
    this.duplicateSeq = 0,
    this.lastGuessWord,
  });

  final WeeklyRun? run;
  final List<AdaptiveHint> hints;
  final bool submitting;
  final bool hintLoading;
  final Object? error;
  final String? unknownWord;
  final List<String> unknownSuggestions;
  final String? duplicateCanonical;
  final int duplicateSeq;
  final String? lastGuessWord;

  bool get hasRun => run != null;

  WeeklyRunState copyWith({
    WeeklyRun? run,
    List<AdaptiveHint>? hints,
    bool? submitting,
    bool? hintLoading,
    Object? error,
    String? unknownWord,
    List<String>? unknownSuggestions,
    String? duplicateCanonical,
    int? duplicateSeq,
    String? lastGuessWord,
    bool clearError = false,
    bool clearUnknown = false,
  }) => WeeklyRunState(
    run: run ?? this.run,
    hints: hints ?? this.hints,
    submitting: submitting ?? this.submitting,
    hintLoading: hintLoading ?? this.hintLoading,
    error: clearError ? null : (error ?? this.error),
    unknownWord: clearUnknown ? null : (unknownWord ?? this.unknownWord),
    unknownSuggestions: clearUnknown
        ? const []
        : (unknownSuggestions ?? this.unknownSuggestions),
    duplicateCanonical: duplicateCanonical ?? this.duplicateCanonical,
    duplicateSeq: duplicateSeq ?? this.duplicateSeq,
    lastGuessWord: lastGuessWord ?? this.lastGuessWord,
  );
}

/// Weekly gameplay controller. The backend is the source of truth: attempts
/// are taken from the returned run and NEVER incremented optimistically;
/// canonical duplicates add no attempt; adaptive hints are not attempts.
class WeeklyRunController extends Notifier<WeeklyRunState> {
  @override
  WeeklyRunState build() => const WeeklyRunState();

  bool _submitting = false;

  Future<void> start(
    GameplayLanguage language, {
    HintMode hintMode = HintMode.standard,
  }) async {
    state = const WeeklyRunState();
    final week = await ref
        .read(weeklyRepositoryProvider)
        .current(language: language);
    final run = await ref
        .read(weeklyRepositoryProvider)
        .startRun(weekId: week.weekId, language: language, hintMode: hintMode);
    state = WeeklyRunState(run: run);
  }

  Future<bool> resume(String runId) async {
    try {
      final run = await ref
          .read(weeklyRepositoryProvider)
          .resumeRun(runId: runId);
      state = WeeklyRunState(run: run);
      return true;
    } catch (e) {
      state = state.copyWith(error: e);
      return false;
    }
  }

  Future<void> submitGuess(String raw) async {
    final word = raw.trim();
    final run = state.run;
    if (word.isEmpty || run == null || _submitting || run.solved) return;
    _submitting = true;
    state = state.copyWith(
      submitting: true,
      clearError: true,
      clearUnknown: true,
    );
    try {
      final res = await ref
          .read(weeklyRepositoryProvider)
          .guess(runId: run.runId, word: word);
      final outcome = res.outcome;
      if (outcome.unknown) {
        state = state.copyWith(
          submitting: false,
          unknownWord: word,
          unknownSuggestions: outcome.suggestions,
        );
        return;
      }
      if (outcome.duplicate) {
        // Canonical duplicate — no attempt added.
        state = state.copyWith(
          submitting: false,
          run: res.run,
          duplicateCanonical: outcome.canonicalWord ?? word,
          duplicateSeq: state.duplicateSeq + 1,
        );
        return;
      }
      state = state.copyWith(
        submitting: false,
        run: res.run,
        lastGuessWord: outcome.canonicalWord ?? word,
      );
    } catch (e) {
      state = state.copyWith(submitting: false, error: e);
    } finally {
      _submitting = false;
    }
  }

  Future<void> requestHint(HintMode mode) async {
    final run = state.run;
    if (run == null || state.hintLoading || run.hintsExhausted || run.solved) {
      return;
    }
    state = state.copyWith(hintLoading: true, clearError: true);
    try {
      final hint = await ref
          .read(weeklyRepositoryProvider)
          .hint(runId: run.runId, mode: mode);
      // A hint updates hint counters but is NOT a user attempt and its rank is
      // NOT the user's best rank.
      final updated = WeeklyRun(
        runId: run.runId,
        weekId: run.weekId,
        language: run.language,
        category: run.category,
        totalWords: run.totalWords,
        guesses: run.guesses,
        solved: run.solved,
        attempts: run.attempts,
        hintsUsed: run.hintsUsed + 1,
        hintsRemaining: hint.hintsRemaining,
        maxHints: run.maxHints,
        bestUserGeneratedRank: run.bestUserGeneratedRank,
        secretWord: run.secretWord,
        elapsed: run.elapsed,
        placement: run.placement,
      );
      state = state.copyWith(
        hintLoading: false,
        hints: [...state.hints, hint],
        run: updated,
      );
    } catch (e) {
      state = state.copyWith(hintLoading: false, error: e);
    }
  }

  void clearDuplicate() {} // handled via seq listener in the UI
  void clearError() => state = state.copyWith(clearError: true);
  void dismissUnknown() => state = state.copyWith(clearUnknown: true);
}

final weeklyRunControllerProvider =
    NotifierProvider<WeeklyRunController, WeeklyRunState>(
      WeeklyRunController.new,
    );

/// Active weekly run id (persisted for resume); null when none.
final activeWeeklyRunIdProvider = StateProvider<String?>((ref) {
  return ref.watch(sharedPreferencesProvider).getString('siyaq.v2.weeklyRunId');
});
