import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/presentation/controllers/leaderboard_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';
import 'package:context_game/features/v2/presentation/controllers/weekly_controller.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../support/v2_mock/v2_mock_overrides.dart';

Future<ProviderContainer> makeContainer() async {
  SharedPreferences.setMockInitialValues({});
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      // Weekly run + leaderboard both read weeklyRepositoryProvider; one shared
      // mock instance keeps their state consistent.
      weeklyRepositoryProvider.overrideWithValue(MockWeeklyRepository()),
      profileRepositoryProvider.overrideWithValue(MockProfileRepository()),
    ],
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('weekly flow (mock)', () {
    test('start → guess → best rank tracked; attempts from server', () async {
      final c = await makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(weeklyRunControllerProvider.notifier);
      await ctrl.start(GameplayLanguage.arabic);
      expect(c.read(weeklyRunControllerProvider).run, isNotNull);

      await ctrl.submitGuess('بيت'); // rank 2170
      await ctrl.submitGuess('حاسوب'); // rank 2
      final s = c.read(weeklyRunControllerProvider);
      expect(s.run!.attempts, 2);
      expect(s.run!.bestUserGeneratedRank, 2);
    });

    test('canonical duplicate does not add an attempt', () async {
      final c = await makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(weeklyRunControllerProvider.notifier);
      await ctrl.start(GameplayLanguage.arabic);
      await ctrl.submitGuess('حرب');
      expect(c.read(weeklyRunControllerProvider).run!.attempts, 1);
      await ctrl.submitGuess('حرب'); // duplicate
      final s = c.read(weeklyRunControllerProvider);
      expect(s.run!.attempts, 1, reason: 'duplicate must not count');
      expect(s.duplicateCanonical, 'حرب');
      expect(s.duplicateSeq, 1);
    });

    test('unknown word yields suggestions, no attempt', () async {
      final c = await makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(weeklyRunControllerProvider.notifier);
      await ctrl.start(GameplayLanguage.arabic);
      await ctrl.submitGuess('زقزقتيبل');
      final s = c.read(weeklyRunControllerProvider);
      expect(s.run!.attempts, 0);
      expect(s.unknownWord, 'زقزقتيبل');
      expect(s.unknownSuggestions, isNotEmpty);
    });

    test(
      'adaptive hint: not an attempt, rank never 1-3, best-rank untouched',
      () async {
        final c = await makeContainer();
        addTearDown(c.dispose);
        final ctrl = c.read(weeklyRunControllerProvider.notifier);
        await ctrl.start(GameplayLanguage.arabic);
        await ctrl.submitGuess('حاسوب'); // best rank 2
        final before = c.read(weeklyRunControllerProvider).run!;
        await ctrl.requestHint(HintMode.adaptive);
        final after = c.read(weeklyRunControllerProvider);
        expect(after.hints, hasLength(1));
        expect(
          after.hints.first.semanticRank,
          greaterThanOrEqualTo(4),
          reason: 'ranks 1-3 must never be adaptive hints',
        );
        expect(
          after.run!.attempts,
          before.attempts,
          reason: 'hint is not an attempt',
        );
        expect(
          after.run!.bestUserGeneratedRank,
          2,
          reason: 'hint rank is not the user best rank',
        );
      },
    );

    test('solve reveals the secret + placement', () async {
      final c = await makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(weeklyRunControllerProvider.notifier);
      await ctrl.start(GameplayLanguage.arabic);
      await ctrl.submitGuess(MockFixtures.secretWordAr);
      final s = c.read(weeklyRunControllerProvider);
      expect(s.run!.solved, isTrue);
      expect(s.run!.secretWord, MockFixtures.secretWordAr);
      expect(s.run!.placement, isNotNull);
    });

    test('gameplay language is fixed on the run (lock)', () async {
      final c = await makeContainer();
      addTearDown(c.dispose);
      final ctrl = c.read(weeklyRunControllerProvider.notifier);
      await ctrl.start(GameplayLanguage.english);
      final run = c.read(weeklyRunControllerProvider).run!;
      expect(run.language, GameplayLanguage.english);
      // The English secret solves it — content language did not change.
      await ctrl.submitGuess(MockFixtures.secretWordEn);
      expect(c.read(weeklyRunControllerProvider).run!.solved, isTrue);
    });

    test('leaderboard paginates and highlights the current profile', () async {
      final c = await makeContainer();
      addTearDown(c.dispose);
      final lb = c.read(leaderboardControllerProvider.notifier);
      await lb.load(MockFixtures.weekId);
      final first = c.read(leaderboardControllerProvider);
      expect(first.entries, hasLength(20));
      expect(first.entries.any((e) => e.isCurrentProfile), isTrue);
      await lb.loadMore();
      expect(
        c.read(leaderboardControllerProvider).entries.length,
        greaterThan(20),
      );
    });
  });
}
