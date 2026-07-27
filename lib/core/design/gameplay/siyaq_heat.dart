import 'dart:math' as math;

import 'package:flutter/material.dart';

/// Semantic-distance ("heat") scale for gameplay.
///
/// Moved out of the old theme file so that colour is **injected**, not read from
/// a global: [color] now takes the solved colour from the caller's
/// `context.colors.success`.
///
/// The ramp is intentionally left continuous (cold → warm → hot) rather than
/// switched to Figma's 5 discrete bands. That change is product decision **D3**
/// (audit §22) and would alter gameplay rendering, so it is out of scope here.
///
/// [labelAr] still returns hardcoded Arabic. Moving these strings into the
/// existing 334-key localization tables is Phase 3 work (audit §7) — doing it
/// here would change visible copy in a phase that must stay pixel-identical.
class SiyaqHeat {
  SiyaqHeat._();

  static const cold = Color(0xFF2DD4E8);
  static const warm = Color(0xFFFF8A4A);
  static const hot = Color(0xFFFF4436);

  /// Continuous heat colour for `heat` in 0..1.
  ///
  /// [solvedColor] should come from `context.colors.success`.
  static Color color(
    double heat, {
    bool solved = false,
    required Color solvedColor,
  }) {
    if (solved) return solvedColor;
    final t = heat.clamp(0.0, 1.0);
    if (t < 0.55) return Color.lerp(cold, warm, t / 0.55)!;
    return Color.lerp(warm, hot, (t - 0.55) / 0.45)!;
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

  /// A short progress message shown after a guess.
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
