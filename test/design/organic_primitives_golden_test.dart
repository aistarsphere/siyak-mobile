@Tags(['golden'])
library;

import 'dart:io';

import 'package:context_game/core/design/organic/organic_colors.dart';
import 'package:context_game/core/design/organic/organic_tokens.dart';
import 'package:context_game/core/design/organic/sy_icon.dart';
import 'package:context_game/core/design/organic/organic_type.dart';
import 'package:context_game/core/design/organic/sy_primitives.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_test/flutter_test.dart';

/// Visual record of the Organic primitives, so a token or variant change is seen
/// rather than merely asserted.
///
/// Regenerate deliberately:
/// ```sh
/// flutter test --update-goldens test/design/organic_primitives_golden_test.dart
/// ```
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
  // SyIcons draws from the Lucide500 stroke build, so that is the family the
  // golden must load — loading plain 'Lucide' leaves the glyphs as boxes.
  for (final step in const ['500']) {
    final file = File(_lucideStrokePath(step));
    if (!file.existsSync()) continue;
    // With `fontPackage` set, Flutter resolves the family as
    // `packages/<package>/<family>`, so the loader must register that exact name
    // — registering the bare family leaves the glyphs as boxes.
    final loader = FontLoader('packages/lucide_icons_flutter/Lucide$step')
      ..addFont(file.readAsBytes().then((b) => ByteData.sublistView(b)));
    await loader.load();
  }
}

/// Lucide ships its stroke builds inside the package; locate one in the pub cache
/// so the golden shows real glyphs instead of boxes.
String _lucideStrokePath(String step) {
  final home = Platform.environment['HOME'] ?? '';
  return '$home/.pub-cache/hosted/pub.dev/lucide_icons_flutter-3.1.15/'
      'assets/build_font/LucideVariable-w$step.ttf';
}

Widget _gallery({required Brightness brightness, required String lang}) {
  final c = OrganicColors.of(brightness);
  return MaterialApp(
    debugShowCheckedModeBanner: false,
    locale: Locale(lang),
    supportedLocales: const [Locale('en'), Locale('ar')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    theme: ThemeData(
      extensions: <ThemeExtension<dynamic>>[c],
      scaffoldBackgroundColor: c.background,
    ),
    home: Scaffold(
      backgroundColor: c.background,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(OrganicSpacing.s4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SyKicker(lang == 'ar' ? 'بيانات اللعبة' : 'game data'),
              const SizedBox(height: OrganicSpacing.s3),
              Wrap(
                spacing: OrganicSpacing.s2,
                runSpacing: OrganicSpacing.s2,
                children: [
                  SyButton(
                    label: lang == 'ar' ? 'ابدأ' : 'Start',
                    onPressed: () {},
                    icon: const SyIcon.decorative(
                      icon: SyIcons.submit,
                      size: 16,
                    ),
                  ),
                  SyButton(
                    label: lang == 'ar' ? 'لاحقاً' : 'Later',
                    variant: SyButtonVariant.secondary,
                    onPressed: () {},
                  ),
                  SyButton(
                    label: lang == 'ar' ? 'تخطَّ' : 'Skip',
                    variant: SyButtonVariant.ghost,
                    onPressed: () {},
                  ),
                  SyButton(label: lang == 'ar' ? 'معطّل' : 'Disabled'),
                ],
              ),
              const SizedBox(height: OrganicSpacing.s4),
              Wrap(
                spacing: OrganicSpacing.s2,
                runSpacing: OrganicSpacing.s2,
                children: [
                  SyTag(label: lang == 'ar' ? 'ملامس' : 'Touching'),
                  SyTag(
                    label: lang == 'ar' ? 'قريب' : 'Related',
                    variant: SyTagVariant.accent2,
                  ),
                  SyTag(
                    label: lang == 'ar' ? 'بعيد' : 'Distant',
                    variant: SyTagVariant.neutral,
                  ),
                  SyTag(
                    label: lang == 'ar' ? 'وشيك' : 'Near',
                    variant: SyTagVariant.outline,
                  ),
                ],
              ),
              const SizedBox(height: OrganicSpacing.s4),
              SyCard(
                elevation: SyElevation.md,
                children: [
                  SyKicker(lang == 'ar' ? 'نسيج اليوم' : "today's weave"),
                  SyCardTitle(
                    lang == 'ar' ? 'التحدي الأسبوعي' : 'Weekly challenge',
                  ),
                  Text(
                    lang == 'ar'
                        ? 'كلمة واحدة، أسبوع كامل.'
                        : 'One word, one whole week.',
                    // Through the type layer, not a raw TextStyle: a bare
                    // TextStyle carries no family and rendered as tofu in the
                    // first version of this golden.
                    style: OrganicTextStyles.resolve(
                      OrganicTextRole.bodySmall,
                      script: OrganicTextStyles.scriptForLanguage(lang),
                      color: c.muted,
                    ),
                  ),
                  SyButton(
                    label: lang == 'ar' ? 'ابدأ التحدي' : 'Start challenge',
                    block: true,
                    onPressed: () {},
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  Future<void> shoot(
    WidgetTester t,
    String name, {
    required Brightness brightness,
    required String lang,
  }) async {
    t.view.physicalSize = const Size(390, 640);
    t.view.devicePixelRatio = 1.0;
    addTearDown(t.view.reset);

    await t.pumpWidget(_gallery(brightness: brightness, lang: lang));
    await t.pumpAndSettle();

    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('goldens/$name.png'),
    );
  }

  testWidgets('primitives · light · English', (t) async {
    await shoot(
      t,
      'organic_primitives_light_en',
      brightness: Brightness.light,
      lang: 'en',
    );
  });

  testWidgets('primitives · night · English', (t) async {
    await shoot(
      t,
      'organic_primitives_night_en',
      brightness: Brightness.dark,
      lang: 'en',
    );
  });

  testWidgets('primitives · light · Arabic RTL', (t) async {
    await shoot(
      t,
      'organic_primitives_light_ar',
      brightness: Brightness.light,
      lang: 'ar',
    );
  });
}
