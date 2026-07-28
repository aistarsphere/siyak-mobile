import 'package:context_game/features/game/domain/entities/heat.dart';
import 'package:flutter_test/flutter_test.dart';

/// `Heat` is now only a mapper from the server's `heat_level` / `proximity` onto
/// a tier. Its colour, label-key, fraction and percent helpers were removed as
/// dead code in the theme audit — nothing rendered them, and they were the last
/// consumers of the retired `AppColors` palette. Gameplay closeness is rendered
/// from `SiyaqHeat` instead.
void main() {
  group('Heat.fromLevel', () {
    test('maps backend heat_level strings to tiers', () {
      expect(Heat.fromLevel('boiling', 100), HeatTier.blazing);
      expect(Heat.fromLevel('hot', 90), HeatTier.blazing);
      expect(Heat.fromLevel('warm', 60), HeatTier.warm);
      expect(Heat.fromLevel('cold', 30), HeatTier.cold);
      expect(Heat.fromLevel('freezing', 10), HeatTier.freezing);
    });

    test('falls back to proximity for unknown level strings', () {
      expect(Heat.fromLevel('mystery', 80), HeatTier.blazing);
      expect(Heat.fromLevel(null, 60), HeatTier.warm);
      expect(Heat.fromLevel(null, 30), HeatTier.cold);
      expect(Heat.fromLevel(null, 5), HeatTier.freezing);
    });
  });

  group('Heat.fromProximity', () {
    test('bands the 0-100 scale', () {
      expect(Heat.fromProximity(100), HeatTier.blazing);
      expect(Heat.fromProximity(75), HeatTier.blazing);
      expect(Heat.fromProximity(50), HeatTier.warm);
      expect(Heat.fromProximity(25), HeatTier.cold);
      expect(Heat.fromProximity(0), HeatTier.freezing);
    });
  });
}
