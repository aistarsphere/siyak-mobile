// Live end-to-end test: drives the REAL app against the REAL Cloudflare
// backend (public URL — no adb reverse needed):
//
//   flutter test integration_test/live_e2e_test.dart -d <device> \
//     --dart-define=CG_BASE=https://<tunnel>.trycloudflare.com/api/context-game
import 'package:context_game/app.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 25),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

Future<void> pumpUntilGone(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 10),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 250));
    if (finder.evaluate().isEmpty) return;
  }
  fail('Timed out waiting for $finder to disappear');
}

Future<void> submitWord(WidgetTester tester, String word) async {
  final field = find.byType(TextField).first;
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(field, word);
  await tester.pump(const Duration(milliseconds: 100));
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arabic game end-to-end against the live backend', (
    tester,
  ) async {
    SharedPreferences.setMockInitialValues({'siyaq.lang': 'ar'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const SiyagApp(),
      ),
    );

    // Splash → Home once /modes answers (backend health check).
    await pumpUntilFound(tester, find.text('ابدأ لعبة جديدة'));
    expect(
      Directionality.of(tester.element(find.text('ابدأ لعبة جديدة'))),
      TextDirection.rtl,
    );
    // Category chips came from the live backend.
    await pumpUntilFound(tester, find.text('عام'));

    // Start a new Arabic game.
    await tester.tap(find.text('ابدأ لعبة جديدة'));
    await pumpUntilFound(tester, find.text('محاولات:'));

    // 1) Hint from the live semantic engine (requested first, near the top).
    await pumpUntilFound(tester, find.textContaining('تلميح 0/5'));
    await tester.tap(find.textContaining('تلميح 0/5'));
    await pumpUntilFound(
      tester,
      find.textContaining('تلميح 1 ·'),
      timeout: const Duration(seconds: 20),
    );

    // 2) Valid guess.
    await submitWord(tester, 'بيت');
    await pumpUntilFound(
      tester,
      find.text('السجل (1)'),
      timeout: const Duration(seconds: 20),
    );

    // 3) Duplicate canonical guess must NOT increment attempts.
    await submitWord(tester, 'بيت');
    await pumpUntilFound(
      tester,
      find.textContaining('خمّنت هذه الكلمة من قبل'),
      timeout: const Duration(seconds: 10),
    );
    expect(
      find.text('السجل (1)'),
      findsOneWidget,
      reason: 'duplicate guess must not increment attempts',
    );
    await pumpUntilGone(tester, find.textContaining('خمّنت هذه الكلمة من قبل'));

    // 4) Unknown word (two words → not in vocabulary) → did-you-mean card.
    await submitWord(tester, 'سيارة حمراء');
    await pumpUntilFound(
      tester,
      find.text('هذه الكلمة غير موجودة في القاموس'),
      timeout: const Duration(seconds: 15),
    );
    await pumpUntilFound(tester, find.text('هل تقصد:'));
    await pumpUntilFound(
      tester,
      find.text('سيارة'),
      timeout: const Duration(seconds: 15),
    );

    // 5) Autocomplete chips after 2+ characters (debounced live call).
    await tester.enterText(find.byType(TextField).first, 'سيار');
    await tester.pump(const Duration(milliseconds: 600));
    await pumpUntilFound(
      tester,
      find.text('سيارة'),
      timeout: const Duration(seconds: 15),
    );
  });

  testWidgets('English game starts against the live backend', (tester) async {
    SharedPreferences.setMockInitialValues({'siyaq.lang': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
        child: const SiyagApp(),
      ),
    );

    await pumpUntilFound(tester, find.text('Start New Game'));
    expect(
      Directionality.of(tester.element(find.text('Start New Game'))),
      TextDirection.ltr,
    );
    await pumpUntilFound(tester, find.text('General'));

    await tester.tap(find.text('Start New Game'));
    await pumpUntilFound(tester, find.text('Guesses:'));

    await submitWord(tester, 'house');
    await pumpUntilFound(
      tester,
      find.text('History (1)'),
      timeout: const Duration(seconds: 20),
    );
  });
}
