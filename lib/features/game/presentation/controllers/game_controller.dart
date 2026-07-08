import 'dart:async';
import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/network/api_error.dart';
import '../../data/models/game_snapshot.dart';
import '../../data/models/hint_result.dart';
import '../../domain/entities/guess.dart';
import 'app_settings_controller.dart';
import 'providers.dart';
import 'stats_controller.dart';

/// "Did you mean" state after the server rejected an out-of-vocab word.
class UnknownWordState {
  const UnknownWordState({
    required this.word,
    this.message,
    this.suggestions = const [],
    this.loading = true,
  });

  final String word;
  final String? message;
  final List<String> suggestions;
  final bool loading;

  UnknownWordState copyWith({List<String>? suggestions, bool? loading}) =>
      UnknownWordState(
        word: word,
        message: message,
        suggestions: suggestions ?? this.suggestions,
        loading: loading ?? this.loading,
      );
}

/// Client game state, mirroring the backend's authoritative snapshot plus a
/// little transient UI state (duplicate/unknown notices, autocomplete).
class GameState {
  const GameState({
    this.gameId,
    this.language = 'ar',
    this.category = 'general',
    this.categoryLabel = '',
    this.difficulty = 'medium',
    this.totalWords = 0,
    this.guesses = const [],
    this.hints = const [],
    this.solved = false,
    this.secretWord,
    this.hintsUsed = 0,
    this.hintsRemaining = AppConfig.maxHints,
    this.maxHints = AppConfig.maxHints,
    this.lastGuessWord,
    this.submitting = false,
    this.hintLoading = false,
    this.error,
    this.duplicateWord,
    this.duplicateSeq = 0,
    this.unknown,
    this.autocomplete = const [],
  });

  final String? gameId;
  final String language;
  final String category;
  final String categoryLabel;
  final String difficulty;
  final int totalWords;

  /// Server-ordered history (each already scored).
  final List<Guess> guesses;
  final List<HintResult> hints;
  final bool solved;
  final String? secretWord;
  final int hintsUsed;
  final int hintsRemaining;
  final int maxHints;
  final String? lastGuessWord;

  final bool submitting;
  final bool hintLoading;
  final Object? error;

  /// Bumped on every duplicate event so the UI notifies even for repeats.
  final String? duplicateWord;
  final int duplicateSeq;
  final UnknownWordState? unknown;
  final List<String> autocomplete;

  bool get hasGame => gameId != null;
  int get attempts => guesses.length;
  bool get hintsExhausted => hintsRemaining <= 0;

  int get bestRank =>
      guesses.isEmpty ? 0 : guesses.map((g) => g.rank).reduce((a, b) => a < b ? a : b);

  Guess? get bestGuess {
    Guess? best;
    for (final g in guesses) {
      if (best == null || g.rank < best.rank) best = g;
    }
    return best;
  }

  List<Guess> get sortedGuesses =>
      [...guesses]..sort((a, b) => a.rank.compareTo(b.rank));

  GameState copyWith({
    String? gameId,
    String? language,
    String? category,
    String? categoryLabel,
    String? difficulty,
    int? totalWords,
    List<Guess>? guesses,
    List<HintResult>? hints,
    bool? solved,
    String? secretWord,
    int? hintsUsed,
    int? hintsRemaining,
    int? maxHints,
    String? lastGuessWord,
    bool? submitting,
    bool? hintLoading,
    Object? error,
    String? duplicateWord,
    int? duplicateSeq,
    UnknownWordState? unknown,
    List<String>? autocomplete,
    bool clearError = false,
    bool clearUnknown = false,
  }) =>
      GameState(
        gameId: gameId ?? this.gameId,
        language: language ?? this.language,
        category: category ?? this.category,
        categoryLabel: categoryLabel ?? this.categoryLabel,
        difficulty: difficulty ?? this.difficulty,
        totalWords: totalWords ?? this.totalWords,
        guesses: guesses ?? this.guesses,
        hints: hints ?? this.hints,
        solved: solved ?? this.solved,
        secretWord: secretWord ?? this.secretWord,
        hintsUsed: hintsUsed ?? this.hintsUsed,
        hintsRemaining: hintsRemaining ?? this.hintsRemaining,
        maxHints: maxHints ?? this.maxHints,
        lastGuessWord: lastGuessWord ?? this.lastGuessWord,
        submitting: submitting ?? this.submitting,
        hintLoading: hintLoading ?? this.hintLoading,
        error: clearError ? null : (error ?? this.error),
        duplicateWord: duplicateWord ?? this.duplicateWord,
        duplicateSeq: duplicateSeq ?? this.duplicateSeq,
        unknown: clearUnknown ? null : (unknown ?? this.unknown),
        autocomplete: autocomplete ?? this.autocomplete,
      );
}

