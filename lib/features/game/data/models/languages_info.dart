/// `GET /api/context-game/languages`
/// {languages:[{code,name,native_name,dir,ready}]}
class LanguageInfo {
  const LanguageInfo({
    required this.code,
    required this.name,
    required this.nativeName,
    required this.dir,
    required this.ready,
  });

  final String code; // 'ar' | 'en'
  final String name;
  final String nativeName; // 'العربية' | 'English'
  final String dir; // 'rtl' | 'ltr'
  final bool ready;

  factory LanguageInfo.fromJson(Map<String, dynamic> j) => LanguageInfo(
    code: j['code'] as String,
    name: j['name'] as String,
    nativeName: (j['native_name'] ?? j['name']) as String,
    dir: j['dir'] as String? ?? 'ltr',
    ready: j['ready'] as bool? ?? true,
  );
}

class LanguagesInfo {
  const LanguagesInfo(this.languages);

  final List<LanguageInfo> languages;

  factory LanguagesInfo.fromJson(Map<String, dynamic> j) => LanguagesInfo(
    (j['languages'] as List<dynamic>? ?? const [])
        .map((e) => LanguageInfo.fromJson(e as Map<String, dynamic>))
        .toList(),
  );
}
