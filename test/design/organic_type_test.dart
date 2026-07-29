import 'dart:io';

import 'package:context_game/core/design/organic/organic_tokens.dart';
import 'package:context_game/core/design/organic/organic_type.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Typography guards for the Organic layer.
///
/// The load-bearing one is the variable-axis probe: `fontWeight` alone does not
/// move a variable font's `wght` axis, and this project already shipped that bug
/// once. It is checked by measuring real painted text, not by inspecting the
/// style object.
Future<void> _loadFonts() async {
  const families = <String, List<String>>{
    'Caprasimo': ['assets/fonts/organic/Caprasimo-Regular.ttf'],
    'Figtree': ['assets/fonts/organic/Figtree-Variable.ttf'],
    'BalooBhaijaan2': ['assets/fonts/organic/BalooBhaijaan2-Variable.ttf'],
    'Tajawal': [
      'assets/fonts/organic/Tajawal-Regular.ttf',
      'assets/fonts/organic/Tajawal-Medium.ttf',
      'assets/fonts/organic/Tajawal-Bold.ttf',
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
}

double _width(String text, TextStyle style, {TextDirection? direction}) {
  final painter = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: direction ?? TextDirection.ltr,
  )..layout();
  return painter.width;
}

void main() {
  setUpAll(_loadFonts);

  group('font assets', () {
    test('every declared face is present on disk with its licence', () {
      for (final f in [
        'Caprasimo-Regular.ttf',
        'Figtree-Variable.ttf',
        'BalooBhaijaan2-Variable.ttf',
        'Tajawal-Regular.ttf',
        'Tajawal-Medium.ttf',
        'Tajawal-Bold.ttf',
      ]) {
        final file = File('assets/fonts/organic/$f');
        expect(file.existsSync(), isTrue, reason: '$f missing');
        expect(file.lengthSync(), greaterThan(10000), reason: '$f looks empty');
      }
      for (final l in [
        'OFL-caprasimo.txt',
        'OFL-figtree.txt',
        'OFL-baloobhaijaan2.txt',
        'OFL-tajawal.txt',
      ]) {
        final licence = File('assets/fonts/organic/$l');
        expect(licence.existsSync(), isTrue, reason: '$l missing');
        expect(
          licence.readAsStringSync(),
          contains('SIL Open Font License, Version 1.1'),
          reason: '$l must be OFL 1.1',
        );
      }
    });
  });

  group('script selection', () {
    test('display and body faces switch wholesale by script', () {
      final arHeading = OrganicTextStyles.resolve(
        OrganicTextRole.displayLarge,
        script: OrganicScript.arabic,
      );
      final enHeading = OrganicTextStyles.resolve(
        OrganicTextRole.displayLarge,
        script: OrganicScript.latin,
      );
      expect(arHeading.fontFamily, 'BalooBhaijaan2');
      expect(enHeading.fontFamily, 'Caprasimo');

      final arBody = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.arabic,
      );
      expect(arBody.fontFamily, 'Tajawal');
      expect(
        OrganicTextStyles.resolve(
          OrganicTextRole.bodyLarge,
          script: OrganicScript.latin,
        ).fontFamily,
        'Figtree',
      );
    });

    test('language codes map to scripts', () {
      expect(OrganicTextStyles.scriptForLanguage('ar'), OrganicScript.arabic);
      expect(
        OrganicTextStyles.scriptForLanguage('ar-IQ'),
        OrganicScript.arabic,
      );
      expect(OrganicTextStyles.scriptForLanguage('en'), OrganicScript.latin);
      expect(OrganicTextStyles.scriptForLanguage(null), OrganicScript.latin);
    });
  });

  group('Arabic typographic rules', () {
    test('line-height rises to at least 1.75', () {
      for (final role in OrganicTextRole.values) {
        final ar = OrganicTextStyles.resolve(
          role,
          script: OrganicScript.arabic,
        );
        expect(
          ar.height,
          greaterThanOrEqualTo(OrganicTextStyles.arabicHeight),
          reason: '${role.name} must breathe in Arabic',
        );
      }
    });

    test('a roomier Latin role keeps its own height rather than shrinking', () {
      // bodyLarge is 1.65 in Latin, so Arabic lifts it to 1.75; nothing should
      // ever be pushed *down* by the floor.
      for (final role in OrganicTextRole.values) {
        final latin = OrganicTextStyles.resolve(
          role,
          script: OrganicScript.latin,
        );
        final arabic = OrganicTextStyles.resolve(
          role,
          script: OrganicScript.arabic,
        );
        expect(arabic.height, greaterThanOrEqualTo(latin.height!));
      }
    });

    test('letter-spacing is never applied to Arabic', () {
      for (final role in OrganicTextRole.values) {
        expect(
          OrganicTextStyles.resolve(
            role,
            script: OrganicScript.arabic,
          ).letterSpacing,
          isNull,
          reason: '${role.name} must not track in Arabic',
        );
      }
      // The Latin kicker does carry tracking — otherwise the rule is vacuous.
      expect(
        OrganicTextStyles.resolve(
          OrganicTextRole.kicker,
          script: OrganicScript.latin,
        ).letterSpacing,
        closeTo(1.54, 0.001),
      );
    });

    test('uppercase is refused for Arabic', () {
      expect(OrganicTextStyles.allowsUppercase(OrganicScript.arabic), isFalse);
      expect(OrganicTextStyles.allowsUppercase(OrganicScript.latin), isTrue);
    });
  });

  group('variable axis', () {
    test('variable families carry a wght variation, static ones do not', () {
      final figtree = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.latin,
        weight: FontWeight.w700,
      );
      expect(figtree.fontVariations, isNotNull);
      expect(figtree.fontVariations!.single.axis, 'wght');
      expect(figtree.fontVariations!.single.value, 700);

      // Tajawal ships as static cuts; a variation would fight the shaper.
      final tajawal = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.arabic,
        weight: FontWeight.w700,
      );
      expect(tajawal.fontVariations, isNull);
      expect(tajawal.fontWeight, FontWeight.w700);

      // Caprasimo has one weight only.
      expect(
        OrganicTextStyles.resolve(
          OrganicTextRole.displayLarge,
          script: OrganicScript.latin,
        ).fontVariations,
        isNull,
      );
    });

    test('a weight outside the axis clamps to the range the file carries', () {
      // Baloo Bhaijaan 2 is 400..800, so w900 must clamp rather than fall back.
      final heavy = OrganicTextStyles.resolve(
        OrganicTextRole.displayLarge,
        script: OrganicScript.arabic,
        weight: FontWeight.w900,
      );
      expect(heavy.fontVariations!.single.value, 800);

      // Figtree is 300..900, so w900 passes through.
      final figtree = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.latin,
        weight: FontWeight.w900,
      );
      expect(figtree.fontVariations!.single.value, 900);
    });

    testWidgets('the wght axis genuinely changes painted Latin text', (
      t,
    ) async {
      final light = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.latin,
        weight: FontWeight.w400,
      );
      final bold = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.latin,
        weight: FontWeight.w900,
      );
      // If only fontWeight were set, these would measure identically on a
      // variable font — that is exactly the bug this pins.
      expect(
        _width('Siyaq weaving words', bold),
        greaterThan(_width('Siyaq weaving words', light)),
      );
    });

    testWidgets('the wght axis genuinely changes painted Arabic display text', (
      t,
    ) async {
      final light = OrganicTextStyles.resolve(
        OrganicTextRole.headingSmall,
        script: OrganicScript.arabic,
        weight: FontWeight.w400,
      );
      final bold = OrganicTextStyles.resolve(
        OrganicTextRole.headingSmall,
        script: OrganicScript.arabic,
        weight: FontWeight.w800,
      );
      expect(
        _width('نسيج اليوم', bold, direction: TextDirection.rtl),
        greaterThan(_width('نسيج اليوم', light, direction: TextDirection.rtl)),
      );
    });

    testWidgets('Arabic actually renders — no tofu from a Latin-only face', (
      t,
    ) async {
      // A Latin-only family would fall back or blank; a real Arabic face gives
      // this string meaningful width.
      final arabic = OrganicTextStyles.resolve(
        OrganicTextRole.bodyLarge,
        script: OrganicScript.arabic,
      );
      final width = _width('اكتب كلمة', arabic, direction: TextDirection.rtl);
      expect(width, greaterThan(20));
    });
  });

  group('scale', () {
    test('display roles use the heading face, others the body face', () {
      for (final role in OrganicTextRole.values) {
        final style = OrganicTextStyles.resolve(
          role,
          script: OrganicScript.latin,
        );
        expect(
          style.fontFamily,
          role.display ? OrganicFonts.latinDisplay : OrganicFonts.latinBody,
          reason: role.name,
        );
      }
    });

    test('sizes descend from display to meta and are all positive', () {
      expect(OrganicTextRole.displayLarge.size, 34);
      expect(
        OrganicTextRole.displayLarge.size,
        greaterThan(OrganicTextRole.headingLarge.size),
      );
      expect(
        OrganicTextRole.bodyLarge.size,
        greaterThan(OrganicTextRole.bodySmall.size),
      );
      for (final role in OrganicTextRole.values) {
        expect(role.size, greaterThan(0), reason: role.name);
      }
    });

    test('an explicit size override wins', () {
      expect(
        OrganicTextStyles.resolve(
          OrganicTextRole.bodyLarge,
          script: OrganicScript.latin,
          sizeOverride: 21,
        ).fontSize,
        21,
      );
    });
  });
}
