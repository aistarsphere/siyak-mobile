import 'dart:math' as math;

import 'package:flutter/material.dart';

/// ─── Siyag design system ──────────────────────────────────────────────────
/// Ported verbatim from the Figma Make handoff `reference_web/src/app/theme.ts`.
/// Modern game palette: charcoal/graphite surfaces, coral-orange primary,
/// electric-cyan secondary, emerald success, warm-neutral text.
/// No blue/indigo, no amber/gold, no gradients-as-identity.
class SC {
  SC._();

  // Canvas behind the phone frame (App.tsx outer bg)
  static const outer = Color(0xFF0C0C0D);

  // Surfaces (charcoal → graphite)
  static const bg = Color(0xFF141416);
  static const surface = Color(0xFF1D1E22);
  static const surfaceHi = Color(0xFF26272C);
  static const surfaceHover = Color(0xFF2E2F35);
  static Color get line => Colors.white.withValues(alpha: 0.06);
  static Color get lineStrong => Colors.white.withValues(alpha: 0.10);

  // Text (warm neutrals)
  static const text = Color(0xFFF1ECE3);
  static const textDim = Color(0xFFB4AEA3);
  static const textMute = Color(0xFF7C7770);
  static const textFaint = Color(0xFF4E4B46);

  // Brand
  static const coral = Color(0xFFFF6B4A);
  static Color get coralDim => const Color(0xFFFF6B4A).withValues(alpha: 0.14);
  static const cyan = Color(0xFF2DD4E8);
  static Color get cyanDim => const Color(0xFF2DD4E8).withValues(alpha: 0.14);
  static const emerald = Color(0xFF34D399);
  static Color get emeraldDim =>
      const Color(0xFF34D399).withValues(alpha: 0.14);
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
          Color color = SC.text,
          double? height}) =>
      TextStyle(
        fontFamily: SF.ar,
        fontSize: size,
        fontWeight: weight,
        color: color,
        height: height,
      );

  static TextStyle mono(double size,
          {FontWeight weight = FontWeight.w400,
          Color color = SC.text,
          double letterSpacing = 0}) =>
      TextStyle(
        fontFamily: SF.mono,
        fontSize: size,
        fontWeight: weight,
        color: color,
        letterSpacing: letterSpacing,
      );

  static TextStyle sys(double size,
          {FontWeight weight = FontWeight.w400, Color color = SC.text}) =>
      TextStyle(
          fontFamily: SF.sys, fontSize: size, fontWeight: weight, color: color);
}
