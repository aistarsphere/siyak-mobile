import 'package:context_game/features/game/presentation/screens/home_screen.dart';
import 'package:context_game/features/v2/domain/entities/adaptive_hint.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/v2_capabilities.dart';
import 'package:context_game/features/v2/presentation/controllers/room_controller.dart';
import 'package:context_game/features/v2/presentation/screens/join_room_screen.dart';
import 'package:context_game/features/v2/presentation/screens/leaderboard_screen.dart';
import 'package:context_game/features/v2/presentation/screens/room_lobby_screen.dart';
import 'package:context_game/features/v2/presentation/screens/weekly_overview_screen.dart';
import 'package:context_game/features/v2/presentation/widgets/adaptive_hint_pill.dart';
import 'package:context_game/features/v2/presentation/widgets/profile_setup_sheet.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'v2_helpers.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('three-mode Home renders in Arabic RTL', (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await v2Container();
    await tester.pumpWidget(hostV2(c, const Scaffold(body: HomeScreen())));
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('لعبة فردية'), findsOneWidget);
    expect(find.text('الكلمة الأسبوعية'), findsOneWidget);
    expect(find.text('اللعب مع الأصدقاء'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('لعبة فردية'))),
      TextDirection.rtl,
    );
  });

  testWidgets('three-mode Home renders in English LTR', (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await v2Container(lang: 'en');
    await tester.pumpWidget(
      hostV2(c, const Scaffold(body: HomeScreen()), lang: 'en'),
    );
    await tester.pump(const Duration(milliseconds: 400));

    expect(find.text('Solo Game'), findsOneWidget);
    expect(find.text('Weekly Challenge'), findsOneWidget);
    expect(find.text('Play With Friends'), findsOneWidget);
    expect(
      Directionality.of(tester.element(find.text('Solo Game'))),
      TextDirection.ltr,
    );
  });

  testWidgets('V2 unavailable → modes gated with "coming soon" (V1 kept)',
      (tester) async {
    tester.view.physicalSize = const Size(1000, 2600);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
    final c = await v2Container(caps: V2Capabilities.unavailable);
    await tester.pumpWidget(hostV2(c, const Scaffold(body: HomeScreen())));
    await tester.pumpAndSettle();
    // Solo always works; Weekly/Multiplayer show the friendly gated state.
    expect(find.text('لعبة فردية'), findsOneWidget);
    expect(find.text('قريباً'), findsWidgets);
  });

  testWidgets('Weekly overview renders week header + actions', (tester) async {
    final c = await v2Container();
    await tester.pumpWidget(hostV2(c, const WeeklyOverviewScreen()));
    await tester.pumpAndSettle();

    expect(find.text('الكلمة الأسبوعية'), findsWidgets);
    expect(find.text('التقنية'), findsOneWidget); // weekly category label
    expect(find.text('لوحة الصدارة'), findsOneWidget);
  });

  testWidgets('Leaderboard renders rows and highlights current profile', (
    tester,
  ) async {
    final c = await v2Container();
    await tester.pumpWidget(
      hostV2(c, const LeaderboardScreen(weekId: 'week-2026-28')),
    );
    await tester.pumpAndSettle();

    // Current profile row (placement #7 in the mock) is present.
    expect(find.text('لاعب-AMB1'), findsOneWidget);
    // Some ordinary rows are present.
    expect(find.textContaining('لاعب-'), findsWidgets);
  });

  testWidgets('Join room normalizes to uppercase', (tester) async {
    final c = await v2Container();
    await tester.pumpWidget(hostV2(c, const JoinRoomScreen()));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField), 'amber7');
    await tester.pump();
    expect(find.text('AMBER7'), findsOneWidget);
  });

  testWidgets('Room lobby shows join code, host badge and start', (
    tester,
  ) async {
    final c = await v2Container();
    // Seed an active room as host.
    await c
        .read(roomLifecycleControllerProvider.notifier)
        .create(language: GameplayLanguage.arabic, category: 'technology');
    await tester.pumpWidget(hostV2(c, const RoomLobbyScreen()));
    await tester.pump(const Duration(milliseconds: 300));

    expect(find.text('AMBER7'), findsOneWidget); // join code
    expect(find.text('المضيف'), findsOneWidget); // host badge
    expect(find.text('ابدأ اللعبة'), findsOneWidget); // host can start
  });

  testWidgets('Adaptive hint pill shows word + rank, never an attempt', (
    tester,
  ) async {
    final c = await v2Container();
    await tester.pumpWidget(
      hostV2(
        c,
        const Scaffold(
          body: Center(
            child: AdaptiveHintPill(
              hint: AdaptiveHint(
                number: 1,
                word: 'خوارزمية',
                semanticRank: 31,
                hintsRemaining: 4,
              ),
              hintLabel: 'تلميح',
            ),
          ),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text('تلميح 1 · خوارزمية · #31'), findsOneWidget);
  });

  testWidgets('First-run profile setup sheet renders', (tester) async {
    final c = await v2Container();
    await tester.pumpWidget(
      hostV2(
        c,
        Scaffold(
          body: Builder(
            builder: (context) => Center(
              child: ElevatedButton(
                onPressed: () => ProfileSetupSheet.show(context),
                child: const Text('open'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.text('اختر اسماً للظهور'), findsOneWidget);
    expect(find.text('حفظ'), findsOneWidget);
    expect(find.text('تخطٍّ'), findsOneWidget);
  });
}
