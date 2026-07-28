import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../tokens/siyaq_colors.dart';
import '../tokens/siyaq_icons.dart';

/// A named closeness band on the heat scale.
///
/// The band exists so closeness is never carried by colour alone: each band has
/// a label and an icon as well as a position on the ramp. A player with a colour
/// vision deficiency, or reading the screen in bright sun, still gets the state.
enum SiyaqHeatBand {
  solved('bandSolved', SiyaqIcons.success),
  blazing('bandBlazing', Icons.local_fire_department_rounded),
  hot('bandHot', Icons.whatshot_rounded),
  warm('bandWarm', Icons.wb_sunny_rounded),
  lukewarm('bandLukewarm', Icons.thermostat_rounded),
  cold('bandCold', Icons.ac_unit_rounded);

  const SiyaqHeatBand(this.labelKey, this.icon);

  /// Localization key of the band's label. Resolve through `AppLocalizations` —
  /// the scale has to read correctly in both app languages.
  final String labelKey;

  final IconData icon;
}

/// Semantic-distance ("heat") scale for gameplay.
///
/// Moved out of the old theme file so that colour is **injected**, not read from
/// a global: [color] takes the solved colour from the caller's
/// `context.colors.success`.
///
/// The ramp is intentionally left continuous (cold → warm → hot) rather than
/// switched to Figma's 5 discrete bands. That change is product decision **D3**
/// (audit §22) and would alter how guesses score, so it stays out of scope.
/// [bandOf] layers *named* bands on top of the continuous ramp for labelling
/// and iconography without changing the ramp itself.
class SiyaqHeat {
  SiyaqHeat._();

  static const cold = SiyaqColors.heatCold;
  static const warm = SiyaqColors.heatWarm;
  static const hot = SiyaqColors.heatHot;

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

  /// The named band for `heat` in 0..1.
  ///
  /// Thresholds are the ones the game shipped with, so the wording a returning
  /// player recognises is unchanged — only its language is now resolved.
  static SiyaqHeatBand bandOf(double heat, {bool solved = false}) {
    if (solved) return SiyaqHeatBand.solved;
    if (heat >= 0.85) return SiyaqHeatBand.blazing;
    if (heat >= 0.65) return SiyaqHeatBand.hot;
    if (heat >= 0.45) return SiyaqHeatBand.warm;
    if (heat >= 0.25) return SiyaqHeatBand.lukewarm;
    return SiyaqHeatBand.cold;
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

  /// Localization key of the short progress message shown after a guess.
  ///
  /// Returns a key rather than a string: this used to emit hardcoded Arabic
  /// regardless of the app language (audit §7).
  static String progressKey(double? prevBest, double newBest) {
    if (prevBest == null) return 'progFirst';
    if (newBest > prevBest + 0.001) {
      if (newBest >= 0.85) return 'progBlazing';
      if (newBest >= 0.65) return 'progCloser';
      return 'progWarmer';
    }
    return 'progKeepTrying';
  }
}
