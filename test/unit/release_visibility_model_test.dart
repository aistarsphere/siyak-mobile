import 'package:context_game/features/v2/data/remote/v2_mappers.dart';
import 'package:context_game/features/v2/domain/entities/release_visibility.dart';
import 'package:flutter_test/flutter_test.dart';

/// Decoder contract for `GET /release-visibility`.
///
/// The load-bearing case is **omitted vs present-null**: a key switched off by
/// policy must stay `absent`, while a key the server sends as `null` on a legacy
/// release must be `present` with a null value. Both render nothing, but only one
/// of them means "the backend does not have this".
void main() {
  group('hidden response', () {
    test(
      '{"visible": false} decodes to the hidden fallback and nothing else',
      () {
        final v = V2Mappers.releaseVisibility({'visible': false});
        expect(v.visible, isFalse);
        expect(v.resolvedRelease, isNull);
        expect(v.currentGameRelease, isNull);
        expect(v.releaseChangedForNewGames, isFalse);
        expect(v.lastUpdated, isNull);
        expect(v.scope, ReleaseVisibilityScope.unknown);
        expect(v.hasAnythingToShow, isFalse);
      },
    );

    test('a missing `visible` key is treated as hidden, not as visible', () {
      expect(V2Mappers.releaseVisibility(const {}).visible, isFalse);
    });

    test('a non-boolean `visible` is not coerced into true', () {
      expect(V2Mappers.releaseVisibility({'visible': 'true'}).visible, isFalse);
      expect(V2Mappers.releaseVisibility({'visible': 1}).visible, isFalse);
    });
  });

  group('visible response', () {
    // The canonical example from the contract.
    final canonical = <String, dynamic>{
      'visible': true,
      'scope': 'internal_testers',
      'resolved_release': {
        'release_id': 'siyak-ar-lexicon-v003-ar-iq',
        'display_name': 'Arabic Iraqi v003',
        'dataset_version': 'arabic-lexicon-v003',
        'language': 'ar',
        'pack': 'ar-IQ',
        'status': 'active',
      },
      'current_game_release': {
        'release_id': 'siyak-ar-lexicon-v002-ar-iq',
        'display_name': 'Arabic Iraqi v002',
        'pinned': true,
      },
      'release_changed_for_new_games': true,
      'last_updated': '2026-07-29T00:00:00Z',
    };

    test('maps every documented field', () {
      final v = V2Mappers.releaseVisibility(canonical);
      expect(v.visible, isTrue);
      expect(v.scope, ReleaseVisibilityScope.internalTesters);

      final r = v.resolvedRelease!;
      expect(r.releaseId.value, 'siyak-ar-lexicon-v003-ar-iq');
      expect(r.displayName, 'Arabic Iraqi v003');
      expect(r.datasetVersion.value, 'arabic-lexicon-v003');
      expect(r.language, 'ar');
      expect(r.pack.value, 'ar-IQ');
      expect(r.status, 'active');
      expect(r.label, 'Arabic Iraqi v003');

      final c = v.currentGameRelease!;
      expect(c.releaseId.value, 'siyak-ar-lexicon-v002-ar-iq');
      expect(c.label, 'Arabic Iraqi v002');
      expect(c.pinned, isTrue);
      expect(c.unknownRelease, isFalse);
      expect(c.isUnknownLegacy, isFalse);

      expect(v.releaseChangedForNewGames, isTrue);
      expect(v.lastUpdated, '2026-07-29T00:00:00Z');
      expect(v.hasAnythingToShow, isTrue);
    });

    test('unknown extra fields are ignored, not fatal', () {
      final v = V2Mappers.releaseVisibility({
        ...canonical,
        'a_future_field': {'nested': true},
        'another': 42,
        'resolved_release': {
          ...canonical['resolved_release'] as Map<String, dynamic>,
          'unexpected_key': 'whatever',
        },
      });
      expect(v.visible, isTrue);
      expect(v.resolvedRelease!.label, 'Arabic Iraqi v003');
    });

    test('an unrecognised scope decodes to unknown instead of throwing', () {
      for (final raw in <Object>['some_future_scope', '', 7]) {
        final v = V2Mappers.releaseVisibility({...canonical, 'scope': raw});
        expect(v.scope, ReleaseVisibilityScope.unknown, reason: '$raw');
        expect(v.visible, isTrue);
      }
    });

    test('an absent scope decodes to unknown', () {
      final withoutScope = Map<String, dynamic>.of(canonical)..remove('scope');
      final v = V2Mappers.releaseVisibility(withoutScope);
      expect(v.scope, ReleaseVisibilityScope.unknown);
      expect(v.visible, isTrue);
    });

    test('known scopes each map', () {
      ReleaseVisibilityScope scopeOf(String s) =>
          V2Mappers.releaseVisibility({...canonical, 'scope': s}).scope;
      expect(scopeOf('hidden'), ReleaseVisibilityScope.hidden);
      expect(
        scopeOf('internal_testers'),
        ReleaseVisibilityScope.internalTesters,
      );
      expect(scopeOf('all_users'), ReleaseVisibilityScope.allUsers);
    });
  });

  group('omitted vs present-null', () {
    test('omitted gated keys stay absent', () {
      // Policy switched off release_id, dataset_version, pack and source_commit.
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {
          'display_name': 'Arabic Iraqi v003',
          'language': 'ar',
          'status': 'active',
        },
      });
      final r = v.resolvedRelease!;
      expect(r.releaseId.present, isFalse);
      expect(r.datasetVersion.present, isFalse);
      expect(r.pack.present, isFalse);
      expect(r.sourceCommit.present, isFalse);
      for (final g in [r.releaseId, r.datasetVersion, r.pack, r.sourceCommit]) {
        expect(g.hasValue, isFalse);
      }
    });

    test('present-null keys are present, distinct from omitted', () {
      // Legacy release: the backend genuinely has no dataset_version or pack.
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {
          'release_id': 'legacy-001',
          'display_name': null,
          'dataset_version': null,
          'pack': null,
        },
      });
      final r = v.resolvedRelease!;
      expect(r.datasetVersion.present, isTrue);
      expect(r.datasetVersion.value, isNull);
      expect(r.datasetVersion.hasValue, isFalse);
      expect(r.pack.present, isTrue);
      expect(r.pack.value, isNull);

      // Neither renders, but the model can still tell them apart.
      expect(
        r.datasetVersion,
        isNot(const Gated<String>.absent()),
        reason: 'present-null must not equal absent',
      );
    });

    test('display_name null falls back to release_id', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {'release_id': 'legacy-001', 'display_name': null},
      });
      expect(v.resolvedRelease!.displayName, isNull);
      expect(v.resolvedRelease!.label, 'legacy-001');
    });

    test('neither display_name nor release_id → no label, so no row', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {'language': 'ar'},
      });
      expect(v.resolvedRelease!.label, isNull);
    });
  });

  group('edge cases', () {
    test('no active release: resolved_release null', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': null,
      });
      expect(v.visible, isTrue);
      expect(v.resolvedRelease, isNull);
      expect(v.hasAnythingToShow, isFalse);
    });

    test('no resumable game: current_game_release null', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {'display_name': 'v3'},
        'current_game_release': null,
      });
      expect(v.currentGameRelease, isNull);
    });

    test(
      'game created before pinning: release_id null, unknown_release true',
      () {
        final v = V2Mappers.releaseVisibility({
          'visible': true,
          'resolved_release': {'display_name': 'v3', 'release_id': 'rel-3'},
          'current_game_release': {'release_id': null, 'unknown_release': true},
        });
        final c = v.currentGameRelease!;
        expect(c.unknownRelease, isTrue);
        expect(c.releaseId.present, isTrue);
        expect(c.releaseId.value, isNull);
        expect(c.isUnknownLegacy, isTrue);
        expect(
          c.pinned,
          isFalse,
          reason: 'no pinned key on a pre-pinning game',
        );
        expect(
          c.label,
          isNull,
          reason: 'must not be filled in from the resolved release',
        );
      },
    );

    test('release_changed_for_new_games defaults false when absent', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {'display_name': 'v3'},
      });
      expect(v.releaseChangedForNewGames, isFalse);
    });

    test('release_changed_for_new_games true/false both honoured verbatim', () {
      for (final flag in [true, false]) {
        final v = V2Mappers.releaseVisibility({
          'visible': true,
          'resolved_release': {'release_id': 'rel-3'},
          'current_game_release': {'release_id': 'rel-3', 'pinned': true},
          'release_changed_for_new_games': flag,
        });
        // Never recomputed locally, even when the ids plainly match.
        expect(v.releaseChangedForNewGames, flag);
      }
    });

    test('a non-map nested object does not crash the decode', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': 'not-an-object',
        'current_game_release': 42,
      });
      expect(v.resolvedRelease, isNull);
      expect(v.currentGameRelease, isNull);
    });

    test('source_commit is carried when the server includes it', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': {'release_id': 'rel-3', 'source_commit': 'abc1234'},
      });
      expect(v.resolvedRelease!.sourceCommit.value, 'abc1234');
    });
  });

  group('hasAnythingToShow', () {
    test('false when visible but every field was gated away', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'scope': 'all_users',
        'resolved_release': {'language': 'ar', 'status': 'active'},
      });
      expect(v.visible, isTrue);
      expect(
        v.hasAnythingToShow,
        isFalse,
        reason: 'an empty section must not be rendered',
      );
    });

    test('true on a current-game row alone', () {
      final v = V2Mappers.releaseVisibility({
        'visible': true,
        'resolved_release': null,
        'current_game_release': {'release_id': null, 'unknown_release': true},
      });
      expect(v.hasAnythingToShow, isTrue);
    });
  });
}
