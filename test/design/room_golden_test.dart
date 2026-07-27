@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/room_harness.dart';

/// Golden coverage for the room flow — Lobby, Join and the Create wizard —
/// across theme × language × state.
///
/// Regenerate after an intentional visual change:
/// ```sh
/// flutter test --update-goldens test/design/room_golden_test.dart
/// ```
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'NotoNaskhArabic': [
      'assets/fonts/siyag/NotoNaskhArabic-400.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-500.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-600.ttf',
      'assets/fonts/siyag/NotoNaskhArabic-700.ttf',
    ],
    'PlusJakartaSans': [
      'assets/fonts/siyag/PlusJakartaSans-400.ttf',
      'assets/fonts/siyag/PlusJakartaSans-500.ttf',
      'assets/fonts/siyag/PlusJakartaSans-600.ttf',
      'assets/fonts/siyag/PlusJakartaSans-700.ttf',
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

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(WidgetTester t, String name) => expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('goldens/$name.png'),
  );

  void sized(WidgetTester t, Size size) {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);
  }

  group('lobby', () {
    testWidgets('host · dark · Arabic', (t) async {
      sized(t, const Size(390, 1000));
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.dark,
          roomState: room(
            participants: [
              participant('كاظم', isHost: true, isMe: true),
              participant('Sara'),
              participant('Yousef', connected: false),
            ],
          ),
        ),
      );
      await t.pump();
      await shoot(t, 'room_lobby_dark_ar');
    });

    testWidgets('guest · light · English · reconnecting', (t) async {
      sized(t, const Size(390, 1000));
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.light,
          lang: 'en',
          roomState: room(
            participants: [participant('Sara', isHost: true)],
            maxPlayers: 6,
          ),
          status: RoomConnStatus.reconnecting,
        ),
      );
      await t.pump();
      await shoot(t, 'room_lobby_light_en_reconnecting');
    });

    testWidgets('empty roster · dark · English', (t) async {
      sized(t, const Size(390, 1000));
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.dark,
          lang: 'en',
          roomState: room(participants: const []),
        ),
      );
      await t.pump();
      await shoot(t, 'room_lobby_empty_dark_en');
    });

    testWidgets('320px at text scale 1.6 · Arabic', (t) async {
      sized(t, const Size(320, 1600));
      await t.pumpWidget(
        await buildLobby(
          brightness: Brightness.dark,
          roomState: room(
            participants: [
              participant('كاظم', isHost: true, isMe: true),
              participant('Sara', connected: false),
            ],
          ),
          textScale: 1.6,
        ),
      );
      await t.pump();
      await shoot(t, 'room_lobby_320_scale16_ar');
    });
  });

  group('join', () {
    testWidgets('empty · dark · Arabic', (t) async {
      sized(t, const Size(390, 800));
      await t.pumpWidget(await buildJoin(brightness: Brightness.dark));
      await t.pump();
      await shoot(t, 'room_join_dark_ar');
    });

    testWidgets('searching · light · English', (t) async {
      sized(t, const Size(390, 800));
      await t.pumpWidget(
        await buildJoin(brightness: Brightness.light, lang: 'en', busy: true),
      );
      await t.pump();
      await shoot(t, 'room_join_busy_light_en');
    });
  });

  group('create', () {
    testWidgets('language step · dark · Arabic', (t) async {
      sized(t, const Size(390, 900));
      await t.pumpWidget(await buildCreate(brightness: Brightness.dark));
      await t.pumpAndSettle();
      await shoot(t, 'room_create_lang_dark_ar');
    });

    testWidgets('category grid · light · English', (t) async {
      sized(t, const Size(390, 900));
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.light, lang: 'en'),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Next'));
      await t.pumpAndSettle();
      await shoot(t, 'room_create_category_light_en');
    });

    testWidgets('mode step · dark · English', (t) async {
      sized(t, const Size(390, 900));
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.dark, lang: 'en'),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 2; i++) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
      }
      await shoot(t, 'room_create_mode_dark_en');
    });

    testWidgets('summary · dark · Arabic', (t) async {
      sized(t, const Size(390, 900));
      await t.pumpWidget(await buildCreate(brightness: Brightness.dark));
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await t.tap(find.textContaining('التالي'));
        await t.pumpAndSettle();
      }
      await shoot(t, 'room_create_summary_dark_ar');
    });

    testWidgets('catalogue error · light · Arabic', (t) async {
      sized(t, const Size(390, 900));
      await t.pumpWidget(
        await buildCreate(brightness: Brightness.light, categories: null),
      );
      await t.pumpAndSettle();
      await t.tap(find.textContaining('التالي'));
      await t.pumpAndSettle();
      await shoot(t, 'room_create_error_light_ar');
    });

    testWidgets('summary at 320px · text scale 2.0 · English', (t) async {
      sized(t, const Size(320, 1400));
      await t.pumpWidget(
        await buildCreate(
          brightness: Brightness.dark,
          lang: 'en',
          textScale: 2.0,
        ),
      );
      await t.pumpAndSettle();
      for (var i = 0; i < 4; i++) {
        await t.tap(find.text('Next'));
        await t.pumpAndSettle();
      }
      await shoot(t, 'room_create_summary_320_scale2_en');
    });
  });
}
