/// `GET /api/context-game/suggest?language=&q=&limit=` and the `suggestions`
/// array on an unknown-word guess response:
/// {language, query, suggestions:[{word}]}
class WordSuggestions {
  const WordSuggestions({required this.words});

  final List<String> words;

  factory WordSuggestions.fromJson(Map<String, dynamic> j) =>
      WordSuggestions(words: parseList(j['suggestions']));

  /// Parse a `[{word: ...}, ...]` list (also tolerates a bare `[String]`).
  static List<String> parseList(dynamic raw) =>
      (raw as List<dynamic>? ?? const [])
          .map(
            (e) =>
                e is String ? e : (e as Map<String, dynamic>)['word'] as String,
          )
          .toList();
}
