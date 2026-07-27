import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/design/theme/siyaq_theme_data.dart';
import 'core/design/tokens/siyaq_typography.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';
import 'features/siyag/presentation/siyag_shell.dart';

class SiyagApp extends ConsumerWidget {
  const SiyagApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));

    // Resolve the effective brightness (System follows the platform) purely to
    // drive the system UI overlay. Colours themselves are no longer pushed into
    // a global: every widget reads them from the enclosing Theme via
    // `context.colors`, so MaterialApp's own light/dark selection is the single
    // source of truth. Depending on platformBrightness keeps the overlay in sync
    // on OS light/dark changes.
    final platformBrightness = MediaQuery.platformBrightnessOf(context);
    final effective = switch (mode) {
      ThemeMode.light => Brightness.light,
      ThemeMode.dark => Brightness.dark,
      ThemeMode.system => platformBrightness,
    };
    SystemChrome.setSystemUIOverlayStyle(
      SiyaqThemeData.systemUiStyleFor(effective),
    );

    // Typography follows the selected language so Material widgets inherit the
    // right script family; custom widgets can still override per-string.
    final script = SiyaqTypography.scriptForLocale(lang);

    return MaterialApp(
      title: 'سياق',
      debugShowCheckedModeBanner: false,
      theme: SiyaqThemeData.light(script: script),
      darkTheme: SiyaqThemeData.dark(script: script),
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
