import 'package:context_game/core/theme/app_colors.dart';
import 'package:context_game/features/game/domain/entities/heat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Heat.fromLevel', () {
    test('maps backend heat_level strings to Stitch tiers', () {
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

  group('Heat labels and colors', () {
    test('label keys per tier', () {
      expect(Heat.labelKey(HeatTier.blazing), 'heatBlazing');
      expect(Heat.labelKey(HeatTier.warm), 'heatWarm');
      expect(Heat.labelKey(HeatTier.cold), 'heatCold');
      expect(Heat.labelKey(HeatTier.freezing), 'heatFreezing');
    });

    test('tier colors follow the Amber Noir palette', () {
      expect(Heat.color(HeatTier.blazing), AppColors.error);
      expect(Heat.color(HeatTier.warm), AppColors.secondary);
      expect(Heat.color(HeatTier.cold), AppColors.tertiary);
      expect(Heat.color(HeatTier.freezing), AppColors.outline);
    });
  });

  group('Heat.fraction / percentLabel from server proximity', () {
    test('fraction is proximity/100 clamped to [0.02, 1]', () {
      expect(Heat.fraction(100), 1.0);
      expect(Heat.fraction(50), 0.5);
      expect(Heat.fraction(0), 0.02);
    });

    test('percent label rounds the proximity', () {
      expect(Heat.percentLabel(17.5), '18%');
      expect(Heat.percentLabel(99.5), '100%');
      expect(Heat.percentLabel(0), '0%');
    });
  });
}