class GameController extends Notifier<GameState> {
  static const _kCurrent = 'siyaq.currentGame';

  Timer? _debounce;
  int _autocompleteSeq = 0;

  @override
  GameState build() {
    ref.onDispose(() => _debounce?.cancel());
    return const GameState();
  }

  // ---- persistence (resume across restarts) --------------------------------

  void _persist() {
    final sp = ref.read(sharedPreferencesProvider);
    if (state.gameId == null) return;
    sp.setString(
      _kCurrent,
      jsonEncode({
        'gameId': state.gameId,
        'language': state.language,
        'category': state.category,
        'categoryLabel': state.categoryLabel,
        'difficulty': state.difficulty,
        'solved': state.solved,
      }),
    );
  }

  Map<String, dynamic>? _savedRaw() {
    final raw = ref.read(sharedPreferencesProvider).getString(_kCurrent);
    if (raw == null) return null;
    try {
      final d = jsonDecode(raw) as Map<String, dynamic>;
      if (d['solved'] == true) return null;
      return d;
    } catch (_) {
      return null;
    }
  }

  /// Category label of a resumable unsolved game, if any (Home "resume").
  String? savedCategoryLabel() => _savedRaw()?['categoryLabel'] as String?;

  bool get hasSavedGame => _savedRaw() != null;

  void _clearSaved() => ref.read(sharedPreferencesProvider).remove(_kCurrent);

  GameState _fromSnapshot(
    GameSnapshot s, {
    required String categoryLabel,
    required String difficulty,
  }) =>
      GameState(
        gameId: s.gameId,
        language: s.language,
        category: s.category,
        categoryLabel: categoryLabel,
        difficulty: difficulty,
        totalWords: s.totalWords,
        guesses: s.guesses,
        hints: s.hints,
        solved: s.solved,
        secretWord: s.secretWord,
        hintsUsed: s.hintsUsed,
        hintsRemaining: s.hintsRemaining,
        maxHints: s.maxHints,
      );

  // ---- game lifecycle -------------------------------------------------------

  Future<void> startNewGame({
    required String language,
    required String category,
    required String categoryLabel,
    required String difficulty,
  }) async {
    _debounce?.cancel();
    state = const GameState();
    final snap = await ref
        .read(gameRepositoryProvider)
        .newGame(language: language, category: category);
    state = _fromSnapshot(snap, categoryLabel: categoryLabel, difficulty: difficulty);
    ref.read(statsProvider.notifier).recordGameStarted();
    _persist();
  }

  /// Restore the saved game by re-fetching it from the server.
  Future<bool> resumeSavedGame() async {
    final saved = _savedRaw();
    if (saved == null) return false;
    final gameId = saved['gameId'] as String?;
    if (gameId == null) return false;
    try {
      final snap = await ref.read(gameRepositoryProvider).game(gameId: gameId);
      state = _fromSnapshot(
        snap,
        categoryLabel: saved['categoryLabel'] as String? ?? snap.category,
        difficulty: saved['difficulty'] as String? ?? 'medium',
      );
      return true;
    } on ApiException catch (e) {
      if (e.type == ApiErrorType.badRequest) {
        _clearSaved(); // game expired/unknown server-side
        return false;
      }
      rethrow;
    }
  }

  // ---- guessing -------------------------------------------------------------

