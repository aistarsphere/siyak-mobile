import 'dart:convert';

import 'package:context_game/core/network/api_error.dart';
import 'package:context_game/features/game/domain/languages/game_start_failure.dart';
import 'package:context_game/features/game/domain/languages/language_availability.dart';
import 'package:flutter_test/flutter_test.dart';

/// Contract tests for the Language Availability Contract v1 client model.
///
/// The fixtures are the **real** bodies captured from production on
/// 2026-07-31, not hand-written approximations — a model that only parses what
/// its author imagined is how field-name mismatches ship.

/// `GET /api/v1/game/languages`.
const _liveCatalogue = '''
{
  "contract_version": "1.0.0",
  "default_language": "en",
  "languages": [
    {"code":"ar","display_name":"العربية","supported":true,"available":false,
     "state":"NO_ACTIVE_RELEASE","managed":false,
     "message_key":"language_ar_no_active_release","active_release":null,
     "categories":{"available_count":0,"available":[]},
     "name":"Arabic","native_name":"العربية","dir":"rtl","ready":false},
    {"code":"en","display_name":"English","supported":true,"available":true,
     "state":"ACTIVE_MANAGED","managed":true,"message_key":null,
     "active_release":{"release_id":"siyak-en-reference-v1-candidate-1",
       "display_name":"Siyaq English Reference v1 Candidate 1",
       "ranking_mode":"precomputed_neighbors","schema_version":"1.0.0",
       "word_count":20000,"secret_count":829,"runtime_loaded":true,"managed":true},
     "categories":{"available_count":1,"available":["general"]},
     "name":"English","native_name":"English","dir":"ltr","ready":true}
  ]
}
''';

/// The shape the endpoint served before contract v1 shipped.
const _preContract = '''
{"languages":[
  {"code":"ar","name":"Arabic","native_name":"العربية","dir":"rtl","ready":false},
  {"code":"en","name":"English","native_name":"English","dir":"ltr","ready":true}
]}
''';

LanguageCatalogue _parse(String raw) =>
    LanguageCatalogue.fromJson(jsonDecode(raw) as Map<String, dynamic>);

LanguageAvailability _lang(
  String code, {
  bool available = true,
  bool supported = true,
  LanguageAvailabilityState state = LanguageAvailabilityState.activeManaged,
}) => LanguageAvailability(
  code: code,
  displayName: code == 'ar' ? 'العربية' : 'English',
  supported: supported,
  available: available,
  state: state,
);

