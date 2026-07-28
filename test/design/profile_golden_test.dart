@Tags(['golden'])
library;

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:context_game/features/v2/domain/entities/release_visibility.dart';

import '../helpers/profile_harness.dart';

/// Golden coverage for the Profile screen across theme × language × state.
///
/// Regenerate after an intentional visual change:
/// ```sh
/// flutter test --update-goldens test/design/profile_golden_test.dart
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

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(
    WidgetTester t,
    String name, {
    required Brightness brightness,
    String lang = 'ar',
    bool signedIn = false,
    bool blocked = false,
    bool appleSupported = false,
    double textScale = 1.0,
    Size size = const Size(390, 1000),
    FakeReleaseVisibilityRepository? releaseVisibility,
  }) async {
    t.view.physicalSize = size;
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(
      await buildProfile(
        brightness: brightness,
        lang: lang,
        account: blocked
            ? kBlockedAccount
            : signedIn
            ? kSampleAccount
            : null,
        appleSupported: appleSupported,
        textScale: textScale,
        releaseVisibility: releaseVisibility,
      ),
    );
    // Let the async controllers resolve.
    await t.pump();
    await t.pump(const Duration(milliseconds: 32));

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  group('guest', () {
    testWidgets('dark · Arabic', (t) async {
      await shoot(
        t,
        'profile_guest_dark_ar',
        brightness: Brightness.dark,
        appleSupported: true,
      );
    });

    testWidgets('light · English', (t) async {
      await shoot(
        t,
        'profile_guest_light_en',
        brightness: Brightness.light,
        lang: 'en',
        appleSupported: true,
      );
    });
  });

  group('signed in', () {
    testWidgets('dark · Arabic', (t) async {
      await shoot(
        t,
        'profile_signedin_dark_ar',
        brightness: Brightness.dark,
        signedIn: true,
      );
    });

    testWidgets('light · English', (t) async {
      await shoot(
        t,
        'profile_signedin_light_en',
        brightness: Brightness.light,
        lang: 'en',
        signedIn: true,
      );
    });

    testWidgets('blocked account banner · dark · Arabic', (t) async {
      await shoot(
        t,
        'profile_blocked_dark_ar',
        brightness: Brightness.dark,
        signedIn: true,
        blocked: true,
      );
    });
  });

  group('stress', () {
    testWidgets('320px at text scale 1.6 · Arabic', (t) async {
      await shoot(
        t,
        'profile_320_scale16_ar',
        brightness: Brightness.dark,
        textScale: 1.6,
        signedIn: true,
        size: const Size(320, 1400),
      );
    });
  });

  // ── Release visibility ────────────────────────────────────────────────────
  //
  // The "Game data" section is absent by default (the harness serves the hidden
  // response), so every pre-existing golden above doubles as proof that a hidden
  // policy leaves Profile untouched. These four capture the visible states.
  group('release visibility', () {
    final resolved = ResolvedRelease(
      releaseId: const Gated<String>.of('siyak-ar-lexicon-v003-ar-iq'),
      displayName: 'Arabic Iraqi v003',
      datasetVersion: const Gated<String>.of('arabic-lexicon-v003'),
      language: 'ar',
      pack: const Gated<String>.of('ar-IQ'),
      status: 'active',
    );

    ReleaseVisibility visible({bool changed = false}) => ReleaseVisibility(
      visible: true,
      scope: ReleaseVisibilityScope.internalTesters,
      resolvedRelease: resolved,
      currentGameRelease: changed
          ? const CurrentGameRelease(
              releaseId: Gated<String>.of('siyak-ar-lexicon-v002-ar-iq'),
              displayName: 'Arabic Iraqi v002',
              pinned: true,
            )
          : const CurrentGameRelease(
              releaseId: Gated<String>.of('siyak-ar-lexicon-v003-ar-iq'),
              displayName: 'Arabic Iraqi v003',
              pinned: true,
            ),
      releaseChangedForNewGames: changed,
    );

    testWidgets('visible · dark · Arabic', (t) async {
      await shoot(
        t,
        'profile_release_visible_dark_ar',
        brightness: Brightness.dark,
        size: const Size(390, 1500),
        releaseVisibility: FakeReleaseVisibilityRepository(value: visible()),
      );
    });

    testWidgets('visible · light · English', (t) async {
      await shoot(
        t,
        'profile_release_visible_light_en',
        brightness: Brightness.light,
        lang: 'en',
        size: const Size(390, 1500),
        releaseVisibility: FakeReleaseVisibilityRepository(value: visible()),
      );
    });

    testWidgets('changed release · dark · Arabic', (t) async {
      await shoot(
        t,
        'profile_release_changed_dark_ar',
        brightness: Brightness.dark,
        size: const Size(390, 1500),
        releaseVisibility: FakeReleaseVisibilityRepository(
          value: visible(changed: true),
        ),
      );
    });

    testWidgets('legacy unknown current game · light · English', (t) async {
      await shoot(
        t,
        'profile_release_legacy_light_en',
        brightness: Brightness.light,
        lang: 'en',
        size: const Size(390, 1500),
        releaseVisibility: FakeReleaseVisibilityRepository(
          value: ReleaseVisibility(
            visible: true,
            resolvedRelease: resolved,
            currentGameRelease: const CurrentGameRelease(
              releaseId: Gated<String>.of(null),
              unknownRelease: true,
            ),
          ),
        ),
      );
    });

    testWidgets('hidden · section absent · dark · Arabic', (t) async {
      await shoot(
        t,
        'profile_release_hidden_dark_ar',
        brightness: Brightness.dark,
        size: const Size(390, 1500),
        releaseVisibility: FakeReleaseVisibilityRepository(),
      );
    });
  });
}
