import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/game/presentation/controllers/game_controller.dart';
import 'package:context_game/features/game/presentation/controllers/providers.dart';
import 'package:context_game/features/game/presentation/screens/game_screen.dart';
import 'package:context_game/features/game/presentation/screens/home_screen.dart';
import 'package:context_game/features/game/presentation/screens/solved_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/fake_repository.dart';

Future<ProviderContainer> makeContainer({String lang = 'ar'}) async {
  SharedPreferences.setMockInitialValues({'siyaq.lang': lang});
  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      gameRepositoryProvider.overrideWithValue(FakeGameRepository()),
    ],
  );
  addTearDown(container.dispose);
  return container;
}

Widget host(ProviderContainer container, Widget child, {String lang = 'ar'}) {
  return UncontrolledProviderScope(
    container: container,
    child: MaterialApp(
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: Scaffold(body: child),
    ),
  );
}

void main() {
  group('HomeScreen', () {
    testWidgets('renders Arabic UI in RTL', (tester) async {
      final container = await makeContainer();
      await tester.pumpWidget(host(container, const HomeScreen()));
      await tester.pumpAndSettle();

      expect(find.text('لعبة السياق'), findsWidgets);
      expect(find.text('ابدأ لعبة جديدة'), findsOneWidget);
      expect(find.text('التصنيف'), findsOneWidget);
      expect(find.text('الصعوبة'), findsOneWidget);
      // Category/difficulty chips from the (fake) backend catalogue:
      expect(find.text('عام'), findsOneWidget);
      expect(find.text('الحيوانات'), findsOneWidget);
      expect(find.text('متوسط'), findsOneWidget);

      final dir = Directionality.of(
        tester.element(find.text('ابدأ لعبة جديدة')),
      );
      expect(dir, TextDirection.rtl);
    });

    testWidgets('renders English UI in LTR', (tester) async {
      final container = await makeContainer(lang: 'en');
      await tester.pumpWidget(host(container, const HomeScreen(), lang: 'en'));
      await tester.pumpAndSettle();

      expect(find.text('Start New Game'), findsOneWidget);
      expect(find.text('Category'), findsOneWidget);
      expect(find.text('General'), findsOneWidget);

      final dir = Directionality.of(
        tester.element(find.text('Start New Game')),
      );
      expect(dir, TextDirection.ltr);
    });
  });

  group('GameScreen', () {
    testWidgets('renders input, history, best-guess card and hint pill', (
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
      await controller.submitGuess('حاسوب');
      await controller.submitGuess('حرب');
      await controller.requestHint();

      await tester.pumpWidget(host(container, const GameScreen()));
      // Shimmer/pulse animations repeat forever → fixed pumps, no settle.
      await tester.pump(const Duration(milliseconds: 700));

      // Input field placeholder
      expect(find.text('أدخل كلمتك هنا...'), findsOneWidget);
      // Top stats row: attempts count and best rank
      expect(find.text('محاولات:'), findsOneWidget);
      expect(find.text('2'), findsWidgets);
      expect(find.text('#2'), findsWidgets); // best rank (حاسوب)
      // Best-guess card
      expect(find.text('أقرب تخمين'), findsOneWidget);
      expect(find.text('ساخن جداً'), findsOneWidget); // heat label rank 2
      // History section with both guesses
      expect(find.text('السجل (2)'), findsOneWidget);
      expect(find.text('حاسوب'), findsWidgets);
      expect(find.text('حرب'), findsWidgets);
      // Hint pill parsed as «تلميح 1 · حرب · #152»
      expect(find.text('تلميح 1 · حرب · #152'), findsOneWidget);
    });

    testWidgets('unknown word shows the did-you-mean card with suggestions', (
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
      await controller.submitGuess('سيار');

      await tester.pumpWidget(host(container, const GameScreen()));
      await tester.pump(const Duration(milliseconds: 700));

      expect(find.text('هذه الكلمة غير موجودة في القاموس'), findsOneWidget);
      expect(find.text('هل تقصد:'), findsOneWidget);
      expect(find.text('سيارة'), findsOneWidget);
      expect(find.text('السيارة'), findsOneWidget);
      expect(find.text('سيارات'), findsOneWidget);
    });
  });

  group('SolvedScreen', () {
    testWidgets('renders secret word, stats and actions', (tester) async {
      // Tall viewport so the whole (lazy) solved layout is built.
      tester.view.physicalSize = const Size(800, 2400);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);
      final container = await makeContainer();
      final controller = container.read(gameControllerProvider.notifier);
      await controller.startNewGame(
        language: 'ar',
        category: 'general',
        categoryLabel: 'عام',
        difficulty: 'medium',
      );
      await controller.submitGuess('حاسوب');
      await controller.submitGuess('كود');
      await controller.requestHint();
      await controller.submitGuess(FakeGameRepository.secretWord);
      expect(container.read(gameControllerProvider).solved, isTrue);

      await tester.pumpWidget(host(container, const SolvedScreen()));
      // Confetti/pulse/shine run for seconds → fixed pumps, no settle.
      await tester.pump(const Duration(milliseconds: 500));

      expect(find.text('أحسنت! لقد وجدت الكلمة'), findsOneWidget);
      expect(find.text('الكلمة السرية هي'), findsOneWidget);
      expect(find.text(FakeGameRepository.secretWord), findsOneWidget);
      expect(find.text('3'), findsWidgets); // attempts
      expect(find.text('#1'), findsOneWidget); // rank
      expect(find.text('المحاولات'), findsOneWidget);
      expect(find.text('التلميحات'), findsOneWidget);
      // Closest guesses list shows non-secret guesses
      expect(find.text('أقرب الكلمات التي خمنتها'), findsOneWidget);
      expect(find.text('حاسوب'), findsOneWidget);
      expect(find.text('كود'), findsOneWidget);
      // Actions
      expect(find.text('مشاركة النتيجة'), findsOneWidget);
      expect(find.text('لعبة جديدة'), findsOneWidget);
    });
  });
}
