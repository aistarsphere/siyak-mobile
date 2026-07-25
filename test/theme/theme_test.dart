import 'package:context_game/core/theme/app_theme.dart';
import 'package:context_game/core/theme/app_tokens.dart';
import 'package:context_game/core/theme/siyag_theme.dart';
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

      // A fresh container backed by the same (now-written) prefs restores it.
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
    test('light and dark palettes are distinct graphite identities', () {
      expect(AppTokens.light.background, const Color(0xFFF7F5F0));
      expect(AppTokens.dark.background, const Color(0xFF17191E));
      expect(AppTokens.light.brightness, Brightness.light);
      expect(AppTokens.dark.brightness, Brightness.dark);
    });

    test('gold is the PRIMARY interaction color with dark text on it', () {
      expect(AppTokens.light.primary, AppTokens.goldLight);
      expect(AppTokens.dark.primary, AppTokens.goldDark);
      // dark-graphite foreground → readable on gold
      expect(AppTokens.dark.onPrimary.computeLuminance(), lessThan(0.2));
      expect(AppTokens.light.onPrimary.computeLuminance(), lessThan(0.2));
    });

    test('SC.applyBrightness swaps the active token set', () {
      SC.applyBrightness(Brightness.dark);
      expect(SC.bg, AppTokens.dark.background);
      expect(SC.coral, AppTokens.dark.primary); // legacy name → gold primary
      SC.applyBrightness(Brightness.light);
      expect(SC.bg, AppTokens.light.background);
      addTearDown(() => SC.applyBrightness(Brightness.dark));
    });

    test('onColor picks dark text on gold, light text on graphite', () {
      SC.applyBrightness(Brightness.dark);
      expect(
        SC.onColor(AppTokens.dark.primary).computeLuminance(),
        lessThan(0.2),
      );
      expect(
        SC.onColor(const Color(0xFF353A42)).computeLuminance(),
        greaterThan(0.5),
      );
    });

    test('surface hierarchy is clearly separated (dark)', () {
      final d = AppTokens.dark;
      double lum(Color c) => c.computeLuminance();
      expect(lum(d.surface), greaterThan(lum(d.background)));
      expect(lum(d.surfaceElevated), greaterThan(lum(d.surface)));
      expect(lum(d.surfaceStrong), greaterThan(lum(d.surfaceElevated)));
    });
  });

  group('themes', () {
    test('both themes register AppTokens and a gold primary; no blue seed', () {
      for (final theme in [AppTheme.light, AppTheme.dark]) {
        final t = theme.extension<AppTokens>();
        expect(t, isNotNull);
        expect(theme.colorScheme.primary, t!.primary);
        // Surfaces stay neutral graphite — blue channel not dominant (no navy).
        final s = theme.colorScheme.surface;
        expect(
          s.b - (s.r + s.g) / 2,
          lessThan(0.06),
          reason: 'surface must not be bluish',
        );
      }
    });
  });
}
