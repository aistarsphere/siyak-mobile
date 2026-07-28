import 'dart:ui';

import 'package:context_game/core/config/app_config.dart';
import 'package:context_game/core/localization/app_localizations.dart';
import 'package:context_game/core/network/api_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppConfig base URL resolution', () {
    // The unified backend is one API root (`…/api/v1`): the gameplay/engine
    // base (`resolveBaseUrl`) is `<root>/game`; the platform base
    // (`resolveV2BaseUrl`) is the root itself.
    test('gameplay base is the root + /game', () {
      expect(
        AppConfig.resolveBaseUrl(null),
        '${AppConfig.documentedPublicUrl}/game',
      );
      expect(
        AppConfig.resolveBaseUrl(''),
        '${AppConfig.documentedPublicUrl}/game',
      );
    });

    test('platform base is the API root', () {
      expect(AppConfig.resolveV2BaseUrl(null), AppConfig.documentedPublicUrl);
      expect(AppConfig.documentedPublicUrl, endsWith('/api/v1'));
    });

    test('runtime override wins, is normalized, and derives both bases', () {
      expect(
        AppConfig.resolveBaseUrl('http://10.0.2.2:8000/'),
        'http://10.0.2.2:8000/game',
      );
      expect(
        AppConfig.resolveV2BaseUrl(' https://x.example.com// '),
        'https://x.example.com',
      );
      expect(
        AppConfig.resolveV2SocketBase('https://x.example.com'),
        'wss://x.example.com',
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

    test('badRequest is localized, never the raw server detail', () {
      // Regression: this test used to assert the detail was shown verbatim, on
      // an *Arabic* fixture. The live API sends English ("Please enter a
      // word."), so on device an Arabic player got an English sentence. The
      // detail stays on the exception for logs; the player gets localized copy.
      const e = ApiException(
        ApiErrorType.badRequest,
        detail: 'Please enter a word.',
      );
      const enLoc = AppLocalizations('en');
      expect(ar.errorMessage(e), ar('errRejectedWord'));
      expect(ar.errorMessage(e), isNot(contains('Please')));
      expect(enLoc.errorMessage(e), enLoc('errRejectedWord'));
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
