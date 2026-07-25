import 'dart:math' as math;

import 'package:flutter/material.dart';

import 'app_tokens.dart';

/// ─── Siyaq design tokens (theme-aware) ────────────────────────────────────
/// Graphite/gold brand identity. Every field resolves from the active
/// [AppTokens] palette so the same screens render correctly in Light and Dark.
/// The legacy field names (`coral`, `cyan`, `emerald`) are kept to avoid a
/// mass rename — they now map to graphite/info/success semantics.
class SC {
  SC._();

  static AppTokens _t = AppTokens.dark;
  static AppTokens get tokens => _t;

  /// Point the tokens at the active brightness (called from the app root
  /// before the widget subtree builds, and again whenever the theme changes).
  static void applyBrightness(Brightness b) => _t = AppTokens.of(b);

  // Surfaces
  static Color get outer => _t.background;
  static Color get bg => _t.background;
  static Color get surface => _t.surface;
  static Color get surfaceHi => _t.surfaceAlt;
  static Color get surfaceHover => _t.surfaceAlt;
  static Color get line => _t.border;
  static Color get lineStrong => _t.divider;

  // Text
  static Color get text => _t.textPrimary;
  static Color get textDim => _t.textSecondary;
  static Color get textMute => _t.textMuted;
  static Color get textFaint => _t.disabled;

  // Primary interactive accent → **graphite** (legacy name `coral`).
  static Color get coral => _t.accentPrimary;
  static Color get coralDim => _t.accentPrimary.withValues(alpha: 0.16);
  static Color get onAccent => _t.onAccent;

  // Restrained **gold** accent (premium / achievement / rank / key result).
  static Color get gold => _t.accentGold;
  static Color get goldDim => _t.accentGold.withValues(alpha: 0.16);
  static Color get onGold => _t.onGold;

  // Semantic (legacy names retained)
  static Color get cyan => _t.info; // informational / hint / cold
  static Color get cyanDim => _t.info.withValues(alpha: 0.16);
  static Color get emerald => _t.success; // success / accepted / solved
  static Color get emeraldDim => _t.success.withValues(alpha: 0.16);
  static Color get warning => _t.warning;
  static Color get error => _t.error;

  /// Readable foreground for a filled [fill]: dark graphite text on light fills
  /// (notably the **gold** primary, whose luminance ≈ 0.48), light text on
  /// graphite/green/info fills. Threshold sits below gold so gold → dark text.
  static Color onColor(Color fill) => fill.computeLuminance() > 0.42
      ? AppTokens.graphiteDeep
      : const Color(0xFFF5F6F8);
}

/// Typography families (bundled — no runtime fetch).
class SF {
  SF._();
  static const ar = 'NotoNaskhArabic'; // Arabic game content
  static const mono = 'DMMono'; // ranks / numbers / kicker labels
  static const sys = 'PlusJakartaSans'; // Latin / system base
}

/// Continuous heat scale: cold → cyan, warm → coral-orange, hot → red,
/// solved → emerald. `heat` is 0..1.
class SiyagHeat {
  SiyagHeat._();

  static const _cold = Color(0xFF2DD4E8);
  static const _warm = Color(0xFFFF8A4A);
  static const _hot = Color(0xFFFF4436);

  static Color color(double heat, {bool solved = false}) {
    if (solved) return SC.emerald;
    final t = heat.clamp(0.0, 1.0);
    if (t < 0.55) return Color.lerp(_cold, _warm, t / 0.55)!;
    return Color.lerp(_warm, _hot, (t - 0.55) / 0.45)!;
  }

  /// Arabic heat label (ملتهب/حار/دافئ/فاتر/بارد, or الإجابة when solved).
  static String labelAr(double heat, {bool solved = false}) {
    if (solved) return 'الإجابة';
    if (heat >= 0.85) return 'ملتهب';
    if (heat >= 0.65) return 'حار';
    if (heat >= 0.45) return 'دافئ';
    if (heat >= 0.25) return 'فاتر';
    return 'بارد';
  }

  /// Map a backend rank to a 0..1 heat, given the vocabulary size.
  /// Rank 1 → 1.0 (or solved). Log-scaled so top ranks read hot.
  static double fromRank(int rank, int totalWords, {bool solved = false}) {
    if (solved || rank <= 1) return 1.0;
    final total = math.max(totalWords, 2);
    final r = rank.clamp(1, total);
    final v = 1 - math.log(r) / math.log(total);
    return v.clamp(0.02, 1.0);
  }

  /// A short progress message shown after a guess (theme.ts progressMessage).
  static String progressMessage(double? prevBest, double newBest) {
    if (prevBest == null) return 'أول تخمين — لنبدأ!';
    if (newBest > prevBest + 0.001) {
      if (newBest >= 0.85) return 'دخلت المنطقة الملتهبة! 🔥';
      if (newBest >= 0.65) return 'أقرب من أي وقت مضى!';
      return 'أنت تقترب...';
    }
    return 'استمر — جرّب زاوية أخرى';
  }
}

/// Motion constants (MOTION_SPEC.md + component `transition` values).
class SM {
  SM._();

  /// Route transition: fade + slide y 12→0, 240ms, cubic-bezier(0.22,1,0.36,1).
  static const route = Duration(milliseconds: 240);
  static const easeOutQuint = Cubic(0.22, 1, 0.36, 1);

  static const tap = Duration(milliseconds: 120);
  static const barFill = Duration(milliseconds: 550); // HeatBar
  static const rowIn = Duration(milliseconds: 320); // GuessRow
  static const summaryIn = Duration(milliseconds: 300);
}

/// Text style helpers keyed to the reference's font/size/weight usage.
class ST {
  ST._();

  static TextStyle ar(double size,
          {FontWeight weight = FontWeight.w400,
          Color? color,
          double? height}) =>
      TextStyle(
        fontFamily: SF.ar,
        fontSize: size,
        fontWeight: weight,
        color: color ?? SC.text,
        height: height,
      );

  static TextStyle mono(double size,
          {FontWeight weight = FontWeight.w400,
          Color? color,
          double letterSpacing = 0}) =>
      TextStyle(
        fontFamily: SF.mono,
        fontSize: size,
        fontWeight: weight,
        color: color ?? SC.text,
        letterSpacing: letterSpacing,
      );

  static TextStyle sys(double size,
          {FontWeight weight = FontWeight.w400, Color? color}) =>
      TextStyle(
          fontFamily: SF.sys,
          fontSize: size,
          fontWeight: weight,
          color: color ?? SC.text);
}
