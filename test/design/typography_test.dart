import 'dart:io';
import 'package:context_game/core/design/siyaq_design.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the script-aware font stack.
///
/// Inter ships as one *variable* asset, so `fontWeight` alone does not move its
/// `wght` axis — the type layer has to emit `fontVariations`. If that is ever
/// dropped, or Inter is swapped for a static family, the whole Latin type scale
/// silently flattens to a single weight with no other test noticing.
void main() {
  setUpAll(() async {
    final l = FontLoader('Inter')
      ..addFont(
        File(
          'assets/fonts/siyag/Inter.ttf',
        ).readAsBytes().then((b) => ByteData.sublistView(b)),
      );
    await l.load();
  });

  test('Inter variable wght axis is actually driven by the type layer', () {
    const type = SiyaqTypography(
      script: SiyaqScript.latin,
      defaultColor: Color(0xFF000000),
    );
    final light = type.role(SiyaqTextRole.bodyLarge, weight: FontWeight.w400);
    final heavy = type.role(SiyaqTextRole.bodyLarge, weight: FontWeight.w700);

    expect(light.fontFamily, 'Inter');
    expect(
      light.fontVariations,
      isNotNull,
      reason: 'a variable family must carry an explicit wght axis',
    );
    expect(light.fontVariations!.single.value, 400);
    expect(heavy.fontVariations!.single.value, 700);

    // Arabic is static: the file per weight already selects the design.
    final ar = type.role(
      SiyaqTextRole.bodyLarge,
      script: SiyaqScript.arabic,
      weight: FontWeight.w700,
    );
    expect(ar.fontFamily, 'IBMPlexSansArabic');
    expect(ar.fontVariations, isNull);
    expect(ar.fontFamilyFallback, contains('NotoNaskhArabic'));
  });

  testWidgets('w400 and w700 really paint at different widths', (t) async {
    Future<double> widthAt(FontWeight w) async {
      final key = GlobalKey();
      await t.pumpWidget(
        MaterialApp(
          home: Center(
            child: Text(
              'Handgloves 12345',
              key: key,
              style: const SiyaqTypography(
                script: SiyaqScript.latin,
                defaultColor: Color(0xFF000000),
              ).role(SiyaqTextRole.displayMedium, weight: w),
            ),
          ),
        ),
      );
      return t.getSize(find.byKey(key)).width;
    }

    final thin = await widthAt(FontWeight.w400);
    final bold = await widthAt(FontWeight.w700);
    // A live wght axis changes advance widths; an ignored one would not.
    expect(
      bold,
      greaterThan(thin),
      reason: 'variable axis appears inert — Inter is rendering one weight',
    );
  });
}
