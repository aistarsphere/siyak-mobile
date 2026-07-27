import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../tokens/siyaq_colors.dart';
import '../tokens/siyaq_spacing.dart';
import '../tokens/siyaq_typography.dart';

/// Builds [ThemeData] from the semantic token layer.
///
/// Both [SiyaqColors] and [SiyaqTypography] are registered as theme extensions,
/// so `context.colors` / `context.type` resolve from wherever a widget sits —
/// including inside a nested [Theme] of the opposite brightness.
///
/// The `ColorScheme` is configured explicitly (no `fromSeed`) so Material
/// components share the graphite/gold identity exactly and no generated
/// blue/indigo can leak in.
class SiyaqThemeData {
  SiyaqThemeData._();

  /// Theme for [brightness], with typography shaped for [script].
  ///
  /// [script] should follow the active locale so Material widgets inherit the
  /// right font family; pass it explicitly in previews to force a script.
  static ThemeData of(
    Brightness brightness, {
    SiyaqScript script = SiyaqScript.arabic,
  }) {
    final c = SiyaqColors.of(brightness);
    final t = SiyaqTypography(script: script, defaultColor: c.textPrimary);
    return _build(c, t);
  }

  static ThemeData light({SiyaqScript script = SiyaqScript.arabic}) =>
      of(Brightness.light, script: script);

  static ThemeData dark({SiyaqScript script = SiyaqScript.arabic}) =>
      of(Brightness.dark, script: script);

  static SystemUiOverlayStyle systemUiStyleFor(Brightness b) {
    final c = SiyaqColors.of(b);
    final isDark = b == Brightness.dark;
    return SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: isDark ? Brightness.light : Brightness.dark,
      statusBarBrightness: isDark ? Brightness.dark : Brightness.light,
      systemNavigationBarColor: c.background,
      systemNavigationBarIconBrightness: isDark
          ? Brightness.light
          : Brightness.dark,
    );
  }

  static ThemeData _build(SiyaqColors c, SiyaqTypography t) {
    final scheme = ColorScheme(
      brightness: c.brightness,
      primary: c.primary,
      onPrimary: c.onPrimary,
      primaryContainer: c.primaryContainer,
      onPrimaryContainer: c.primary,
      secondary: c.primary,
      onSecondary: c.onPrimary,
      tertiary: c.info,
      onTertiary: c.onPrimary,
      error: c.error,
      onError: c.onActionDestructive,
      surface: c.surface,
      onSurface: c.textPrimary,
      surfaceContainerHighest: c.surfaceStrong,
      surfaceContainerHigh: c.surfaceElevated,
      surfaceContainer: c.surface,
      surfaceContainerLow: c.surface,
      surfaceContainerLowest: c.background,
      onSurfaceVariant: c.textSecondary,
      outline: c.border,
      outlineVariant: c.divider,
      shadow: c.shadow,
      scrim: c.scrim,
    );

    return ThemeData(
      useMaterial3: true,
      brightness: c.brightness,
      colorScheme: scheme,
      extensions: [c, t],
      scaffoldBackgroundColor: c.background,
      canvasColor: c.background,
      fontFamily: SiyaqFonts.latin,
      textTheme: t.toTextTheme(),
      splashFactory: InkSparkle.splashFactory,
      dividerColor: c.divider,
      iconTheme: IconThemeData(color: c.iconPrimary),
      appBarTheme: AppBarTheme(
        backgroundColor: c.background,
        foregroundColor: c.textPrimary,
        elevation: 0,
        scrolledUnderElevation: 0,
      ),
      cardTheme: CardThemeData(
        color: c.surface,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SiyaqRadius.xxl),
          side: BorderSide(color: c.border),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        titleTextStyle: t.role(
          SiyaqTextRole.headingSmall,
          weight: FontWeight.w700,
        ),
        contentTextStyle: t.role(
          SiyaqTextRole.bodyMedium,
          color: c.textSecondary,
        ),
      ),
      bottomSheetTheme: BottomSheetThemeData(
        backgroundColor: c.surface,
        surfaceTintColor: Colors.transparent,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(
            top: Radius.circular(SiyaqRadius.xxxl),
          ),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: c.background,
        surfaceTintColor: Colors.transparent,
        indicatorColor: c.surfaceElevated,
      ),
      textSelectionTheme: TextSelectionThemeData(
        cursorColor: c.primary,
        selectionHandleColor: c.primary,
        selectionColor: c.primary.withValues(alpha: 0.24),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: c.surface,
        hintStyle: t.role(SiyaqTextRole.bodyMedium, color: c.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SiyaqRadius.xl),
          borderSide: BorderSide(color: c.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SiyaqRadius.xl),
          borderSide: BorderSide(color: c.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(SiyaqRadius.xl),
          borderSide: BorderSide(color: c.borderFocus, width: 2),
        ),
      ),
      chipTheme: ChipThemeData(
        backgroundColor: c.surfaceElevated,
        side: BorderSide(color: c.border),
        labelStyle: t.role(SiyaqTextRole.bodySmall, color: c.textSecondary),
      ),
      switchTheme: SwitchThemeData(
        thumbColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected) ? c.primary : c.textMuted,
        ),
        trackColor: WidgetStateProperty.resolveWith(
          (s) => s.contains(WidgetState.selected)
              ? c.primary.withValues(alpha: 0.35)
              : c.surfaceElevated,
        ),
      ),
      progressIndicatorTheme: ProgressIndicatorThemeData(color: c.primary),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: c.surfaceElevated,
        contentTextStyle: t.role(SiyaqTextRole.bodyMedium),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(SiyaqRadius.xl),
        ),
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
