import 'package:context_game/features/game/data/models/game_snapshot.dart';
import 'package:context_game/features/v2/data/remote/v2_mappers.dart';
import 'package:context_game/features/v2/domain/entities/release_visibility.dart';
import 'package:context_game/features/v2/domain/entities/v2_capabilities.dart';
import 'package:flutter_test/flutter_test.dart';

/// Locale-composition compatibility, pinned against payloads captured live from
/// production on 2026-07-29/30.
///
/// The backend resolves Arabic by locale and composes Iraq from `ar-MSA` +
/// `ar-IQ`, reporting the result as one identifier. Everything here exists to
/// prove the client stays out of that decision: it sends a language, treats the
/// returned id as opaque, and records whatever it was given.

/// Composed Arabic identity, verbatim from `POST /game/new-game`.
const kComposedAr =
    'siyak-ar-msa-corpus-v3-candidate+siyak-ar-iq-corpus-v3-candidate';

/// Plain English identity — the older format, still live.
const kPlainEn = 'siyak-en-2026-07-26-v001';

void main() {
  group('composed identity is opaque', () {
    test('a composed id round-trips through the snapshot untouched', () {
      final snap = GameSnapshot.fromJson({
        'game_id': 'g1',
        'language': 'ar',
        'release_id': kComposedAr,
        'active_release_id': kComposedAr,
        'release_changed': false,
      });
      expect(snap.releaseId, kComposedAr);
      expect(snap.activeReleaseId, kComposedAr);
      expect(
        snap.releaseId,
        isNot(contains('  ')),
        reason: 'no reformatting of the identifier',
      );
    });

    test('a plain single id is equally accepted (backward compatible)', () {
      final snap = GameSnapshot.fromJson({
        'game_id': 'g2',
        'language': 'en',
        'release_id': kPlainEn,
        'active_release_id': kPlainEn,
      });
      expect(snap.releaseId, kPlainEn);
      expect(snap.releaseChanged, isFalse);
    });

    test(
      'a future id format the client has never seen still passes through',
      () {
        const exotic = 'rel::2027/q1::ar-msa|ar-iq|ar-eg@build.9';
        final snap = GameSnapshot.fromJson({
          'game_id': 'g3',
          'release_id': exotic,
        });
        expect(snap.releaseId, exotic);
      },
    );

    test('absent release fields do not break decoding', () {
      final snap = GameSnapshot.fromJson({'game_id': 'g4', 'language': 'ar'});
      expect(snap.releaseId, isNull);
      expect(snap.activeReleaseId, isNull);
      expect(snap.releaseChanged, isFalse);
    });
  });

  group('component IDs are display-only', () {
    test('a composed id splits into its two components', () {
      expect(releaseComponents(kComposedAr), [
        'siyak-ar-msa-corpus-v3-candidate',
        'siyak-ar-iq-corpus-v3-candidate',
      ]);
    });

    test('a plain id yields no components, so nothing extra renders', () {
      expect(releaseComponents(kPlainEn), isEmpty);
      expect(releaseComponents(null), isEmpty);
      expect(releaseComponents(''), isEmpty);
      expect(releaseComponents('   '), isEmpty);
    });

    test('malformed separators degrade to "not composed"', () {
      // Never throws, never invents a component.
      expect(releaseComponents('+'), isEmpty);
      expect(releaseComponents('a+'), isEmpty);
      expect(releaseComponents('+a'), isEmpty);
      expect(releaseComponents(' a + b '), ['a', 'b']);
    });

    test('three components compose as readily as two (future countries)', () {
      expect(releaseComponents('a+b+c'), ['a', 'b', 'c']);
    });
  });

  group('activation and rollback', () {
    test(
      'release_changed is taken verbatim, never recomputed from the ids',
      () {
        // Ids identical but the server says changed: honour the server.
        final a = GameSnapshot.fromJson({
          'game_id': 'g5',
          'release_id': kComposedAr,
          'active_release_id': kComposedAr,
          'release_changed': true,
        });
        expect(a.releaseChanged, isTrue);

        // Ids differ but the server says unchanged: still honour the server.
        final b = GameSnapshot.fromJson({
          'game_id': 'g6',
          'release_id': kPlainEn,
          'active_release_id': kComposedAr,
          'release_changed': false,
        });
        expect(b.releaseChanged, isFalse);
      },
    );

    test('a rollback is visible as pinned != active', () {
      final rolled = GameSnapshot.fromJson({
        'game_id': 'g7',
        'release_id': kComposedAr, // this game keeps its data
        'active_release_id': 'siyak-ar-iq-corpus-v2', // server rolled back
        'release_changed': true,
      });
      expect(rolled.releaseId, isNot(rolled.activeReleaseId));
      expect(rolled.releaseChanged, isTrue);
    });
  });

  group('capabilities: per-language release state', () {
    // Verbatim from GET /capabilities, 2026-07-30.
    final live = <String, dynamic>{
      'capabilities_contract': {
        'contract_version': 1,
        'languages': {
          'ar': {
            'semantic': true,
            'translation_assistant': false,
            'engine_ready': true,
            'release_id': kComposedAr,
            'release_unavailable_reason': null,
          },
          'en': {
            'semantic': true,
            'translation_assistant': false,
            'engine_ready': true,
            'release_id': null,
            'release_unavailable_reason': 'NO_ACTIVE_RELEASE',
          },
        },
      },
    };

    test('Iraq resolution: Arabic reports the composed identity', () {
      final ar = V2Mappers.capabilities(live).releaseFor('ar')!;
      expect(ar.releaseId, kComposedAr);
      expect(ar.hasRelease, isTrue);
      expect(ar.engineReady, isTrue);
      expect(ar.unavailableReason, isNull);
      expect(releaseComponents(ar.releaseId), hasLength(2));
    });

    test('NO_ACTIVE_RELEASE decodes to a typed reason with a null id', () {
      final en = V2Mappers.capabilities(live).releaseFor('en')!;
      expect(en.releaseId, isNull);
      expect(en.hasRelease, isFalse);
      expect(en.unavailableReason, ReleaseUnavailableReason.noActiveRelease);
    });

    test('an unrecognised reason decodes to unknown, not a crash', () {
      final caps = V2Mappers.capabilities({
        'capabilities_contract': {
          'languages': {
            'ar': {'release_unavailable_reason': 'SOME_FUTURE_REASON'},
          },
        },
      });
      expect(
        caps.releaseFor('ar')!.unavailableReason,
        ReleaseUnavailableReason.unknown,
      );
    });

    test('an empty release_id counts as no release, not as an id', () {
      final caps = V2Mappers.capabilities({
        'capabilities_contract': {
          'languages': {
            'ar': {'release_id': ''},
          },
        },
      });
      expect(caps.releaseFor('ar')!.releaseId, isNull);
      expect(caps.releaseFor('ar')!.hasRelease, isFalse);
    });

    test('a language the client never heard of is carried, not dropped', () {
      final caps = V2Mappers.capabilities({
        'capabilities_contract': {
          'languages': {
            'ku': {'release_id': 'siyak-ku-v1', 'engine_ready': true},
          },
        },
      });
      // Architecture stays ready for further locales without a client change.
      expect(caps.releaseFor('ku')!.releaseId, 'siyak-ku-v1');
      expect(caps.releaseFor('ar'), isNull);
    });

    test('malformed contract fails closed without throwing', () {
      for (final payload in <Map<String, dynamic>>[
        const {},
        const {'capabilities_contract': 'nope'},
        const {
          'capabilities_contract': {'languages': 'nope'},
        },
        const {
          'capabilities_contract': {
            'languages': {'ar': 'nope'},
          },
        },
      ]) {
        final caps = V2Mappers.capabilities(payload);
        expect(caps.languageReleases, isEmpty, reason: '$payload');
        expect(caps.releaseFor('ar'), isNull);
      }
    });

    test('unavailable capabilities name no release for any language', () {
      expect(V2Capabilities.unavailable.releaseFor('ar'), isNull);
    });
  });

  group('no local composition or selection', () {
    test('the client never derives an id from components', () {
      // Composing locally would mean turning parts back into an identifier.
      // Nothing in the app does that; this test documents the invariant by
      // showing the only supported direction is id -> parts, for display.
      final parts = releaseComponents(kComposedAr);
      expect(
        parts.join('+'),
        kComposedAr,
        reason: 'round-trip is incidental, not a construction path',
      );
    });

    test('a snapshot never fills in a missing release from another field', () {
      final snap = GameSnapshot.fromJson({
        'game_id': 'g8',
        'language': 'ar',
        'active_release_id': kComposedAr,
        // release_id deliberately absent
      });
      expect(
        snap.releaseId,
        isNull,
        reason: 'the pinned release must not be guessed from the active one',
      );
      expect(snap.activeReleaseId, kComposedAr);
    });
  });
}
