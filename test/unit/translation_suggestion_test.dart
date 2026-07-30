import 'dart:async';

import 'package:context_game/features/game/domain/translation/translation_suggestion.dart';
import 'package:context_game/features/game/domain/translation/translation_suggestion_repository.dart';
import 'package:context_game/features/game/presentation/controllers/translation_suggestion_controller.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';

/// Focused coverage for the Arabic → English guess assistant.
///
/// Everything that makes a type-as-you-go network feature misbehave is exercised
/// here against a scriptable repository: debounce, stale replies, out-of-order
/// replies, caching, timeout and the gate.

/// A repository whose every call can be resolved by hand, so ordering is
/// deterministic rather than a race.
class _ScriptedRepository implements TranslationSuggestionRepository {
  final calls = <String>[];
  final _pending = <String, Completer<List<TranslationSuggestion>>>{};

  @override
  Future<List<TranslationSuggestion>> suggest({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? locale,
  }) {
    calls.add(text);
    return (_pending[text] = Completer<List<TranslationSuggestion>>()).future;
  }

  void complete(String text, List<String> words) => _pending[text]!.complete([
    for (final w in words) TranslationSuggestion(text: w),
  ]);

  void fail(String text) => _pending[text]!.completeError(StateError('boom'));

  bool isPending(String text) =>
      _pending[text] != null && !_pending[text]!.isCompleted;
}

TranslationSuggestionController _controller(
  TranslationSuggestionRepository repo, {
  GameplayLanguage language = GameplayLanguage.english,
  TranslationAnalytics? analytics,
  Duration debounce = const Duration(milliseconds: 300),
  Duration timeout = const Duration(milliseconds: 2500),
}) => TranslationSuggestionController(
  repository: repo,
  gameLanguage: language,
  analytics: analytics ?? const NoopTranslationAnalytics(),
  debounce: debounce,
  timeout: timeout,
);

