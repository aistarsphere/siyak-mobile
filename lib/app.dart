import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'core/theme/siyag_theme.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';
import 'features/siyag/presentation/siyag_shell.dart';

class SiyagApp extends ConsumerWidget {
  const SiyagApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));

    // Resolve the effective brightness (System follows the platform) and point
    // the custom-screen token accessor (SC) at it BEFORE the subtree builds.
    // Depending on platformBrightness rebuilds this on OS light/dark changes.
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final effective = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    SC.applyBrightness(effective);
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiStyleFor(effective));

    return MaterialApp(
      title: 'سياق',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light,
      darkTheme: AppTheme.dark,
      themeMode: mode,
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SiyagShell(),
    );
  }
}
