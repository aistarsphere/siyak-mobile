/// Repository boundary for Arabic → English guess suggestions.
///
/// **No provider credentials live in the app.** Translation is a backend-mediated
/// call over the existing authenticated client, so the key stays server-side and
/// the request can be rate-limited where rate limiting belongs.
library;

import '../../../v2/data/remote/v2_api_client.dart';
import 'translation_suggestion.dart';

/// Fetches candidate English words for an Arabic source.
abstract class TranslationSuggestionRepository {
  /// Throws on failure — the controller decides what a failure means for the UI.
  /// Returning an empty list means "asked, and there is no translation", which is
  /// a different outcome and rendered differently.
  Future<List<TranslationSuggestion>> suggest({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? locale,
  });
}

/// Live implementation against the documented contract.
///
/// ⚠️ **The endpoint does not exist yet.** Probed on 2026-07-31: this API answers
/// POST to an unknown route with `405 Method Not Allowed` (a known-good route
/// returns 200, and GET to an unknown route returns 404), and every candidate
/// path answered 405. `GET /capabilities` agrees —
/// `capabilities_contract.unimplemented.translation_assistant` reads "no
/// translation service is wired into gameplay".
///
/// This class is written to the contract so that shipping the backend is the only
/// remaining step; until then the capability flag keeps it unreachable in
/// release, and debug builds use [DevTranslationSuggestionRepository].
class RemoteTranslationSuggestionRepository
    implements TranslationSuggestionRepository {
  RemoteTranslationSuggestionRepository(this._client);

  /// The single path this feature may call.
  static const path = '/gameplay/translation-suggestions';

  final V2ApiClient _client;

  @override
  Future<List<TranslationSuggestion>> suggest({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? locale,
  }) async {
    final json = await _client.post(
      path,
      body: <String, dynamic>{
        'source_language': sourceLanguage,
        'target_language': targetLanguage,
        'text': text,
        'context': <String, dynamic>{
          'game_language': targetLanguage,
          'locale': ?locale,
        },
      },
    );
    return parse(json);
  }

  /// Decodes a response tolerantly.
  ///
  /// The contract's optional fields are genuinely optional: a backend that
  /// returns nothing but `{"suggestions": ["gold"]}` is supported, because the
  /// minimum this feature needs is a list of English strings.
  static List<TranslationSuggestion> parse(Map<String, dynamic> json) {
    final raw = json['suggestions'];
    if (raw is! List) return const [];
    return TranslationGate.refine([
      for (final entry in raw)
        if (entry is Map<String, dynamic>)
          TranslationSuggestion.fromJson(entry)
        else if (entry is Map)
          TranslationSuggestion.fromJson(
            entry.map((k, v) => MapEntry(k.toString(), v)),
          )
        else if (entry != null)
          // A bare string is a valid, minimal suggestion.
          TranslationSuggestion(text: entry.toString().trim()),
    ]);
  }
}

/// Deterministic stand-in for development and tests.
///
/// **Not a shippable translator, and not reachable in release.** It exists so the
/// whole interaction — detect, debounce, request, choose, submit — can be built
/// and QA'd before the backend endpoint lands. The entries carry real senses so
/// the ambiguity handling is exercised rather than assumed.
class DevTranslationSuggestionRepository
    implements TranslationSuggestionRepository {
  const DevTranslationSuggestionRepository({this.delay = Duration.zero});

  /// Lets a test or a demo simulate latency.
  final Duration delay;

  static const _fixtures = <String, List<TranslationSuggestion>>{
    'ذهب': [
      TranslationSuggestion(
        text: 'gold',
        sense: 'noun',
        confidence: 0.94,
        label: 'ذهب كمعدن',
      ),
      TranslationSuggestion(
        text: 'went',
        sense: 'verb',
        confidence: 0.82,
        label: 'فعل ماضٍ',
      ),
      TranslationSuggestion(
        text: 'go',
        sense: 'verb',
        confidence: 0.71,
        label: 'الصيغة الأساسية',
      ),
    ],
    'كتاب': [
      TranslationSuggestion(text: 'book', sense: 'noun', confidence: 0.96),
      TranslationSuggestion(text: 'volume', sense: 'noun', confidence: 0.63),
      TranslationSuggestion(
        text: 'publication',
        sense: 'noun',
        confidence: 0.55,
      ),
    ],
    'عين': [
      TranslationSuggestion(
        text: 'eye',
        sense: 'noun',
        confidence: 0.93,
        label: 'العضو',
      ),
      TranslationSuggestion(
        text: 'spring',
        sense: 'noun',
        confidence: 0.74,
        label: 'نبع ماء',
      ),
      TranslationSuggestion(
        text: 'appointed',
        sense: 'verb',
        confidence: 0.51,
        label: 'فعل ماضٍ',
      ),
    ],
    'مدرسه': [
      TranslationSuggestion(text: 'school', sense: 'noun', confidence: 0.97),
    ],
    'شمس': [
      TranslationSuggestion(text: 'sun', sense: 'noun', confidence: 0.98),
    ],
    'قمر': [
      TranslationSuggestion(text: 'moon', sense: 'noun', confidence: 0.97),
    ],
    'ماء': [
      TranslationSuggestion(text: 'water', sense: 'noun', confidence: 0.98),
    ],
    'بيت': [
      TranslationSuggestion(text: 'house', sense: 'noun', confidence: 0.9),
      TranslationSuggestion(text: 'home', sense: 'noun', confidence: 0.84),
      TranslationSuggestion(
        text: 'verse',
        sense: 'noun',
        confidence: 0.4,
        label: 'بيت شِعر',
      ),
    ],
  };

  @override
  Future<List<TranslationSuggestion>> suggest({
    required String text,
    required String sourceLanguage,
    required String targetLanguage,
    String? locale,
  }) async {
    if (delay > Duration.zero) await Future<void>.delayed(delay);
    // Keyed on the normalised form, so orthographic variants hit the same entry.
    final key = TranslationGate.normalize(text);
    return TranslationGate.refine(_fixtures[key] ?? const []);
  }
}
