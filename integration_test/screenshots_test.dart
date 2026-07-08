// Captures on-device screenshots of the main screens against a live backend,
// for visual comparison with the Stitch design. Run with:
//
//   flutter drive --driver=test_driver/integration_test.dart \
//     --target=integration_test/screenshots_test.dart -d <device> \
//     --dart-define=API_BASE_URL=http://127.0.0.1:8000
//
// PNGs land in build/screenshots/.
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

Future<String> fetchSecret(
    String base, String mode, String difficulty, int gameId) async {
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
  await tester.tap(find.byIcon(Icons.send));
  await tester.pump(const Duration(milliseconds: 300));
}

void main() {
  final binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('capture screens', (tester) async {
    SharedPreferences.setMockInitialValues({'siyaq.lang': 'ar'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SiyaqApp(),
    ));
    await binding.convertFlutterSurfaceToImage();

    Future<void> shot(String name) async {
      await tester.pump(const Duration(milliseconds: 300));
      await binding.takeScreenshot(name);
    }

    // Home
    await pumpUntilFound(tester, find.text('ابدأ لعبة جديدة'));
    await shot('01_home_ar');

    // Game (fresh)
    await tester.tap(find.text('ابدأ لعبة جديدة'));
    await pumpUntilFound(tester, find.text('محاولات:'));
    await shot('02_game_empty');

    // Game with guesses + hint (hint first, while its row is near the top)
    await tester.tap(find.textContaining('تلميح 0/5'));
    await pumpUntilFound(tester, find.textContaining('تلميح 1 ·'),
        timeout: const Duration(seconds: 15));
    await submitWord(tester, 'بيت');
    await pumpUntilFound(tester, find.text('السجل (1)'));
    await submitWord(tester, 'حرب');
    await pumpUntilFound(tester, find.text('السجل (2)'));
    await submitWord(tester, 'مدرسة');
    await pumpUntilFound(tester, find.text('السجل (3)'));
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump(const Duration(milliseconds: 500));
    await shot('03_game_playing');

    // Unknown word
    await submitWord(tester, 'سيارة حمراء');
    await pumpUntilFound(
        tester, find.text('هذه الكلمة غير موجودة في القاموس'));
    await pumpUntilFound(tester, find.text('سيارة'),
        timeout: const Duration(seconds: 15));
    await shot('04_unknown_word');
    await submitWord(tester, 'بيت'); // clear the unknown state

    // Solved
    final container =
        ProviderScope.containerOf(tester.element(find.byType(SiyaqApp)));
    final metaRaw = container
        .read(sharedPreferencesProvider)
        .getString('siyaq.currentGame')!;
    final metaJson =
        (jsonDecode(metaRaw) as Map<String, dynamic>)['meta']
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
    await tester.pump(const Duration(milliseconds: 800));
    await shot('05_solved');

    // English home: leave the solved route, switch language, go to Home tab.
    await tester.binding.handlePopRoute();
    await tester.pump(const Duration(milliseconds: 600));
    container.read(appSettingsProvider.notifier).setLang('en');
    await pumpUntilFound(tester, find.text('Home'));
    await tester.tap(find.text('Home').last);
    await pumpUntilFound(tester, find.text('Start New Game'));
    await shot('06_home_en');
  });
}
