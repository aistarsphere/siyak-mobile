import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'siyag_theme.dart';

/// Single dark theme — the Siyag charcoal system (Figma Make handoff).
class AppTheme {
  AppTheme._();

  static const systemUiStyle = SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    statusBarBrightness: Brightness.dark,
    systemNavigationBarColor: SC.bg,
    systemNavigationBarIconBrightness: Brightness.light,
  );

  static ThemeData get dark {
    const scheme = ColorScheme(
      brightness: Brightness.dark,
      primary: SC.coral,
      onPrimary: SC.bg,
      secondary: SC.cyan,
      onSecondary: SC.bg,
      tertiary: SC.emerald,
      onTertiary: SC.bg,
      error: Color(0xFFFF4436),
      onError: SC.bg,
      surface: SC.bg,
      onSurface: SC.text,
      surfaceContainerHighest: SC.surfaceHi,
      surfaceContainerHigh: SC.surfaceHi,
      surfaceContainer: SC.surface,
      surfaceContainerLow: SC.surface,
      surfaceContainerLowest: SC.bg,
      onSurfaceVariant: SC.textDim,
      outline: SC.textFaint,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: SC.bg,
      fontFamily: SF.sys,
      splashFactory: InkSparkle.splashFactory,
      textSelectionTheme: const TextSelectionThemeData(
        cursorColor: SC.coral,
        selectionHandleColor: SC.coral,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: SC.surfaceHi,
        contentTextStyle: ST.ar(14, color: SC.text),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(builders: {
        TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
        TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
      }),
    );
  }
}
