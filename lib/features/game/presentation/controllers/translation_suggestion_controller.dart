/// Owns the suggestion lifecycle for one gameplay session.
///
/// The widget renders state; everything that can go wrong with a
/// type-as-you-go network feature lives here and is unit-testable: debounce,
/// stale-request cancellation, out-of-order protection, a session cache, a
/// timeout, and an input length cap.
library;

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/presentation/controllers/capabilities_controller.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../domain/translation/translation_suggestion.dart';
import '../../domain/translation/translation_suggestion_repository.dart';

/// Privacy-safe telemetry for the assistant.
///
/// Deliberately carries **no** typed text, no profile and no identifiers — only
/// shapes and timings. The app has no analytics pipeline today, so the default
/// sink discards everything; this exists so the events are emitted from one place
/// and can be asserted, rather than being invented later across the UI.
abstract class TranslationAnalytics {
  void requested({
    required String gameLanguage,
    required String sourceLanguage,
  });
  void shown({required int count, required int latencyMs});
  void selected({required int index, required int count});
  void failed({required String reason, required int latencyMs});
}

class NoopTranslationAnalytics implements TranslationAnalytics {
  const NoopTranslationAnalytics();
  @override
  void requested({
    required String gameLanguage,
    required String sourceLanguage,
  }) {}
  @override
  void shown({required int count, required int latencyMs}) {}
  @override
  void selected({required int index, required int count}) {}
  @override
  void failed({required String reason, required int latencyMs}) {}
}

/// Records events in memory. Used by tests and available for a debug overlay.
class RecordingTranslationAnalytics implements TranslationAnalytics {
  final events = <(String, Map<String, Object>)>[];

  @override
  void requested({
    required String gameLanguage,
    required String sourceLanguage,
  }) => events.add((
    'translation_suggestions_requested',
    {'game_language': gameLanguage, 'source_language': sourceLanguage},
  ));

  @override
  void shown({required int count, required int latencyMs}) => events.add((
    'translation_suggestions_shown',
    {'suggestion_count': count, 'latency_ms': latencyMs},
  ));

  @override
  void selected({required int index, required int count}) => events.add((
    'translation_suggestion_selected',
    {'selected_index': index, 'suggestion_count': count},
  ));

  @override
  void failed({required String reason, required int latencyMs}) => events.add((
    'translation_suggestions_failed',
    {'reason': reason, 'latency_ms': latencyMs},
  ));

  List<String> get names => [for (final e in events) e.$1];
}

/// Drives the panel.
class TranslationSuggestionController extends ChangeNotifier {
  TranslationSuggestionController({
    required this.repository,
    required this.gameLanguage,
    this.locale,
    this.analytics = const NoopTranslationAnalytics(),
    this.debounce = defaultDebounce,
    this.timeout = defaultTimeout,
  });

  /// Long enough that a typist is not chased by requests, short enough that a
  /// finished word answers promptly.
  static const defaultDebounce = Duration(milliseconds: 350);

  /// The panel is an aid, never a gate: if the network is slow, it gives up
  /// rather than hanging around.
  static const defaultTimeout = Duration(milliseconds: 2500);

  final TranslationSuggestionRepository repository;
  final GameplayLanguage gameLanguage;
  final String? locale;
  final TranslationAnalytics analytics;
  final Duration debounce;
  final Duration timeout;

  TranslationSuggestionState _state = TranslationSuggestionState.initial;
  TranslationSuggestionState get state => _state;

  Timer? _debounceTimer;

  /// Monotonic request id. A response whose id is not the latest is dropped,
  /// which is what stops an early slow reply overwriting a later fast one.
  int _issued = 0;
  int _settled = 0;

  /// Session cache keyed by normalised Arabic, so re-typing a word — or fixing a
  /// diacritic — costs nothing.
  final Map<String, List<TranslationSuggestion>> _cache = {};

  /// Normalised inputs the player has dismissed. Typing something new re-arms.
  final Set<String> _dismissed = {};

  int get cacheSize => _cache.length;

  /// Feed every change of the guess field here.
  void onInputChanged(String raw) {
    final text = raw.trim();
    final applies = TranslationGate.appliesTo(
      gameLanguage: gameLanguage,
      text: text,
    );

    if (!applies) {
      _debounceTimer?.cancel();
      // Bump the id so any in-flight reply for the old text is ignored.
      _issued++;
      _set(const TranslationSuggestionState());
      return;
    }

    final key = TranslationGate.normalize(text);
    if (_dismissed.contains(key)) {
      _debounceTimer?.cancel();
      _set(
        TranslationSuggestionState(
          phase: TranslationPhase.dismissed,
          sourceText: text,
        ),
      );
      return;
    }

    // A cache hit skips the debounce entirely — there is nothing to wait for.
    final cached = _cache[key];
    if (cached != null) {
      _debounceTimer?.cancel();
      _issued++;
      _set(
        TranslationSuggestionState(
          phase: cached.isEmpty
              ? TranslationPhase.empty
              : TranslationPhase.success,
          sourceText: text,
          suggestions: cached,
        ),
      );
      return;
    }

    _set(
      TranslationSuggestionState(
        phase: TranslationPhase.debouncing,
        sourceText: text,
      ),
    );

    _debounceTimer?.cancel();
    _debounceTimer = Timer(debounce, () => _fetch(text, key));
  }