void main() {
  group('catalogue parsing', () {
    test('reads contract v1 in full', () {
      final c = _parse(_liveCatalogue);

      expect(c.contractVersion, '1.0.0');
      expect(c.defaultLanguage, 'en');
      expect(c.supported.map((l) => l.code), ['ar', 'en']);

      final ar = c.byCode('ar')!;
      expect(ar.displayName, 'العربية');
      expect(ar.supported, isTrue, reason: 'unavailable is not unsupported');
      expect(ar.available, isFalse);
      expect(ar.state, LanguageAvailabilityState.noActiveRelease);
      expect(ar.messageKey, 'language_ar_no_active_release');
      expect(ar.activeRelease, isNull);
      expect(ar.availableCategoryCount, 0);

      final en = c.byCode('en')!;
      expect(en.available, isTrue);
      expect(en.state, LanguageAvailabilityState.activeManaged);
      expect(en.activeRelease?.releaseId, 'siyak-en-reference-v1-candidate-1');
      expect(en.activeRelease?.wordCount, 20000);
      expect(en.activeRelease?.secretCount, 829);
      expect(en.availableCategories, ['general']);
    });

    test('falls back to `ready` on a pre-contract server', () {
      final c = _parse(_preContract);

      expect(c.byCode('ar')!.available, isFalse);
      expect(c.byCode('en')!.available, isTrue);
      // Both remain visible — the fallback must not hide anything.
      expect(c.supported.length, 2);
    });

    test('never invents a reason it was not told', () {
      final c = _parse(_preContract);
      expect(
        c.byCode('ar')!.state,
        LanguageAvailabilityState.unknown,
        reason: '`ready:false` says unavailable, not why',
      );
    });

    test('an unrecognised state decodes rather than throwing', () {
      final c = LanguageCatalogue.fromJson({
        'languages': [
          {'code': 'ar', 'available': false, 'state': 'SOMETHING_NEW'},
        ],
      });
      expect(c.byCode('ar')!.state, LanguageAvailabilityState.unknown);
    });

    test('survives a round trip through the cache', () {
      final original = _parse(_liveCatalogue);
      final restored = LanguageCatalogue.fromJson(
        jsonDecode(jsonEncode(original.toJson())) as Map<String, dynamic>,
      );
      expect(restored, original);
    });
  });

  group('initial selection', () {
    final catalogue = LanguageCatalogue(
      defaultLanguage: 'en',
      languages: [
        _lang(
          'ar',
          available: false,
          state: LanguageAvailabilityState.noActiveRelease,
        ),
        _lang('en'),
      ],
    );

    test('a saved language wins even when it is unavailable', () {
      // It was the player's choice once; the contract forbids replacing it.
      expect(catalogue.resolveInitial(saved: 'ar'), 'ar');
    });

    test('with nothing saved, prefers the server default when available', () {
      expect(catalogue.resolveInitial(), 'en');
    });

    test('falls to the first available when the default is not', () {
      final c = LanguageCatalogue(
        defaultLanguage: 'ar',
        languages: [
          _lang(
            'ar',
            available: false,
            state: LanguageAvailabilityState.noActiveRelease,
          ),
          _lang('en'),
        ],
      );
      expect(c.resolveInitial(), 'en');
    });

    test('never defaults blindly to Arabic merely for being first', () {
      final c = LanguageCatalogue(
        languages: [
          _lang(
            'ar',
            available: false,
            state: LanguageAvailabilityState.noActiveRelease,
          ),
          _lang('en'),
        ],
      );
      expect(c.resolveInitial(), 'en');
    });

    test('stays deterministic when nothing is available', () {
      final c = LanguageCatalogue(
        defaultLanguage: 'en',
        languages: [
          _lang('ar', available: false),
          _lang('en', available: false),
        ],
      );
      expect(c.resolveInitial(), 'en');
      expect(c.allUnavailable, isTrue);
    });

    test('a saved but unsupported language is ignored', () {
      expect(catalogue.resolveInitial(saved: 'fr'), 'en');
    });
  });

  group('typed start failures', () {
    // Captured verbatim from production.
    const noRelease = {
      'error': 'release_unavailable',
      'message': "No data release is currently active for 'ar'.",
      'code': 'NO_ACTIVE_RELEASE',
      'language': 'ar',
      'message_key': 'language_no_active_release',
      'retryable': true,
      'available_languages': ['en'],
      'details': {
        'language': 'ar',
        'retryable': true,
        'available_languages': ['en'],
      },
    };

    const noSecrets = {
      'error': 'no_playable_secrets_for_category',
      'message': "No playable words in category 'animals' for en",
      'code': 'NO_PLAYABLE_SECRETS_FOR_CATEGORY',
      'language': 'en',
      'category': 'animals',
      'message_key': 'category_no_playable_secrets',
      'retryable': false,
      'available_categories': ['general'],
      'details': {
        'language': 'en',
        'category': 'animals',
        'retryable': false,
        'remedy': 'choose_another_category',
        'available_categories': ['general'],
      },
    };

    test('NO_ACTIVE_RELEASE carries what recovery needs', () {
      final f = GameStartFailure.fromBody(noRelease)!;
      expect(f.code, GameStartFailureCode.noActiveRelease);
      expect(f.language, 'ar');
      expect(f.retryable, isTrue);
      expect(f.availableLanguages, ['en']);
      expect(
        f.shouldRefreshAvailability,
        isTrue,
        reason: 'availability just changed under us',
      );
    });

    test('NO_PLAYABLE_SECRETS_FOR_CATEGORY is a category problem, not a '
        'language one', () {
      final f = GameStartFailure.fromBody(noSecrets)!;
      expect(f.code, GameStartFailureCode.noPlayableSecretsForCategory);
      expect(f.category, 'animals');
      expect(f.retryable, isFalse);
      expect(f.availableCategories, ['general']);
      expect(
        f.shouldRefreshAvailability,
        isFalse,
        reason: 'the language is fine; re-fetching it would say nothing new',
      );
    });

    test('the two availability failures never collapse into one', () {
      expect(
        GameStartFailure.fromBody(noRelease)!.code,
        isNot(GameStartFailure.fromBody(noSecrets)!.code),
      );
    });

    test('reads fields nested under details as well as at the top', () {
      final f = GameStartFailure.fromBody({
        'code': 'NO_PLAYABLE_SECRETS_FOR_CATEGORY',
        'details': {'language': 'en', 'category': 'sports'},
      })!;
      expect(f.category, 'sports');
      expect(f.language, 'en');
    });

    test('LANGUAGE_REQUIRED is understood if the server ever sends it', () {
      final f = GameStartFailure.fromBody({
        'code': 'LANGUAGE_REQUIRED',
        'message_key': 'language_required',
        'available_languages': ['en'],
      })!;
      expect(f.code, GameStartFailureCode.languageRequired);
      expect(f.shouldRefreshAvailability, isTrue);
    });

    test('an untyped failure stays untyped rather than being guessed at', () {
      expect(GameStartFailure.fromBody({'detail': 'boom'}), isNull);
      expect(
        GameStartFailure.from(const ApiException(ApiErrorType.network)),
        isNull,
      );
    });

    test('lifts a typed body out of an ApiException', () {
      final f = GameStartFailure.from(
        const ApiException(
          ApiErrorType.server,
          statusCode: 503,
          body: {'code': 'NO_ACTIVE_RELEASE', 'language': 'ar'},
        ),
      );
      expect(f?.code, GameStartFailureCode.noActiveRelease);
    });
  });
}
