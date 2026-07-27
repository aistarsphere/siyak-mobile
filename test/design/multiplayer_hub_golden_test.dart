@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import '../helpers/multiplayer_hub_harness.dart';

/// Golden coverage for the Weekly Challenge screen across theme × language ×
/// state.
///
/// Regenerate after an intentional visual change:
/// ```sh
/// flutter test --update-goldens test/design/weekly_golden_test.dart
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

  Future<void> shoot(
    WidgetTester t,
    String name, {
    required Brightness brightness,
    String lang = 'ar',
    bool signedIn = true,
    int invitationCount = 0,
    Object? invitationsError,
    bool invitationsLoading = false,
    bool hasActiveRoom = false,
    double textScale = 1.0,
    Size size = const Size(390, 1100),
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      await buildHub(
        brightness: brightness,
        lang: lang,
        signedIn: signedIn,
        invitationCount: invitationCount,
        invitationsError: invitationsError,
        invitationsLoading: invitationsLoading,
        hasActiveRoom: hasActiveRoom,
        textScale: textScale,
      ),
    );
    if (invitationsLoading) {
      await t.pump();
      await t.pump(const Duration(milliseconds: 32));
    } else {
      await t.pumpAndSettle();
    }
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('signed in · dark · Arabic', (t) async {
    await shoot(
      t,
      'hub_dark_ar',
      brightness: Brightness.dark,
      invitationCount: 3,
      hasActiveRoom: true,
      size: const Size(390, 1250),
    );
  });

  testWidgets('signed in · light · English', (t) async {
    await shoot(
      t,
      'hub_light_en',
      brightness: Brightness.light,
      lang: 'en',
      invitationCount: 3,
      hasActiveRoom: true,
      size: const Size(390, 1250),
    );
  });

  testWidgets('guest · dark · English', (t) async {
    await shoot(
      t,
      'hub_guest_dark_en',
      brightness: Brightness.dark,
      lang: 'en',
      signedIn: false,
      size: const Size(390, 1300),
    );
  });

  testWidgets('invitations error · light · Arabic', (t) async {
    await shoot(
      t,
      'hub_invite_error_light_ar',
      brightness: Brightness.light,
      invitationsError: Exception('network'),
      size: const Size(390, 1250),
    );
  });

  testWidgets('320px at text scale 1.6 · Arabic', (t) async {
    await shoot(
      t,
      'hub_320_scale16_ar',
      brightness: Brightness.dark,
      signedIn: false,
      hasActiveRoom: true,
      invitationCount: 3,
      textScale: 1.6,
      size: const Size(320, 2600),
    );
  });
}
