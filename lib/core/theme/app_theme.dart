import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'app_tokens.dart';
import 'siyag_theme.dart';

/// Siyaq graphite/gold themes — Light + Dark, built from a single [AppTokens]
/// palette so Material components match the custom (SC-based) screens. The
/// `ColorScheme` is configured explicitly so no seed generation reintroduces
/// blue/indigo/purple.
class AppTheme {
  AppTheme._();

  static ThemeData get light => _build(AppTokens.light);
  static ThemeData get dark => _build(AppTokens.dark);

  static SystemUiOverlayStyle systemUiStyleFor(Brightness b) {
    final t = AppTokens.of(b);
    final dark = b == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: dark ? Brightness.light : Brightness.dark,
      statusBarBrightness: dark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: t.background,
      systemNavigationBarIconBrightness: dark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(AppTokens t) {
    final scheme = ColorScheme(
      brightness: t.brightness,
      primary: t.primary,
      onPrimary: t.onPrimary,
      primaryContainer: t.primaryContainer,
      onPrimaryContainer: t.primary,
      secondary: t.primary,
      onSecondary: t.onPrimary,
      tertiary: t.info,
      onTertiary: t.onPrimary,
      error: t.error,
      onError: t.onPrimary,
      surface: t.surface,
      onSurface: t.textPrimary,
      surfaceContainerHighest: t.surfaceStrong,
      surfaceContainerHigh: t.surfaceElevated,
      surfaceContainer: t.surface,
      surfaceContainerLow: t.surface,
      surfaceContainerLowest: t.background,
      onSurfaceVariant: t.textSecondary,
      outline: t.border,
      outlineVariant: t.divider,
      shadow: t.shadow,
      scrim: t.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: t.brightness,
      colorScheme: scheme,
      extensions: [t],
      scaffoldBackgroundColor: t.background,
      canvasColor: t.background,
      fontFamily: SF.sys,
      splashFactory: InkSparkle.splashFactory,
      dividerColor: t.divider,
      iconTheme: IconThemeData(color: t.iconPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: t.background,
        foregroundColor: t.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: t.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(20),
          side: BorderSide(color: t.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: ST.ar(
          18,
          weight: FontWeight.w700,
          color: t.textPrimary,
        ),
        contentTextStyle: ST.ar(14, color: t.textSecondary),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: t.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: t.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: t.surfaceElevated,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: t.primary,
        selectionHandleColor: t.primary,
        selectionColor: t.primary.withValues(alpha: 0.24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: t.surface,
        hintStyle: ST.ar(14, color: t.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(16),
          borderSide: BorderSide(color: t.primary, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: t.surfaceElevated,
        side: BorderSide(color: t.border),
        labelStyle: ST.ar(13, color: t.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? t.primary : t.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? t.primary.withValues(alpha: 0.35)
              : t.surfaceElevated,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: t.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: t.surfaceElevated,
        contentTextStyle: ST.ar(14, color: t.textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      pageTransitionsTheme: const PageTransitionsTheme(
        builders: {
          TargetPlatform.android: FadeForwardsPageTransitionsBuilder(),
          TargetPlatform.iOS: CupertinoPageTransitionsBuilder(),
        },
      ),
    );
  }
}
