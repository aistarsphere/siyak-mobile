/// `GET /api/context-game/modes?language=` — the category catalogue for a
/// language. Each category is a `new-game` `category` value.
/// {language, modes:[{code,label,label_ar,word_count,playable}]}
class CategoryInfo {
  const CategoryInfo({
    required this.code,
    required this.label,
    required this.labelAr,
    required this.wordCount,
    required this.playable,
  });

  final String code; // e.g. 'general', 'animals', 'sports'
  final String label; // English label
  final String labelAr; // Arabic label
  final int wordCount;
  final bool playable;

  /// Localized label for the given app language.
  String labelFor(String lang) => lang == 'ar' ? labelAr : label;

  factory CategoryInfo.fromJson(Map<String, dynamic> j) => CategoryInfo(
    code: j['code'] as String,
    label: j['label'] as String? ?? j['code'] as String,
    labelAr:
        j['label_ar'] as String? ??
        j['label'] as String? ??
        j['code'] as String,
    wordCount: (j['word_count'] as num?)?.toInt() ?? 0,
    playable: j['playable'] as bool? ?? true,
  );
}

class ModesInfo {
  const ModesInfo({required this.language, required this.categories});

  final String language;
  final List<CategoryInfo> categories;

  /// Only categories the backend marks playable.
  List<CategoryInfo> get playable =>
      categories.where((c) => c.playable).toList();

  factory ModesInfo.fromJson(Map<String, dynamic> j) => ModesInfo(
    language: j['language'] as String? ?? 'ar',
    categories: (j['modes'] as List<dynamic>? ?? const [])
        .map((e) => CategoryInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
