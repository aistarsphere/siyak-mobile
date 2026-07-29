import 'dart:convert';

import 'package:context_game/core/sound/sound_player_adapter.dart';
import 'package:context_game/core/sound/sound_service.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/game_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_repository.dart';

/// Session release attribution and cache safety across the lifecycle events the
/// locale-composition rollout can produce: activation, rollback, expiry, cold
/// start, warm start and app upgrade.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeGameRepository fake;
  late SharedPreferences prefs;

  const composedV3 =
      'siyak-ar-msa-corpus-v3-candidate+siyak-ar-iq-corpus-v3-candidate';
  const composedV4 = 'siyak-ar-msa-corpus-v4+siyak-ar-iq-corpus-v4';

  Future<void> boot({Map<String, Object> seed = const {}}) async {
    SharedPreferences.setMockInitialValues(seed);
    prefs = await SharedPreferences.getInstance();
    fake = FakeGameRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gameRepositoryProvider.overrideWithValue(fake),
        soundPlayerAdapterProvider.overrideWithValue(
          const SilentSoundAdapter(),
        ),
      ],
    );
    addTearDown(container.dispose);
  }

  GameController controller() =>
      container.read(gameControllerProvider.notifier);
  GameState state() => container.read(gameControllerProvider);

  Future<void> newGame() => controller().startNewGame(
    language: 'ar',
    category: 'general',
    categoryLabel: 'عام',
    difficulty: 'medium',
  );

  /// The persisted resume pointer, decoded.
  Map<String, dynamic>? saved() {
    final raw = prefs.getString('siyaq.currentGame');
    return raw == null ? null : jsonDecode(raw) as Map<String, dynamic>;
  }

  group('session release attribution', () {
    test('a new game records the composed release it was served', () async {
      await boot();
      await newGame();

      expect(state().releaseId, composedV3);
      expect(state().activeReleaseId, composedV3);
      expect(
        state().releaseChanged,
        isFalse,
        reason: 'nothing has been activated since this game started',
      );
    });

    test('the pinned release is persisted with the resume pointer', () async {
      await boot();
      await newGame();

      final s = saved();
      expect(s, isNotNull);
      expect(s!['gameId'], 'game-1');
      expect(s['releaseId'], composedV3);
    });

    test('a resumed session is attributed to its own pinned release', () async {
      await boot();
      await newGame();
      final pinned = state().releaseId;

      // Activation happens while the player is away.
      fake.activeReleaseId = composedV4;

      // Warm start: same container, resume from the saved pointer.
      final ok = await controller().resumeSavedGame();
      expect(ok, isTrue);
      expect(
        state().releaseId,
        pinned,
        reason: 'the game keeps the data it was created with',
      );
      expect(state().activeReleaseId, composedV4);
      expect(
        state().releaseChanged,
        isTrue,
        reason: 'server reports the active release moved on',
      );
    });
  });

  group('activation and rollback', () {
    test('a new game after activation uses the new release', () async {
      await boot();
      await newGame();
      expect(state().releaseId, composedV3);

      fake.activeReleaseId = composedV4;
      await newGame();

      expect(state().releaseId, composedV4);
      expect(state().releaseChanged, isFalse);
      expect(
        saved()!['releaseId'],
        composedV4,
        reason: 'the pointer follows the newest game',
      );
    });

    test(
      'a rollback is reflected on the next new game, not retroactively',
      () async {
        await boot();
        fake.activeReleaseId = composedV4;
        await newGame();
        final onV4 = state().releaseId;

        // Operator rolls back.
        fake.activeReleaseId = composedV3;
        await controller().resumeSavedGame();

        expect(onV4, composedV4);
        expect(state().releaseId, composedV4, reason: 'still pinned to v4');
        expect(state().activeReleaseId, composedV3);
        expect(state().releaseChanged, isTrue);

        await newGame();
        expect(state().releaseId, composedV3);
      },
    );

    test('no client-side selection: the app never picks a release', () async {
      await boot();
      // Whatever the fake "activates" is what the session gets — the controller
      // has no input into the choice beyond sending a language.
      for (final id in [composedV3, composedV4, 'siyak-en-2026-07-26-v001']) {
        fake.activeReleaseId = id;
        await newGame();
        expect(state().releaseId, id);
      }
    });
  });

  group('cache safety', () {
    test(
      'a withdrawn game clears the pointer instead of failing forever',
      () async {
        await boot();
        await newGame();
        expect(saved(), isNotNull);

        // The game no longer exists: expired, or its release was withdrawn.
        fake.gameNotFound = true;

        final ok = await controller().resumeSavedGame();
        expect(ok, isFalse, reason: 'resume reports failure, does not throw');
        expect(
          saved(),
          isNull,
          reason: 'stale pointer dropped — no app-data wipe needed',
        );

        // And the app is immediately usable again.
        fake.gameNotFound = false;
        await newGame();
        expect(state().gameId, isNotNull);
      },
    );

    test('cold start with a pointer from a previous release resumes', () async {
      // Simulates app upgrade / cold start: prefs survive, container is new.
      await boot(
        seed: {
          'siyaq.currentGame': jsonEncode({
            'gameId': 'game-legacy',
            'language': 'ar',
            'category': 'general',
            'categoryLabel': 'عام',
            'difficulty': 'medium',
            'solved': false,
            // No releaseId at all — written by a build before attribution.
          }),
        },
      );

      expect(controller().hasSavedGame, isTrue);
      final ok = await controller().resumeSavedGame();
      expect(ok, isTrue, reason: 'an older pointer must still resume');
      // The server supplies the release the client never stored.
      expect(state().releaseId, composedV3);
    });

    test('a corrupt pointer is ignored rather than crashing', () async {
      await boot(seed: {'siyaq.currentGame': 'not json at all'});
      expect(controller().hasSavedGame, isFalse);
      expect(await controller().resumeSavedGame(), isFalse);
    });

    test('a solved game is not offered for resume', () async {
      await boot(
        seed: {
          'siyaq.currentGame': jsonEncode({
            'gameId': 'game-done',
            'solved': true,
            'releaseId': composedV3,
          }),
        },
      );
      expect(controller().hasSavedGame, isFalse);
    });

    test('nothing about word data is cached locally', () async {
      await boot();
      await newGame();

      // The whole persisted payload is an id plus display labels: a release
      // change can never poison a local corpus, because there is none.
      final keys = saved()!.keys.toSet();
      expect(keys, {
        'gameId',
        'language',
        'category',
        'categoryLabel',
        'difficulty',
        'solved',
        'releaseId',
      });
      expect(
        prefs.getKeys().where((k) => k.contains('word')),
        isEmpty,
        reason: 'no vocabulary is stored client-side',
      );
    });
  });
}
