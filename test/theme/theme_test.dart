import 'package:context_game/core/design/theme/context_tokens.dart';
import 'package:context_game/core/design/theme/legacy_type_bridge.dart';
import 'package:context_game/core/design/theme/siyaq_theme_data.dart';
import 'package:context_game/core/design/tokens/siyaq_colors.dart';
import 'package:context_game/core/design/tokens/siyaq_typography.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Future<ProviderContainer> _container() async {
  final prefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );
}

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('theme mode persistence', () {
    test('defaults to system', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      addTearDown(c.dispose);
      expect(c.read(appSettingsProvider).themeMode, ThemeMode.system);
    });

    test('setThemeMode updates state and persists across a rebuild', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      addTearDown(c.dispose);
      c.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.dark);
      expect(c.read(appSettingsProvider).themeMode, ThemeMode.dark);

      final c2 = await _container();
      addTearDown(c2.dispose);
      expect(c2.read(appSettingsProvider).themeMode, ThemeMode.dark);
    });

    test('light selection persists', () async {
      SharedPreferences.setMockInitialValues({});
      final c = await _container();
      addTearDown(c.dispose);
      c.read(appSettingsProvider.notifier).setThemeMode(ThemeMode.light);
      final c2 = await _container();
      addTearDown(c2.dispose);
      expect(c2.read(appSettingsProvider).themeMode, ThemeMode.light);
    });
  });

  group('semantic tokens', () {
    test('light and dark are distinct graphite identities', () {
      expect(SiyaqColors.light.background, const Color(0xFFF7F5F0));
      expect(SiyaqColors.dark.background, const Color(0xFF17191E));
      expect(SiyaqColors.light.brightness, Brightness.light);
      expect(SiyaqColors.dark.brightness, Brightness.dark);
    });

    test('gold is the PRIMARY interaction colour with dark text on it', () {
      expect(SiyaqColors.light.primary, SiyaqColors.goldLight);
      expect(SiyaqColors.dark.primary, SiyaqColors.goldDark);
      expect(SiyaqColors.dark.onPrimary.computeLuminance(), lessThan(0.2));
      expect(SiyaqColors.light.onPrimary.computeLuminance(), lessThan(0.2));
    });

    test('surface hierarchy is clearly separated (dark)', () {
      final d = SiyaqColors.dark;
      double lum(Color c) => c.computeLuminance();
      expect(lum(d.surface), greaterThan(lum(d.background)));
      expect(lum(d.surfaceElevated), greaterThan(lum(d.surface)));
      expect(lum(d.surfaceStrong), greaterThan(lum(d.surfaceElevated)));
    });

    test('onAction meets WCAG AA on the primary fill in BOTH themes', () {
      for (final c in [SiyaqColors.light, SiyaqColors.dark]) {
        expect(
          _contrast(c.onAction, c.primary),
          greaterThanOrEqualTo(4.5),
          reason: '${c.brightness} onAction must pass AA on primary',
        );
      }
    });

    test('destructive and secondary actions meet AA on their fills', () {
      for (final c in [SiyaqColors.light, SiyaqColors.dark]) {
        expect(
          _contrast(c.onActionDestructive, c.actionDestructive),
          greaterThanOrEqualTo(4.5),
        );
        expect(
          _contrast(c.onActionSecondary, c.actionSecondary),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('body text meets AA on background and surface in both themes', () {
      for (final c in [SiyaqColors.light, SiyaqColors.dark]) {
        expect(
          _contrast(c.textPrimary, c.background),
          greaterThanOrEqualTo(4.5),
        );
        expect(_contrast(c.textPrimary, c.surface), greaterThanOrEqualTo(4.5));
        expect(
          _contrast(c.textSecondary, c.background),
          greaterThanOrEqualTo(4.5),
        );
      }
    });

    test('game-mode accents stay distinct from status colours', () {
      // Figma reuses one palette for both, making a ranked surface identical to
      // an error surface (audit §11-10). These must not collide.
      for (final c in [SiyaqColors.light, SiyaqColors.dark]) {
        expect(c.gameRanked, isNot(c.error));
        expect(c.gamePractice, isNot(c.success));
        expect(c.gameMultiplayer, isNot(c.info));
      }
    });

    test('foregroundOn picks the higher-contrast foreground', () {
      final c = SiyaqColors.dark;
      for (final fill in [
        c.primary,
        c.success,
        c.error,
        c.info,
        c.gameWeekly,
        SiyaqColors.distanceCorrect,
      ]) {
        final fg = c.foregroundOn(fill);
        final other = fg == SiyaqColors.graphiteDeep
            ? const Color(0xFFF5F6F8)
            : SiyaqColors.graphiteDeep;
        expect(
          _contrast(fg, fill),
          greaterThanOrEqualTo(_contrast(other, fill)),
        );
      }
    });

    test('onColorLegacy reproduces the OLD threshold behaviour exactly', () {
      // Locked so the Phase 1 migration is provably pixel-identical. The rule is
      // knowingly wrong in Light theme (light gold luminance 0.397 < 0.42 → light
      // text, 2.19:1); fixed when components adopt onAction in Phase 3.
      final d = SiyaqColors.dark;
      expect(d.onColorLegacy(d.primary), SiyaqColors.graphiteDeep);
      expect(
        d.onColorLegacy(const Color(0xFF353A42)).computeLuminance(),
        greaterThan(0.5),
      );
      final l = SiyaqColors.light;
      expect(l.onColorLegacy(l.primary).computeLuminance(), greaterThan(0.5));
    });
  });

  group('typography', () {
    test('roles carry the line-height and tracking bound in Figma', () {
      expect(SiyaqTextRole.bodyLarge.size, 16);
      expect(SiyaqTextRole.bodyLarge.latinHeight, 1.5); // 24/16
      expect(SiyaqTextRole.labelSmall.latinTracking, 0.3);
      expect(SiyaqTextRole.gameDistance.size, 20);
      expect(SiyaqTextRole.gameDistance.latinHeight, 1.4); // 28/20
    });

    test('Arabic gets looser leading and NO tracking (cursive joining)', () {
      const t = SiyaqTypography(
        script: SiyaqScript.arabic,
        defaultColor: Color(0xFF000000),
      );
      final ar = t.role(SiyaqTextRole.labelSmall);
      expect(ar.fontFamily, SiyaqFonts.arabic);
      expect(
        ar.letterSpacing,
        isNull,
        reason: 'tracking breaks Arabic joining',
      );
      expect(ar.height, SiyaqTextRole.labelSmall.arabicHeight);
      expect(ar.height, greaterThan(SiyaqTextRole.labelSmall.latinHeight));

      final en = t.role(SiyaqTextRole.labelSmall, script: SiyaqScript.latin);
      expect(en.fontFamily, SiyaqFonts.latin);
      expect(en.letterSpacing, 0.3);
    });

    test('script is chosen from the locale', () {
      expect(SiyaqTypography.scriptForLocale('ar'), SiyaqScript.arabic);
      expect(SiyaqTypography.scriptForLocale('en'), SiyaqScript.latin);
    });
  });

  group('theme data', () {
    test('both themes register colours + typography and a gold primary', () {
      for (final theme in [SiyaqThemeData.light(), SiyaqThemeData.dark()]) {
        final c = theme.extension<SiyaqColors>();
        expect(c, isNotNull);
        expect(theme.extension<SiyaqTypography>(), isNotNull);
        expect(theme.colorScheme.primary, c!.primary);
        // Surfaces stay neutral graphite — no bluish navy from a generated seed.
        final s = theme.colorScheme.surface;
        expect(
          s.b - (s.r + s.g) / 2,
          lessThan(0.06),
          reason: 'surface must not be bluish',
        );
      }
    });

    test('focus ring colour is themed, satisfying the 2px focus rule', () {
      expect(
        SiyaqThemeData.light().inputDecorationTheme.focusedBorder,
        isA<OutlineInputBorder>(),
      );
      for (final c in [SiyaqColors.light, SiyaqColors.dark]) {
        expect(c.borderFocus, isNotNull);
      }
    });
  });

  group('context-based access (no global state)', () {
    testWidgets('resolves from the enclosing Theme, not a global', (t) async {
      late SiyaqColors outer, inner;
      await t.pumpWidget(
        MaterialApp(
          theme: SiyaqThemeData.dark(),
          home: Builder(
            builder: (ctxDark) {
              outer = ctxDark.colors;
              return Theme(
                data: SiyaqThemeData.light(),
                child: Builder(
                  builder: (ctxLight) {
                    inner = ctxLight.colors;
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );
      // The whole point of the refactor: two brightnesses in ONE tree.
      expect(outer.brightness, Brightness.dark);
      expect(inner.brightness, Brightness.light);
      expect(outer.background, isNot(inner.background));
    });

    testWidgets(
      'legacy type bridge is metric-identical to the old ST helpers',
      (t) async {
        late TextStyle ar, mono, sys;
        await t.pumpWidget(
          MaterialApp(
            theme: SiyaqThemeData.dark(),
            home: Builder(
              builder: (ctx) {
                ar = ctx.legacyType.ar(13);
                mono = ctx.legacyType.mono(10, letterSpacing: 1.8);
                sys = ctx.legacyType.sys(15, weight: FontWeight.w600);
                return const SizedBox();
              },
            ),
          ),
        );
        // Old ST.ar(13): Naskh, 13px, w400, colour = textPrimary, height null.
        expect(ar.fontFamily, SiyaqFonts.arabic);
        expect(ar.fontSize, 13);
        expect(ar.fontWeight, FontWeight.w400);
        expect(ar.height, isNull, reason: 'ST.ar defaulted to no line-height');
        expect(ar.color, SiyaqColors.dark.textPrimary);

        expect(mono.fontFamily, SiyaqFonts.mono);
        expect(mono.letterSpacing, 1.8);
        expect(sys.fontFamily, SiyaqFonts.latin);
        expect(sys.fontWeight, FontWeight.w600);
      },
    );

    testWidgets('a dark subtree inside a light app keeps its own palette', (
      t,
    ) async {
      late Color seen;
      await t.pumpWidget(
        MaterialApp(
          theme: SiyaqThemeData.light(),
          home: Theme(
            data: SiyaqThemeData.dark(),
            child: Builder(
              builder: (ctx) {
                seen = ctx.colors.background;
                return const SizedBox();
              },
            ),
          ),
        ),
      );
      expect(seen, SiyaqColors.dark.background);
    });
  });
}
