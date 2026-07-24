import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/game_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/game/presentation/controllers/stats_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_repository.dart';

/// End-to-end controller flows against the scripted fake backend that mirrors
/// the real `/api/context-game` schema — no live server required.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeGameRepository fake;

  Future<void> setUpContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fake = FakeGameRepository();
    container = ProviderContainer(
      overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gameRepositoryProvider.overrideWithValue(fake),
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

  group('game flow (mock API, real schema)', () {
    setUp(setUpContainer);

    test('new game stores snapshot and resets state', () async {
      await newGame();
      expect(state().gameId, 'game-1');
      expect(state().category, 'general');
      expect(state().categoryLabel, 'عام');
      expect(state().attempts, 0);
      expect(state().solved, isFalse);
      expect(container.read(statsProvider).gamesPlayed, 1);
    });

    test('accepted guess appends history and updates best rank', () async {
      await newGame();
      await controller().submitGuess('بيت');
      expect(state().attempts, 1);
      expect(state().bestRank, 18607);
      expect(state().lastGuessWord, 'بيت');

      await controller().submitGuess('حاسوب');
      expect(state().attempts, 2);
      expect(state().bestRank, 2);
      expect(state().bestGuess?.word, 'حاسوب');
    });

    test('duplicate canonical guess does NOT increment attempts', () async {
      await newGame();
      await controller().submitGuess('بيت');
      expect(state().attempts, 1);

      // Different surface form, same canonical word on the server.
      await controller().submitGuess('البيت');
      expect(state().attempts, 1, reason: 'duplicate must not count');
      expect(state().duplicateWord, 'بيت');
      expect(state().duplicateSeq, 1);
    });

    test('unknown word shows server suggestions, no attempt counted', () async {
      await newGame();
      await controller().submitGuess('زقزقتيبل');
      expect(state().attempts, 0);
      expect(state().unknown, isNotNull);
      expect(state().unknown!.word, 'زقزقتيبل');
      expect(state().unknown!.suggestions, ['سيارة', 'السيارة', 'سيارات']);

      // A following valid guess clears the unknown state.
      await controller().submitGuess('بيت');
      expect(state().unknown, isNull);
      expect(state().attempts, 1);
    });

    test('hint flow: structured word/rank, capped at 5', () async {
      await newGame();
      await controller().requestHint();
      expect(state().hintsUsed, 1);
      expect(state().hints.single.word, 'حرب');
      expect(state().hints.single.rank, 152);
      expect(state().hintsRemaining, 4);

      for (var i = 0; i < 10; i++) {
        await controller().requestHint();
      }
      expect(state().hintsUsed, 5, reason: 'hint limit is 5');
      expect(state().hintsExhausted, isTrue);
    });

    test('solved state reveals the secret word', () async {
      await newGame();
      await controller().submitGuess('حاسوب');
      await controller().submitGuess(FakeGameRepository.secretWord);
      expect(state().solved, isTrue);
      expect(state().secretWord, FakeGameRepository.secretWord);
      expect(container.read(statsProvider).gamesSolved, 1);
    });

    test('unsolved game persists and can be resumed from the server', () async {
      await newGame();
      await controller().submitGuess('بيت');

      // Fresh session sharing the same prefs + backend.
      final prefs = await SharedPreferences.getInstance();
      final second = ProviderContainer(
        overrides: [
          sharedPreferencesProvider.overrideWithValue(prefs),
          gameRepositoryProvider.overrideWithValue(fake),
        ],
      );
      addTearDown(second.dispose);

      expect(second.read(gameControllerProvider.notifier).hasSavedGame, isTrue);
      final ok = await second
          .read(gameControllerProvider.notifier)
          .resumeSavedGame();
      expect(ok, isTrue);
      final restored = second.read(gameControllerProvider);
      expect(restored.attempts, 1);
      expect(restored.guesses.single.word, 'بيت');
    });

    test('solved game is not offered for resume', () async {
      await newGame();
      await controller().submitGuess(FakeGameRepository.secretWord);
      expect(controller().hasSavedGame, isFalse);
    });
  });

  group('suggestionQueryFor', () {
    test('uses the first token stripped to letters', () {
      expect(GameController.suggestionQueryFor('سيارة حمراء'), 'سيارة');
      expect(GameController.suggestionQueryFor('سيارة1'), 'سيارة');
      expect(GameController.suggestionQueryFor('  hello world '), 'hello');
    });
  });
}
