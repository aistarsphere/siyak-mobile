import 'package:flutter/material.dart' show ThemeMode;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/localization/app_localizations.dart';

class AppSettings {
  const AppSettings({
    this.lang = 'ar',
    this.sound = true,
    this.haptics = true,
    this.themeMode = ThemeMode.system,
    this.baseUrlOverride = '',
  });

  final String lang; // 'ar' | 'en' — Arabic-first
  final bool sound;
  final bool haptics;

  /// System / Light / Dark. Persisted; restored on launch.
  final ThemeMode themeMode;

  /// Developer-only override; empty means use --dart-define / default.
  final String baseUrlOverride;

  String get effectiveBaseUrl => AppConfig.resolveBaseUrl(baseUrlOverride);

  AppSettings copyWith({
    String? lang,
    bool? sound,
    bool? haptics,
    ThemeMode? themeMode,
    String? baseUrlOverride,
  }) => AppSettings(
    lang: lang ?? this.lang,
    sound: sound ?? this.sound,
    haptics: haptics ?? this.haptics,
    themeMode: themeMode ?? this.themeMode,
    baseUrlOverride: baseUrlOverride ?? this.baseUrlOverride,
  );
}

/// Loaded synchronously at startup (main.dart) and overridden in the scope.
final sharedPreferencesProvider = Provider<SharedPreferences>(
  (ref) => throw UnimplementedError('overridden in main'),
);

class AppSettingsController extends Notifier<AppSettings> {
  static const _kLang = 'siyaq.lang';
  static const _kSound = 'siyaq.sound';
  static const _kHaptics = 'siyaq.haptics';
  static const _kThemeMode = 'siyaq.themeMode';
  static const _kBaseUrl = 'siyaq.baseUrlOverride';

  @override
  AppSettings build() {
    final sp = ref.watch(sharedPreferencesProvider);
    return AppSettings(
      lang: sp.getString(_kLang) ?? 'ar',
      sound: sp.getBool(_kSound) ?? true,
      haptics: sp.getBool(_kHaptics) ?? true,
      themeMode: _parseThemeMode(sp.getString(_kThemeMode)),
      baseUrlOverride: sp.getString(_kBaseUrl) ?? '',
    );
  }

  static ThemeMode _parseThemeMode(String? v) => switch (v) {
    'light' => ThemeMode.light,
    'dark' => ThemeMode.dark,
    _ => ThemeMode.system,
  };

  SharedPreferences get _sp => ref.read(sharedPreferencesProvider);

  void setThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _sp.setString(_kThemeMode, mode.name);
  }

  void setLang(String lang) {
    state = state.copyWith(lang: lang);
    _sp.setString(_kLang, lang);
  }

  void toggleLang() => setLang(state.lang == 'ar' ? 'en' : 'ar');

  void setSound(bool v) {
    state = state.copyWith(sound: v);
    _sp.setBool(_kSound, v);
  }

  void setHaptics(bool v) {
    state = state.copyWith(haptics: v);
    _sp.setBool(_kHaptics, v);
  }

  void setBaseUrlOverride(String url) {
    state = state.copyWith(baseUrlOverride: url.trim());
    _sp.setString(_kBaseUrl, url.trim());
  }
}

final appSettingsProvider =
    NotifierProvider<AppSettingsController, AppSettings>(
      AppSettingsController.new,
    );

final localizationsProvider = Provider<AppLocalizations>(
  (ref) => AppLocalizations(ref.watch(appSettingsProvider).lang),
);
