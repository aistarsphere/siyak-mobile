@Tags(['golden'])
library;

import 'dart:io';

import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/ranked.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/gameplay_modes_harness.dart';

/// Golden coverage for the Room Game and Ranked Match migrations.
///
/// ```sh
/// flutter test --update-goldens test/design/gameplay_modes_golden_test.dart
/// ```
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'IBMPlexSansArabic': [
      'assets/fonts/siyag/IBMPlexSansArabic-Regular.ttf',
      'assets/fonts/siyag/IBMPlexSansArabic-Medium.ttf',
      'assets/fonts/siyag/IBMPlexSansArabic-SemiBold.ttf',
      'assets/fonts/siyag/IBMPlexSansArabic-Bold.ttf',
    ],
    'Inter': ['assets/fonts/siyag/Inter.ttf'],
    'NotoNaskhArabic': [
      'assets/fonts/siyag/NotoNaskhArabic-400.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-700.ttf',
    ],
    'DMMono': [
      'assets/fonts/siyag/DMMono-400.ttf',
      'assets/fonts/siyag/DMMono-500.ttf',
    ],
  };
  for (final e in families.entries) {
    final loader = FontLoader(e.key);
    for (final path in e.value) {
      loader.addFont(
        File(path).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    }
    await loader.load();
  }
  final root =
      Platform.environment['FLUTTER_ROOT'] ??
      '/Users/devalqaasem/development/flutter';
  final icons = File(
    '$root/bin/cache/artifacts/material_fonts/MaterialIcons-Regular.otf',
  );
  if (icons.existsSync()) {
    final loader = FontLoader('MaterialIcons')
      ..addFont(icons.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

final _roomHistory = [
  shared('كتاب', 25, by: 'كاظم', isMine: true),
  shared('مكتبة', 42, by: '—', isSystemHint: true),
  shared('قلم', 340, by: 'Sara'),
  shared('ورقة', 900, by: 'Yousef'),
  shared('سيارة', 18400, by: 'Sara'),
];

final _matchGuesses = [
  matchGuess('library', rank: 25, isYou: true, turn: 1),
  matchGuess('shelf', rank: 340, turn: 2),
  matchGuess('paper', rank: 900, isYou: true, turn: 3),
  matchGuess('car', rank: 18400, turn: 4),
];

void main() {
  setUpAll(_loadFonts);

  void sized(WidgetTester t, Size size) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  Future<void> shoot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  group('room game', () {
    testWidgets('playing · dark · Arabic', (t) async {
      sized(t, const Size(390, 1100));
      await t.pumpWidget(
        await buildRoomGame(room: roomWith(history: _roomHistory)),
      );
      await t.pumpAndSettle();
      await shoot(t, 'room_game_dark_ar');
    });

    testWidgets('playing · light · English game', (t) async {
      sized(t, const Size(390, 1100));
      await t.pumpWidget(
        await buildRoomGame(
          brightness: Brightness.light,
          uiLang: 'en',
          room: roomWith(
            history: [
              shared('library', 25, by: 'You', isMine: true),
              shared('shelf', 900, by: 'Sara'),
            ],
            language: GameplayLanguage.english,
          ),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'room_game_light_en');
    });

    testWidgets('reconnecting · dark · English', (t) async {
      sized(t, const Size(390, 1100));
      await t.pumpWidget(
        await buildRoomGame(
          uiLang: 'en',
          room: roomWith(history: _roomHistory),
          status: RoomConnStatus.reconnecting,
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'room_game_reconnecting_dark_en');
    });

    testWidgets('winner overlay · dark · Arabic', (t) async {
      sized(t, const Size(390, 1100));
      await t.pumpWidget(
        await buildRoomGame(
          room: roomWith(
            history: [
              ..._roomHistory,
              shared('قاموس', 1, by: 'كاظم', isMine: true, solved: true),
            ],
            state: RoomState.solved,
            winner: const RoomParticipant(
              participantId: 'p_كاظم',
              label: 'كاظم',
              isHost: true,
              isMe: true,
            ),
            secretWord: 'قاموس',
          ),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'room_game_winner_dark_ar');
    });

    testWidgets('320px at text scale 1.6 · Arabic', (t) async {
      sized(t, const Size(320, 1700));
      await t.pumpWidget(
        await buildRoomGame(
          room: roomWith(history: _roomHistory),
          textScale: 1.6,
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'room_game_320_scale16_ar');
    });
  });

  group('ranked match', () {
    testWidgets('my turn · dark · English', (t) async {
      sized(t, const Size(390, 1300));
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: _matchGuesses),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'ranked_myturn_dark_en');
    });

    testWidgets('opponent turn · light · Arabic', (t) async {
      sized(t, const Size(390, 1300));
      await t.pumpWidget(
        await buildRankedMatch(
          brightness: Brightness.light,
          snapshot: match(
            guesses: [
              matchGuess('كتاب', rank: 25, isYou: true, turn: 1),
              matchGuess('قلم', rank: 900, turn: 2),
            ],
            myTurn: false,
          ),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'ranked_oppturn_light_ar');
    });

    testWidgets('preparing · dark · Arabic', (t) async {
      sized(t, const Size(390, 900));
      await t.pumpWidget(
        await buildRankedMatch(
          snapshot: match(status: RankedMatchStatus.preparing),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'ranked_preparing_dark_ar');
    });

    testWidgets('win · dark · English', (t) async {
      sized(t, const Size(390, 1100));
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(
            status: RankedMatchStatus.solved,
            language: 'en',
            guesses: _matchGuesses,
            winner: 'me',
            secretWord: 'bookshelf',
            ratingDelta: 24,
          ),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'ranked_win_dark_en');
    });

    testWidgets('loss · light · English', (t) async {
      sized(t, const Size(390, 1100));
      await t.pumpWidget(
        await buildRankedMatch(
          brightness: Brightness.light,
          uiLang: 'en',
          snapshot: match(
            status: RankedMatchStatus.solved,
            language: 'en',
            winner: 'them',
            secretWord: 'bookshelf',
            ratingDelta: -18,
          ),
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'ranked_loss_light_en');
    });

    testWidgets('320px at text scale 2.0 · English', (t) async {
      sized(t, const Size(320, 2200));
      await t.pumpWidget(
        await buildRankedMatch(
          uiLang: 'en',
          snapshot: match(language: 'en', guesses: _matchGuesses),
          textScale: 2.0,
        ),
      );
      await t.pumpAndSettle();
      await shoot(t, 'ranked_320_scale2_en');
    });
  });
}
