import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'core/design/gallery/design_system_gallery.dart';
import 'core/design/theme/siyaq_theme_data.dart';

/// Debug entry point for the design-system gallery.
///
/// Deliberately a **separate target** rather than a button inside the app, so no
/// production screen is touched to make the gallery reachable:
///
/// ```sh
/// flutter run -t lib/main_gallery.dart
/// ```
///
/// It boots no Riverpod container, no Firebase, no notifications and no network
/// — the gallery renders the token layer only, so it starts instantly and cannot
/// affect app state.
void main() {
  runApp(const _GalleryApp());
}

class _GalleryApp extends StatelessWidget {
  const _GalleryApp();

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Siyaq Design System',
    debugShowCheckedModeBanner: false,
    theme: SiyaqThemeData.light(),
    darkTheme: SiyaqThemeData.dark(),
    themeMode: ThemeMode.dark,
    locale: const Locale('ar'),
    supportedLocales: const [Locale('ar'), Locale('en')],
    localizationsDelegates: const [
      GlobalMaterialLocalizations.delegate,
      GlobalWidgetsLocalizations.delegate,
      GlobalCupertinoLocalizations.delegate,
    ],
    home: const DesignSystemGallery(),
  );
}
