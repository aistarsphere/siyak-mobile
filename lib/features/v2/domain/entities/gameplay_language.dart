import 'dart:ui';

/// The language of the game *content* (secret word / vocabulary), chosen
/// before a session is created and then LOCKED for that session. This is
/// independent of the app's UI locale.
enum GameplayLanguage {
  arabic('ar', TextDirection.rtl),
  english('en', TextDirection.ltr);

  const GameplayLanguage(this.code, this.direction);

  final String code;
  final TextDirection direction;

  bool get isArabic => this == GameplayLanguage.arabic;

  static GameplayLanguage fromCode(String? code) =>
      code == 'en' ? GameplayLanguage.english : GameplayLanguage.arabic;

  /// Localization key for this language's own label.
  String get labelKey => isArabic ? 'langArabic' : 'langEnglish';
}
