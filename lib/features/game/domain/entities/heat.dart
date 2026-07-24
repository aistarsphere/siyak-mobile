import 'dart:ui';

import '../../../../core/theme/app_colors.dart';

/// Heat tiers as shown on the Stitch gameplay screen (icon + accent color).
/// The backend is authoritative about closeness: every guess carries a
/// `heat_level` string and a `proximity` (0–100). We map the server's level
/// to a Stitch tier so the Amber Noir palette/icons stay faithful to the
/// design, while using the server's proximity for the bar fill and percent.
///   blazing → fire (error red)        «ساخن جداً»
///   warm    → thermostat (secondary)  «دافئ»
///   cold    → ac_unit (tertiary cyan) «بارد»
///   freezing→ severe_cold (outline)   «متجمد»
enum HeatTier { blazing, warm, cold, freezing }

class Heat {
  Heat._();

  /// Map the backend `heat_level` string to a Stitch tier. Falls back to the
  /// numeric proximity (0–100) for any level string we don't recognize.
  static HeatTier fromLevel(String? level, double proximity) {
    switch (level?.toLowerCase()) {
      case 'boiling':
      case 'blazing':
      case 'burning':
      case 'scorching':
      case 'hot':
        return HeatTier.blazing;
      case 'warm':
      case 'lukewarm':
        return HeatTier.warm;
      case 'cool':
      case 'cold':
        return HeatTier.cold;
      case 'freezing':
      case 'frozen':
      case 'icy':
        return HeatTier.freezing;
    }
    return fromProximity(proximity);
  }

  static HeatTier fromProximity(double proximity) {
    if (proximity >= 75) return HeatTier.blazing;
    if (proximity >= 50) return HeatTier.warm;
    if (proximity >= 25) return HeatTier.cold;
    return HeatTier.freezing;
  }

  /// Localization key of a tier's label (resolved via AppLocalizations).
  static String labelKey(HeatTier tier) => switch (tier) {
    HeatTier.blazing => 'heatBlazing',
    HeatTier.warm => 'heatWarm',
    HeatTier.cold => 'heatCold',
    HeatTier.freezing => 'heatFreezing',
  };

  static Color color(HeatTier tier) => switch (tier) {
    HeatTier.blazing => AppColors.error,
    HeatTier.warm => AppColors.secondary,
    HeatTier.cold => AppColors.tertiary,
    HeatTier.freezing => AppColors.outline,
  };

  /// Rank/label text color in the history list.
  static Color rankColor(HeatTier tier) => switch (tier) {
    HeatTier.blazing => AppColors.primary,
    HeatTier.warm => AppColors.secondary,
    HeatTier.cold => AppColors.onSurfaceVariant,
    HeatTier.freezing => AppColors.onSurfaceVariant,
  };

  /// Bar fill fraction in [0, 1] from the server proximity (0–100).
  static double fraction(double proximity) =>
      (proximity / 100).clamp(0.02, 1.0);

  static String percentLabel(double proximity) => '${proximity.round()}%';
}