  Future<void> submitGuess(String raw) async {
    final word = raw.trim();
    if (word.isEmpty || state.gameId == null || state.submitting || state.solved) {
      return;
    }
    state = state.copyWith(
      submitting: true,
      autocomplete: const [],
      clearError: true,
      clearUnknown: true,
    );
    _debounce?.cancel();
    try {
      final res = await ref
          .read(gameRepositoryProvider)
          .guess(gameId: state.gameId!, guess: word);

      // Unknown / not in vocabulary → "did you mean" card.
      if (res.unknownWord) {
        _haptic(HapticFeedback.vibrate);
        state = state.copyWith(
          submitting: false,
          unknown: UnknownWordState(
            word: word,
            message: res.message,
            suggestions: res.suggestions,
            loading: res.suggestions.isEmpty,
          ),
        );
        if (res.suggestions.isEmpty) {
          await _loadUnknownSuggestions(word);
        }
        return;
      }

      // Any other non-accepted result → surface the message.
      if (!res.accepted) {
        state = state.copyWith(
          submitting: false,
          error: ApiException(ApiErrorType.badRequest, detail: res.message),
        );
        return;
      }

      final wasDuplicate = res.duplicate || res.alreadyGuessed;

      if (res.solved) {
        _haptic(HapticFeedback.heavyImpact);
        ref.read(statsProvider.notifier).recordSolved();
      } else if (!wasDuplicate) {
        // Only count genuinely new guesses locally (server dedups too).
        ref.read(statsProvider.notifier).recordAttempt(res.rank ?? 0);
        _haptic((res.proximity ?? 0) >= 50
            ? HapticFeedback.mediumImpact
            : HapticFeedback.lightImpact);
      } else {
        _haptic(HapticFeedback.selectionClick);
      }

      state = state.copyWith(
        submitting: false,
        guesses: res.previousGuesses.isNotEmpty ? res.previousGuesses : state.guesses,
        hints: res.hints.isNotEmpty ? res.hints : state.hints,
        solved: res.solved,
        secretWord: res.secretWord,
        totalWords: res.totalWords != 0 ? res.totalWords : state.totalWords,
        hintsUsed: res.hintsUsed ?? state.hintsUsed,
        hintsRemaining: res.hintsRemaining ?? state.hintsRemaining,
        maxHints: res.maxHints ?? state.maxHints,
        lastGuessWord: res.canonicalWord ?? word,
        duplicateWord: wasDuplicate ? (res.canonicalWord ?? word) : null,
        duplicateSeq:
            wasDuplicate ? state.duplicateSeq + 1 : state.duplicateSeq,
      );
      _persist();
    } on ApiException catch (e) {
      _haptic(HapticFeedback.vibrate);
      state = state.copyWith(submitting: false, error: e);
    } catch (e) {
      state = state.copyWith(submitting: false, error: e);
    }
  }

  Future<void> _loadUnknownSuggestions(String word) async {
    try {
      final res = await ref.read(gameRepositoryProvider).suggest(
            query: suggestionQueryFor(word),
            language: state.language,
            limit: 6,
          );
      final u = state.unknown;
      if (u == null || u.word != word) return; // stale
      state = state.copyWith(
        unknown: u.copyWith(suggestions: res.words, loading: false),
      );
    } catch (_) {
      final u = state.unknown;
      if (u == null) return;
      state = state.copyWith(unknown: u.copyWith(loading: false));
    }
  }

  /// First whitespace token stripped to letters, so noisy input still yields
  /// useful dictionary matches.
  static String suggestionQueryFor(String word) {
    final first = word.trim().split(RegExp(r'\s+')).first;
    final cleaned = first.replaceAll(RegExp(r'[^\p{L}]', unicode: true), '');
    return cleaned.isNotEmpty ? cleaned : word.trim();
  }

  void dismissUnknown() => state = state.copyWith(clearUnknown: true);
  void clearError() => state = state.copyWith(clearError: true);

  // ---- hints ----------------------------------------------------------------

  Future<void> requestHint() async {
    if (state.gameId == null ||
        state.hintLoading ||
        state.hintsExhausted ||
        state.solved) {
      return;
    }
    state = state.copyWith(hintLoading: true, clearError: true);
    try {
      final hint = await ref.read(gameRepositoryProvider).hint(
            gameId: state.gameId!,
            difficulty: state.difficulty,
          );
      _haptic(HapticFeedback.lightImpact);
      state = state.copyWith(
        hintLoading: false,
        hints: [...state.hints, hint],
        hintsUsed: hint.hintsUsed ?? state.hintsUsed + 1,
        hintsRemaining: hint.hintsRemaining ?? (state.hintsRemaining - 1),
        maxHints: hint.maxHints ?? state.maxHints,
      );
      _persist();
    } catch (e) {
      state = state.copyWith(hintLoading: false, error: e);
    }
  }

  // ---- autocomplete ---------------------------------------------------------

  void onInputChanged(String text) {
    final q = text.trim();
    _debounce?.cancel();
    if (state.gameId == null || q.length < AppConfig.autocompleteMinChars) {
      if (state.autocomplete.isNotEmpty) {
        state = state.copyWith(autocomplete: const []);
      }
      return;
    }
    final seq = ++_autocompleteSeq;
    _debounce = Timer(AppConfig.autocompleteDebounce, () async {
      try {
        final res = await ref.read(gameRepositoryProvider).suggest(
              query: q,
              language: state.language,
              limit: 8,
            );
        if (seq != _autocompleteSeq) return; // stale
        state = state.copyWith(autocomplete: res.words);
      } catch (_) {
        // best-effort
      }
    });
  }

  void _haptic(Future<void> Function() fn) {
    if (ref.read(appSettingsProvider).haptics) fn();
  }
}

final gameControllerProvider =
    NotifierProvider<GameController, GameState>(GameController.new);
