// Live end-to-end test: drives the REAL app against a REAL backend.
//
// Requires a reachable backend (default http://127.0.0.1:8000 — use
// `adb reverse tcp:8000 tcp:8000` for a USB device):
//
//   flutter test integration_test/live_e2e_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000
import 'dart:convert';
import 'dart:io';

import 'package:context_game/app.dart';
import 'package:context_game/core/config/app_config.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUntilFound(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 20),
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

Future<String> fetchSecret(String base, String mode, String difficulty,
    int gameId) async {
  final client = HttpClient();
  try {
    final req = await client.getUrl(Uri.parse(
        '$base/api/giveup?mode=$mode&difficulty=$difficulty&gameId=$gameId'));
    final res = await req.close();
    final body = await res.transform(utf8.decoder).join();
    return (jsonDecode(body) as Map<String, dynamic>)['secret'] as String;
  } finally {
    client.close();
  }
}

Future<void> submitWord(WidgetTester tester, String word) async {
  // Tap-to-focus first: TextInputAction.send unfocuses the field on real
  // devices, which would make a follow-up enterText silently no-op.
  final field = find.byType(TextField).first;
  await tester.tap(field);
  await tester.pump(const Duration(milliseconds: 150));
  await tester.enterText(field, word);
  await tester.pump(const Duration(milliseconds: 100));
  // Submit via the amber send button — the primary user path.
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Arabic game end-to-end against the live backend',
      (tester) async {
    SharedPreferences.setMockInitialValues({'siyaq.lang': 'ar'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SiyaqApp(),
    ));

    // Splash → Home once /api/modes answers (backend health check).
    await pumpUntilFound(tester, find.text('ابدأ لعبة جديدة'));

    // RTL verified on a rendered widget.
    expect(Directionality.of(tester.element(find.text('ابدأ لعبة جديدة'))),
        TextDirection.rtl);
    // Category chips came from the live backend.
    await pumpUntilFound(tester, find.text('متنوّع'));

    // Start a new Arabic game.
    await tester.tap(find.text('ابدأ لعبة جديدة'));
    await pumpUntilFound(tester, find.text('محاولات:'));

    // 1) Hint from the live semantic-neighbor engine (requested first,
    //    while the hints row is still at the top of the list).
    await pumpUntilFound(tester, find.textContaining('تلميح 0/5'));
    await tester.tap(find.textContaining('تلميح 0/5'));
    await pumpUntilFound(tester, find.textContaining('تلميح 1 ·'),
        timeout: const Duration(seconds: 15));

    // 2) Valid guess.
    await submitWord(tester, 'بيت');
    await pumpUntilFound(tester, find.text('السجل (1)'));
    expect(find.text('بيت'), findsWidgets);

    // 3) Duplicate canonical guess must NOT increment attempts.
    await submitWord(tester, 'بيت');
    await pumpUntilFound(
        tester, find.textContaining('خمّنت هذه الكلمة من قبل'),
        timeout: const Duration(seconds: 8));
    expect(find.text('السجل (1)'), findsOneWidget,
        reason: 'duplicate guess must not increment attempts');
    // Let the snackbar time out before the next step.
    await pumpUntilGone(
        tester, find.textContaining('خمّنت هذه الكلمة من قبل'));

    // 4) Unknown/invalid word (two words → 400) → did-you-mean card with
    //    live suggestions for the first token.
    await submitWord(tester, 'سيارة حمراء');
    await pumpUntilFound(
        tester, find.text('هذه الكلمة غير موجودة في القاموس'),
        timeout: const Duration(seconds: 10));
    await pumpUntilFound(tester, find.text('هل تقصد:'));
    // Suggestions load from /api/datastore/words (q=سيارة).
    await pumpUntilFound(tester, find.text('سيارة'),
        timeout: const Duration(seconds: 15));

    // 5) Autocomplete chips after 2+ characters (debounced live call).
    await tester.enterText(find.byType(TextField).first, 'سيار');
    await tester.pump(const Duration(milliseconds: 600));
    await pumpUntilFound(tester, find.text('سيارة'),
        timeout: const Duration(seconds: 10));

    // 6) Solve: fetch the secret via /api/giveup (test-only) and submit it.
    final container = ProviderScope.containerOf(
        tester.element(find.byType(SiyaqApp)));
    final meta = container
        .read(sharedPreferencesProvider)
        .getString('siyaq.currentGame');
    final metaJson =
        (jsonDecode(meta!) as Map<String, dynamic>)['meta']
            as Map<String, dynamic>;
    final secret = await fetchSecret(
      AppConfig.resolveBaseUrl(null),
      metaJson['mode'] as String,
      metaJson['difficulty'] as String,
      (metaJson['gameId'] as num).toInt(),
    );

    await submitWord(tester, secret);
    await pumpUntilFound(tester, find.text('أحسنت! لقد وجدت الكلمة'),
        timeout: const Duration(seconds: 15));
    expect(find.text('الكلمة السرية هي'), findsOneWidget);
    expect(find.text('مشاركة النتيجة'), findsOneWidget);
  });

  testWidgets('English game starts against the live backend', (tester) async {
    SharedPreferences.setMockInitialValues({'siyaq.lang': 'en'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SiyaqApp(),
    ));

    await pumpUntilFound(tester, find.text('Start New Game'));
    expect(Directionality.of(tester.element(find.text('Start New Game'))),
        TextDirection.ltr);
    await pumpUntilFound(tester, find.text('General'));

    await tester.tap(find.text('Start New Game'));
    await pumpUntilFound(tester, find.text('Guesses:'));

    await submitWord(tester, 'house');
    await pumpUntilFound(tester, find.text('History (1)'),
        timeout: const Duration(seconds: 15));
  });
}
