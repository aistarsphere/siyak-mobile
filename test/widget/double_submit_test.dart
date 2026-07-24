import 'package:context_game/features/game/presentation/controllers/game_controller.dart';
import 'package:context_game/features/game/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_test.dart';

/// Regression for the on-device finding: TextInputAction.send unfocuses the
/// field, so a SECOND enterText+receiveAction cycle must still submit.
void main() {
  testWidgets('two consecutive input submissions both reach the controller', (
    tester,
  ) async {
    final container = await makeContainer();
    final controller = container.read(gameControllerProvider.notifier);
    await controller.startNewGame(
      language: 'ar',
      category: 'general',
      categoryLabel: 'عام',
      difficulty: 'medium',
    );

    await tester.pumpWidget(host(container, const GameScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    Future<void> submit(String word) async {
      await tester.enterText(find.byType(TextField).first, word);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.testTextInput.receiveAction(TextInputAction.send);
      await tester.pump(const Duration(milliseconds: 200));
    }

    await submit('بيت');
    expect(container.read(gameControllerProvider).attempts, 1);

    await submit('بيت'); // duplicate — must still be SUBMITTED
    final st = container.read(gameControllerProvider);
    expect(st.attempts, 1, reason: 'duplicate must not increment');
    expect(
      st.duplicateSeq,
      1,
      reason: 'second submission must reach the controller',
    );
    expect(st.duplicateWord, 'بيت');

    await tester.pump(const Duration(milliseconds: 300));
    expect(find.textContaining('خمّنت هذه الكلمة من قبل'), findsOneWidget);
  });
}
