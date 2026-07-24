import 'dart:ui';

import 'package:context_game/core/config/app_config.dart';
import 'package:context_game/core/localization/app_localizations.dart';
import 'package:context_game/core/network/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig base URL resolution', () {
    test('defaults to the documented public URL', () {
      expect(AppConfig.resolveBaseUrl(null), AppConfig.documentedPublicUrl);
      expect(AppConfig.resolveBaseUrl(''), AppConfig.documentedPublicUrl);
      expect(AppConfig.resolveBaseUrl('   '), AppConfig.documentedPublicUrl);
    });

    test('runtime override wins and is normalized', () {
      expect(
        AppConfig.resolveBaseUrl('http://10.0.2.2:8000/'),
        'http://10.0.2.2:8000',
      );
      expect(
        AppConfig.resolveBaseUrl(' https://x.example.com// '),
        'https://x.example.com',
      );
    });
  });

  group('AppLocalizations direction', () {
    test('Arabic is RTL, English is LTR', () {
      expect(const AppLocalizations('ar').direction, TextDirection.rtl);
      expect(const AppLocalizations('en').direction, TextDirection.ltr);
      expect(AppLocalizations.directionFor('ar'), TextDirection.rtl);
      expect(AppLocalizations.directionFor('en'), TextDirection.ltr);
    });

    test('resolves strings per language with fallback', () {
      const ar = AppLocalizations('ar');
      const en = AppLocalizations('en');
      expect(ar('newGame'), 'ابدأ لعبة جديدة');
      expect(en('newGame'), 'Start New Game');
      expect(ar('missing-key'), 'missing-key');
    });
  });

  group('API error mapping', () {
    const ar = AppLocalizations('ar');

    test('badRequest surfaces the server detail verbatim', () {
      const e = ApiException(
        ApiErrorType.badRequest,
        detail: 'يرجى إدخال كلمة عربية صحيحة واحدة.',
      );
      expect(ar.errorMessage(e), 'يرجى إدخال كلمة عربية صحيحة واحدة.');
    });

    test('network/timeout/server map to localized messages', () {
      expect(
        ar.errorMessage(const ApiException(ApiErrorType.network)),
        ar('errNetwork'),
      );
      expect(
        ar.errorMessage(const ApiException(ApiErrorType.timeout)),
        ar('errTimeout'),
      );
      expect(
        ar.errorMessage(const ApiException(ApiErrorType.server)),
        ar('errServer'),
      );
      expect(ar.errorMessage(Exception('x')), ar('errUnknown'));
    });
  });

  group('Share text', () {
    test('matches the specified Arabic format', () {
      const ar = AppLocalizations('ar');
      final text = ar.shareText(
        attempts: 8,
        bestRank: 3,
        hintsUsed: 1,
        maxHints: 5,
      );
      expect(
        text,
        'لعبة السياق 🎯\n'
        'حلّيت الكلمة في 8 محاولات\n'
        'أفضل ترتيب: #3\n'
        'التلميحات: 1/5',
      );
      // Must never contain a secret word — it is not even a parameter.
    });

    test('English share text', () {
      const en = AppLocalizations('en');
      final text = en.shareText(
        attempts: 8,
        bestRank: 3,
        hintsUsed: 1,
        maxHints: 5,
      );
      expect(text.split('\n').first, contains('🎯'));
      expect(text, contains('8'));
      expect(text, contains('#3'));
      expect(text, contains('1/5'));
    });
  });
}
