import 'dart:ui';

import '../network/api_error.dart';
import 'strings_ar.dart';
import 'strings_en.dart';

/// Lightweight bilingual string table. Arabic-first.
class AppLocalizations {
  const AppLocalizations(this.lang);

  final String lang; // 'ar' | 'en'

  bool get isArabic => lang == 'ar';
  TextDirection get direction =>
      isArabic ? TextDirection.rtl : TextDirection.ltr;
  Locale get locale => Locale(lang);

  static TextDirection directionFor(String lang) =>
      lang == 'ar' ? TextDirection.rtl : TextDirection.ltr;

  String call(String key) =>
      (isArabic ? stringsAr : stringsEn)[key] ?? stringsEn[key] ?? key;

  String errorMessage(Object error) {
    if (error is ApiException) {
      switch (error.type) {
        case ApiErrorType.network:
          return this('errNetwork');
        case ApiErrorType.timeout:
          return this('errTimeout');
        case ApiErrorType.badRequest:
          return error.detail ?? this('errUnknown');
        case ApiErrorType.server:
        case ApiErrorType.unknown:
          return this('errServer');
      }
    }
    return this('errUnknown');
  }

  /// Share text, e.g.:
  /// لعبة السياق 🎯
  /// حلّيت الكلمة في 8 محاولات
  /// أفضل ترتيب: #3
  /// التلميحات: 1/5
  String shareText({
    required int attempts,
    required int bestRank,
    required int hintsUsed,
    required int maxHints,
  }) {
    final lines = [
      '${this('appTitle')} 🎯',
      this('shareSolvedIn').replaceFirst('{n}', '$attempts'),
      this('shareBestRank').replaceFirst('{r}', '$bestRank'),
      this('shareHints')
          .replaceFirst('{h}', '$hintsUsed')
          .replaceFirst('{max}', '$maxHints'),
    ];
    return lines.join('\n');
  }
}
