// Live V2 end-to-end on a device: drives the REAL app UI against the REAL V2
// backend (weekly challenge). Public URL — no reverse tunnel needed.
//
//   flutter test integration_test/v2_live_test.dart -d <device> \
//     --dart-define=CG_BASE=https://<tunnel>.trycloudflare.com/api/context-game
import 'package:context_game/app.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<void> pumpUntil(
  WidgetTester tester,
  Finder finder, {
  Duration timeout = const Duration(seconds: 30),
}) async {
  final end = DateTime.now().add(timeout);
  while (DateTime.now().isBefore(end)) {
    await tester.pump(const Duration(milliseconds: 300));
    if (finder.evaluate().isNotEmpty) return;
  }
  fail('Timed out waiting for $finder');
}

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('Weekly Challenge end-to-end against live V2', (tester) async {
    SharedPreferences.setMockInitialValues({'siyaq.lang': 'ar'});
    final prefs = await SharedPreferences.getInstance();
    await tester.pumpWidget(ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SiyagApp(),
    ));

    // Splash → Home (V1 health) + V2 capabilities probe + profile registration.
    await pumpUntil(tester, find.text('لعبة فردية'));
    // Collapse the Solo config so the Weekly card is on-screen, then tap it.
    await tester.tap(find.text('لعبة فردية'));
    await tester.pump(const Duration(milliseconds: 400));
    await pumpUntil(tester, find.text('الكلمة الأسبوعية'));
    await tester.tap(find.text('الكلمة الأسبوعية'));

    // Weekly overview loads the live challenge → start.
    await pumpUntil(tester, find.text('ابدأ التحدي'),
        timeout: const Duration(seconds: 40));
    await tester.tap(find.text('ابدأ التحدي'));

    // Weekly gameplay: submit a guess against the live semantic engine.
    await pumpUntil(tester, find.text('أدخل كلمتك هنا...'),
        timeout: const Duration(seconds: 40));
    await tester.tap(find.byType(TextField).first);
    await tester.pump(const Duration(milliseconds: 200));
    await tester.enterText(find.byType(TextField).first, 'بيت');
    await tester.pump(const Duration(milliseconds: 200));
    await tester.tap(find.byIcon(Icons.send));

    // History shows the accepted guess (attempts from the server).
    await pumpUntil(tester, find.text('السجل (1)'),
        timeout: const Duration(seconds: 40));
    expect(find.text('بيت'), findsWidgets);
  });
}
