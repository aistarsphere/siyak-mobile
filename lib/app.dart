import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/theme/app_theme.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';
import 'features/game/presentation/screens/splash_screen.dart';

class SiyaqApp extends ConsumerWidget {
  const SiyaqApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
    SystemChrome.setSystemUIOverlayStyle(AppTheme.systemUiStyle);

    return MaterialApp(
      title: 'لعبة السياق',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.dark,
      locale: Locale(lang),
      supportedLocales: const [Locale('ar'), Locale('en')],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: const SplashScreen(),
    );
  }
}
