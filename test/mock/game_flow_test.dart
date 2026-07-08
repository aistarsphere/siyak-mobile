import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/game_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/game/presentation/controllers/stats_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_repository.dart';

/// End-to-end controller flows against the scripted fake backend —
/// no live server required.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ProviderContainer container;
  late FakeGameRepository fake;

  Future<void> setUpContainer() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    fake = FakeGameRepository();
    container = ProviderContainer(overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      gameRepositoryProvider.overrideWithValue(fake),
    ]);
    addTearDown(container.dispose);
  }

  GameController controller() =>
      container.read(gameControllerProvider.notifier);
  GameState state() => container.read(gameControllerProvider);

  group('suggestionQueryFor', () {
    test('uses the first token stripped to letters', () {
      expect(GameController.suggestionQueryFor('سيارة حمراء'), 'سيارة');
      expect(GameController.suggestionQueryFor('سيارة1'), 'سيارة');
      expect(GameController.suggestionQueryFor('  hello world '), 'hello');
      expect(GameController.suggestionQueryFor('123'), '123'); // fallback
    });
  });

  group('game flow (mock API)', () {
    setUp(setUpContainer);

    test('new game stores meta and resets state', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      expect(state().meta?.gameId, 3);
      expect(state().meta?.mode, 'general');
      expect(state().attempts, 0);
      expect(state().solved, isFalse);
      expect(container.read(statsProvider).gamesPlayed, 1);
    });

    test('accepted guess appends history and updates best rank', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess('بيت');
      expect(state().attempts, 1);
      expect(state().bestRank, 50);
      expect(state().lastGuess?.word, 'بيت');

      await controller().submitGuess('حاسوب');
      expect(state().attempts, 2);
      expect(state().bestRank, 2);
      expect(state().bestGuess?.word, 'حاسوب');
    });

    test('duplicate canonical guess does NOT increment attempts', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess('بيت');
      expect(state().attempts, 1);

      // Different surface form, same canonical word on the server.
      await controller().submitGuess('البيت');
      expect(state().attempts, 1, reason: 'duplicate must not count');
      expect(state().duplicateWord, 'بيت');
      expect(state().lastGuess?.word, 'بيت');
    });

    test('unknown word (400) shows suggestions instead of a guess', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess('سيار');
      expect(state().attempts, 0);
      expect(state().unknown, isNotNull);
      expect(state().unknown!.word, 'سيار');
      expect(state().unknown!.loading, isFalse);
      expect(state().unknown!.suggestions,
          ['سيارة', 'السيارة', 'سيارات']);
      // A following valid guess clears the unknown state.
      await controller().submitGuess('بيت');
      expect(state().unknown, isNull);
      expect(state().attempts, 1);
    });

    test('hint flow: level increments, parses word/rank, capped at 5',
        () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().requestHint();
      expect(state().hintsUsed, 1);
      expect(state().hints.single.word, 'حرب');
      expect(state().hints.single.rank, 152);

      for (var i = 0; i < 10; i++) {
        await controller().requestHint();
      }
      expect(state().hintsUsed, 5, reason: 'hint limit is 5');
      expect(state().hintsExhausted, isTrue);
    });

    test('solved state on secret guess', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess('حاسوب');
      await controller().submitGuess(FakeGameRepository.secretWord);
      expect(state().solved, isTrue);
      expect(state().attempts, 2);
      expect(
          state().guesses.where((g) => g.isSecret).single.rank, 1);
      expect(container.read(statsProvider).gamesSolved, 1);
      expect(container.read(statsProvider).bestRank, 1);
    });

    test('root-match win reveals the real secret word', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess('مبرمج');
      expect(state().solved, isTrue);
      final win = state().guesses.single;
      expect(win.rootMatch, isTrue);
      expect(win.answerWord, FakeGameRepository.secretWord);
    });

    test('unsolved game persists and can be resumed', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess('بيت');

      // Simulate a fresh app session sharing the same prefs.
      final prefs = await SharedPreferences.getInstance();
      final second = ProviderContainer(overrides: [
        sharedPreferencesProvider.overrideWithValue(prefs),
        gameRepositoryProvider.overrideWithValue(fake),
      ]);
      addTearDown(second.dispose);

      final saved =
          second.read(gameControllerProvider.notifier).savedGame();
      expect(saved?.gameId, 3);

      final ok = await second
          .read(gameControllerProvider.notifier)
          .resumeSavedGame();
      expect(ok, isTrue);
      final restored = second.read(gameControllerProvider);
      expect(restored.attempts, 1);
      expect(restored.guesses.single.word, 'بيت');
    });

    test('solved game is not offered for resume', () async {
      await controller()
          .startNewGame(mode: 'general', difficulty: 'medium');
      await controller().submitGuess(FakeGameRepository.secretWord);
      expect(controller().savedGame(), isNull);
    });
  });
}
