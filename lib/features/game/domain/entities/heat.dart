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
}