  Future<void> _fetch(String text, String key) async {
    final id = ++_issued;
    final started = DateTime.now();
    _set(
      TranslationSuggestionState(
        phase: TranslationPhase.loading,
        sourceText: text,
      ),
    );
    analytics.requested(gameLanguage: 'en', sourceLanguage: 'ar');

    try {
      final result = await repository
          .suggest(
            text: text,
            sourceLanguage: 'ar',
            targetLanguage: 'en',
            locale: locale,
          )
          .timeout(timeout);

      // Two guards, not one: `id != _issued` drops a reply the player has already
      // typed past, and `id <= _settled` drops one that arrived out of order.
      if (id != _issued || id <= _settled) return;
      _settled = id;

      final refined = TranslationGate.refine(result);
      _cache[key] = refined;
      final latency = DateTime.now().difference(started).inMilliseconds;

      if (refined.isEmpty) {
        analytics.shown(count: 0, latencyMs: latency);
        _set(
          TranslationSuggestionState(
            phase: TranslationPhase.empty,
            sourceText: text,
          ),
        );
        return;
      }
      analytics.shown(count: refined.length, latencyMs: latency);
      _set(
        TranslationSuggestionState(
          phase: TranslationPhase.success,
          sourceText: text,
          suggestions: refined,
        ),
      );
    } on TimeoutException {
      if (id != _issued) return;
      _settled = id;
      analytics.failed(
        reason: 'timeout',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
      _set(
        TranslationSuggestionState(
          phase: TranslationPhase.error,
          sourceText: text,
        ),
      );
    } catch (_) {
      if (id != _issued) return;
      _settled = id;
      analytics.failed(
        reason: 'request_failed',
        latencyMs: DateTime.now().difference(started).inMilliseconds,
      );
      // A failure never blocks play — the field stays usable and the player can
      // simply type English.
      _set(
        TranslationSuggestionState(
          phase: TranslationPhase.error,
          sourceText: text,
        ),
      );
    }
  }

  /// Re-runs the last input after an error, bypassing the debounce.
  void retry() {
    final text = _state.sourceText.trim();
    if (text.isEmpty) return;
    _fetch(text, TranslationGate.normalize(text));
  }

  /// The player closed the panel for the current input.
  void dismiss() {
    final text = _state.sourceText.trim();
    if (text.isEmpty) return;
    _debounceTimer?.cancel();
    _dismissed.add(TranslationGate.normalize(text));
    _set(_state.copyWith(phase: TranslationPhase.dismissed));
  }

  void expand() => _set(_state.copyWith(expanded: true));

  /// The player chose [suggestion]. Reports it and clears the panel.
  ///
  /// Submitting is **not** done here: the caller places the English word into the
  /// guess field and the player submits normally. Nothing is auto-submitted.
  void select(TranslationSuggestion suggestion) {
    final index = _state.suggestions.indexOf(suggestion);
    analytics.selected(
      index: index < 0 ? 0 : index,
      count: _state.suggestions.length,
    );
    _debounceTimer?.cancel();
    _issued++;
    _set(const TranslationSuggestionState());
  }

  void _set(TranslationSuggestionState next) {
    if (identical(_state, next)) return;
    _state = next;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounceTimer?.cancel();
    super.dispose();
  }
}

/// The repository the app should use.
///
/// Release builds require the backend `translation_assistant` capability for the
/// gameplay language. No backend ships it today, so in release this is null and
/// the assistant does not exist. Debug builds fall back to the deterministic
/// fixture so the flow stays exercisable.
final translationSuggestionRepositoryProvider =
    Provider.family<TranslationSuggestionRepository?, GameplayLanguage>((
      ref,
      language,
    ) {
      final caps = ref.watch(capabilitiesProvider).value;
      if (caps?.translationAssistantFor(language.code) ?? false) {
        return RemoteTranslationSuggestionRepository(
          ref.watch(v2ApiClientProvider),
        );
      }
      if (kDebugMode) return const DevTranslationSuggestionRepository();
      return null;
    });
