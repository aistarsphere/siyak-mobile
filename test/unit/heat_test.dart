import 'package:context_game/core/theme/app_colors.dart';
import 'package:context_game/features/game/domain/entities/heat.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Heat.tierFor', () {
    test('maps ranks to the four Stitch tiers', () {
      expect(Heat.tierFor(1), HeatTier.blazing);
      expect(Heat.tierFor(7), HeatTier.blazing);
      expect(Heat.tierFor(10), HeatTier.blazing);
      expect(Heat.tierFor(11), HeatTier.warm);
      expect(Heat.tierFor(42), HeatTier.warm);
      expect(Heat.tierFor(100), HeatTier.warm);
      expect(Heat.tierFor(152), HeatTier.cold);
      expect(Heat.tierFor(1000), HeatTier.cold);
      expect(Heat.tierFor(1001), HeatTier.freezing);
      expect(Heat.tierFor(7999), HeatTier.freezing);
    });
  });

  group('Heat labels and colors', () {
    test('label keys per tier', () {
      expect(Heat.labelKey(HeatTier.blazing), 'heatBlazing');
      expect(Heat.labelKey(HeatTier.warm), 'heatWarm');
      expect(Heat.labelKey(HeatTier.cold), 'heatCold');
      expect(Heat.labelKey(HeatTier.freezing), 'heatFreezing');
    });

    test('tier colors follow the design (error/secondary/tertiary/outline)', () {
      expect(Heat.color(HeatTier.blazing), AppColors.error);
      expect(Heat.color(HeatTier.warm), AppColors.secondary);
      expect(Heat.color(HeatTier.cold), AppColors.tertiary);
      expect(Heat.color(HeatTier.freezing), AppColors.outline);
    });
  });

  group('Heat.closeness', () {
    test('rank 1 is exactly 1.0', () {
      expect(Heat.closeness(1, 8000), 1.0);
    });

    test('is monotonically decreasing in rank', () {
      final values = [2, 7, 42, 152, 1000, 7999]
          .map((r) => Heat.closeness(r, 8000))
          .toList();
      for (var i = 1; i < values.length; i++) {
        expect(values[i], lessThan(values[i - 1]));
      }
    });

    test('stays within [0.02, 1.0] even for out-of-range ranks', () {
      expect(Heat.closeness(999999, 8000), greaterThanOrEqualTo(0.02));
      expect(Heat.closeness(999999, 8000), lessThanOrEqualTo(1.0));
      expect(Heat.closeness(1, 0), 1.0); // degenerate total
    });

    test('percent label renders as a percentage string', () {
      expect(Heat.percentLabel(1, 8000), '100%');
      expect(Heat.percentLabel(8000, 8000), '2%');
    });
  });
}
