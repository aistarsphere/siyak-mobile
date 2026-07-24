import 'package:context_game/features/game/presentation/controllers/game_controller.dart';
import 'package:context_game/features/game/presentation/screens/game_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screens_test.dart';

void main() {
  testWidgets('duplicate guess shows feedback and keeps attempts unchanged', (
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
    await controller.submitGuess('بيت');

    await tester.pumpWidget(host(container, const GameScreen()));
    await tester.pump(const Duration(milliseconds: 400));

    // Same canonical word via a different surface form.
    await tester.enterText(find.byType(TextField).first, 'البيت');
    await tester.testTextInput.receiveAction(TextInputAction.send);
    await tester.pump(); // start submit
    await tester.pump(const Duration(milliseconds: 100)); // resolve future
    await tester.pump(
      const Duration(milliseconds: 300),
    ); // snackbar animates in

    expect(container.read(gameControllerProvider).attempts, 1);
    expect(find.textContaining('خمّنت هذه الكلمة من قبل'), findsOneWidget);
  });
}