void main() {
  group('gate', () {
    test('applies only to an English game with Arabic input', () {
      bool applies(GameplayLanguage lang, String text) =>
          TranslationGate.appliesTo(gameLanguage: lang, text: text);

      expect(applies(GameplayLanguage.english, 'كتاب'), isTrue);
      // Scenario C: an Arabic game must never sprout an English panel.
      expect(applies(GameplayLanguage.arabic, 'كتاب'), isFalse);
      // The player already typing English is not helped by translating.
      expect(applies(GameplayLanguage.english, 'book'), isFalse);
      expect(applies(GameplayLanguage.english, ''), isFalse);
      expect(applies(GameplayLanguage.english, '   '), isFalse);
      // Mixed script is mid-edit, not a finished Arabic word.
      expect(applies(GameplayLanguage.english, 'كتابbook'), isFalse);
      // Digits and punctuation are not a word.
      expect(applies(GameplayLanguage.english, '١٢٣'), isFalse);
    });

    test('refuses input longer than a short expression', () {
      expect(TranslationGate.isWithinLimits('كتاب'), isTrue);
      expect(TranslationGate.isWithinLimits('كتاب مدرسة كبير'), isTrue);
      expect(TranslationGate.isWithinLimits('كتاب مدرسة كبير جدا'), isFalse);
      expect(TranslationGate.isWithinLimits('ا' * 33), isFalse);
      expect(
        TranslationGate.appliesTo(
          gameLanguage: GameplayLanguage.english,
          text: 'ا' * 40,
        ),
        isFalse,
        reason: 'a pasted document must not become a translation request',
      );
    });

    test('normalizes orthographic variation to one key', () {
      // Diacritics, alef forms, ya/alef-maqsura and ta-marbuta all fold.
      expect(
        TranslationGate.normalize('أستاذ'),
        TranslationGate.normalize('استاذ'),
      );
      expect(
        TranslationGate.normalize('مدرسة'),
        TranslationGate.normalize('مدرسه'),
      );
      expect(
        TranslationGate.normalize('ذَهَب'),
        TranslationGate.normalize('ذهب'),
      );
      expect(TranslationGate.normalize('  كتاب  '), 'كتاب');
    });
  });

  group('suggestion refinement', () {
    test('drops empties and case-insensitive duplicates', () {
      final refined = TranslationGate.refine(const [
        TranslationSuggestion(text: 'gold'),
        TranslationSuggestion(text: 'Gold'),
        TranslationSuggestion(text: ''),
        TranslationSuggestion(text: 'went'),
      ]);
      expect(refined.map((s) => s.text), ['gold', 'went']);
    });

    test('orders by confidence only when the backend scored every entry', () {
      final scored = TranslationGate.refine(const [
        TranslationSuggestion(text: 'go', confidence: 0.71),
        TranslationSuggestion(text: 'gold', confidence: 0.94),
      ]);
      expect(scored.first.text, 'gold');

      // Partially scored: the server's own order wins, since it knows which
      // sense is most common.
      final partial = TranslationGate.refine(const [
        TranslationSuggestion(text: 'go'),
        TranslationSuggestion(text: 'gold', confidence: 0.94),
      ]);
      expect(partial.first.text, 'go');
    });
  });

  group('response parsing', () {
    test('accepts the full contract', () {
      final parsed = RemoteTranslationSuggestionRepository.parse({
        'source_text': 'ذهب',
        'suggestions': [
          {
            'text': 'gold',
            'sense': 'noun',
            'confidence': 0.94,
            'label': 'ذهب كمعدن',
          },
        ],
      });
      expect(parsed.single.text, 'gold');
      expect(parsed.single.sense, 'noun');
      expect(parsed.single.confidence, 0.94);
      expect(parsed.single.label, 'ذهب كمعدن');
    });

    test('accepts a bare list of strings — the documented minimum', () {
      final parsed = RemoteTranslationSuggestionRepository.parse({
        'suggestions': ['gold', 'went'],
      });
      expect(parsed.map((s) => s.text), ['gold', 'went']);
      expect(parsed.first.sense, isNull);
    });

    test('malformed payloads yield nothing rather than throwing', () {
      expect(RemoteTranslationSuggestionRepository.parse(const {}), isEmpty);
      expect(
        RemoteTranslationSuggestionRepository.parse({'suggestions': 'nope'}),
        isEmpty,
      );
    });
  });

  group('debounce', () {
    test('asks once after typing settles, not per keystroke', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);

        for (final partial in ['ك', 'كت', 'كتا', 'كتاب']) {
          c.onInputChanged(partial);
          async.elapse(const Duration(milliseconds: 80));
        }
        expect(repo.calls, isEmpty, reason: 'still typing');
        expect(c.state.phase, TranslationPhase.debouncing);
        expect(c.state.isVisible, isFalse, reason: 'no panel while debouncing');

        async.elapse(const Duration(milliseconds: 300));
        expect(repo.calls, ['كتاب']);
        expect(c.state.phase, TranslationPhase.loading);
      });
    });

    test('clearing the field cancels a pending request', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);
        c.onInputChanged('كتاب');
        c.onInputChanged('');
        async.elapse(const Duration(seconds: 1));
        expect(repo.calls, isEmpty);
        expect(c.state.phase, TranslationPhase.idle);
      });
    });
  });

  group('stale and out-of-order replies', () {
    test('a reply the player has typed past is ignored', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);

        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        c.onInputChanged('ذهب');
        async.elapse(const Duration(milliseconds: 300));
        expect(repo.calls, ['كتاب', 'ذهب']);

        // The first request answers last — Scenario D.
        repo.complete('ذهب', ['gold']);
        async.flushMicrotasks();
        repo.complete('كتاب', ['book']);
        async.flushMicrotasks();

        expect(c.state.suggestions.map((s) => s.text), ['gold']);
        expect(c.state.sourceText, 'ذهب');
      });
    });

    test('an out-of-order reply cannot overwrite a newer one', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);

        c.onInputChanged('شمس');
        async.elapse(const Duration(milliseconds: 300));
        c.onInputChanged('قمر');
        async.elapse(const Duration(milliseconds: 300));

        repo.complete('قمر', ['moon']);
        async.flushMicrotasks();
        expect(c.state.suggestions.single.text, 'moon');

        repo.complete('شمس', ['sun']);
        async.flushMicrotasks();
        expect(
          c.state.suggestions.single.text,
          'moon',
          reason: 'the older request must not win by arriving later',
        );
      });
    });
  });

  group('cache', () {
    test('a repeated word is served without a second request', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);

        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        repo.complete('كتاب', ['book']);
        async.flushMicrotasks();

        c.onInputChanged('');
        c.onInputChanged('كتاب');
        async.elapse(const Duration(seconds: 1));

        expect(repo.calls, hasLength(1));
        expect(c.state.phase, TranslationPhase.success);
        expect(c.state.suggestions.single.text, 'book');
      });
    });

    test('an orthographic variant hits the same cache entry', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);

        c.onInputChanged('مدرسة');
        async.elapse(const Duration(milliseconds: 300));
        repo.complete('مدرسة', ['school']);
        async.flushMicrotasks();

        c.onInputChanged('مدرسه');
        async.elapse(const Duration(seconds: 1));
        expect(repo.calls, hasLength(1));
        expect(c.state.suggestions.single.text, 'school');
      });
    });
  });

  group('failure never blocks play', () {
    test('an error surfaces as a retryable state', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);
        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        repo.fail('كتاب');
        async.flushMicrotasks();

        expect(c.state.phase, TranslationPhase.error);
        // Scenario E: the field is still the player's to type English into.
        expect(c.state.sourceText, 'كتاب');
      });
    });

    test('a slow backend times out instead of hanging', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo, timeout: const Duration(milliseconds: 500));
        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        expect(repo.isPending('كتاب'), isTrue);

        async.elapse(const Duration(seconds: 1));
        expect(c.state.phase, TranslationPhase.error);
      });
    });

    test('a known-but-untranslatable word is empty, not an error', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);
        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        repo.complete('كتاب', const []);
        async.flushMicrotasks();
        expect(c.state.phase, TranslationPhase.empty);
      });
    });
  });

  group('dismissal and selection', () {
    test('dismissing hides the panel until the input changes', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo);
        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        repo.complete('كتاب', ['book']);
        async.flushMicrotasks();

        c.dismiss();
        expect(c.state.phase, TranslationPhase.dismissed);
        expect(c.state.isVisible, isFalse);

        // Re-typing the same word stays dismissed; a different word re-arms.
        c.onInputChanged('كتاب');
        expect(c.state.phase, TranslationPhase.dismissed);

        c.onInputChanged('ذهب');
        async.elapse(const Duration(milliseconds: 300));
        expect(repo.calls, ['كتاب', 'ذهب']);
      });
    });

    test('selecting clears the panel and never auto-submits', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final analytics = RecordingTranslationAnalytics();
        final c = _controller(repo, analytics: analytics);
        c.onInputChanged('ذهب');
        async.elapse(const Duration(milliseconds: 300));
        repo.complete('ذهب', ['gold', 'went', 'go']);
        async.flushMicrotasks();

        c.select(c.state.suggestions[1]);
        expect(c.state.phase, TranslationPhase.idle);
        expect(c.state.isVisible, isFalse);
        // The controller reports the choice; submission is the player's.
        expect(analytics.names, contains('translation_suggestion_selected'));
        expect(analytics.events.last.$2['selected_index'], 1);
      });
    });
  });

  group('multiple senses', () {
    test('ambiguous words keep every sense, in confidence order', () async {
      const repo = DevTranslationSuggestionRepository();
      final result = await repo.suggest(
        text: 'ذهب',
        sourceLanguage: 'ar',
        targetLanguage: 'en',
      );
      expect(result.map((s) => s.text), ['gold', 'went', 'go']);
      expect(result.first.label, 'ذهب كمعدن');
      expect(result[1].sense, 'verb');
    });

    test('the panel collapses past six and can expand', () {
      final many = [
        for (var i = 0; i < 9; i++) TranslationSuggestion(text: 'w$i'),
      ];
      const base = TranslationSuggestionState();
      final collapsed = base.copyWith(
        phase: TranslationPhase.success,
        suggestions: many,
      );
      expect(collapsed.visible, hasLength(6));
      expect(collapsed.hasMore, isTrue);

      final expanded = collapsed.copyWith(expanded: true);
      expect(expanded.visible, hasLength(9));
      expect(expanded.hasMore, isFalse);
    });
  });

  group('analytics are privacy-safe', () {
    test('events carry shapes and timings, never the typed text', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final analytics = RecordingTranslationAnalytics();
        final c = _controller(repo, analytics: analytics);

        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        repo.complete('كتاب', ['book']);
        async.flushMicrotasks();

        expect(analytics.names, [
          'translation_suggestions_requested',
          'translation_suggestions_shown',
        ]);
        final payloads = analytics.events.map((e) => e.$2.toString()).join();
        expect(payloads, isNot(contains('كتاب')));
        expect(payloads, isNot(contains('book')));
        expect(analytics.events.last.$2.keys, contains('latency_ms'));
      });
    });

    test('a failure is reported with a reason, not the input', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final analytics = RecordingTranslationAnalytics();
        final c = _controller(repo, analytics: analytics);
        c.onInputChanged('كتاب');
        async.elapse(const Duration(milliseconds: 300));
        repo.fail('كتاب');
        async.flushMicrotasks();

        expect(analytics.names.last, 'translation_suggestions_failed');
        expect(analytics.events.last.$2['reason'], 'request_failed');
      });
    });
  });

  group('Arabic game is untouched', () {
    test('no request is ever made, whatever is typed', () {
      fakeAsync((async) {
        final repo = _ScriptedRepository();
        final c = _controller(repo, language: GameplayLanguage.arabic);
        for (final text in ['كتاب', 'book', 'ذهب']) {
          c.onInputChanged(text);
          async.elapse(const Duration(seconds: 1));
        }
        expect(repo.calls, isEmpty);
        expect(c.state.isVisible, isFalse);
      });
    });
  });
}
