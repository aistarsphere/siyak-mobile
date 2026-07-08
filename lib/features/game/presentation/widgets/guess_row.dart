import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/guess.dart';
import '../../domain/entities/heat.dart';
import 'glass_panel.dart';

IconData heatIcon(HeatTier tier) => switch (tier) {
      HeatTier.blazing => Icons.local_fire_department,
      HeatTier.warm => Icons.thermostat,
      HeatTier.cold => Icons.ac_unit,
      HeatTier.freezing => Icons.severe_cold,
    };

/// One guess-history row from the Stitch gameplay screen:
/// glass panel · tier-tinted rank (#N) · word · closeness % + heat icon ·
/// thin tier-colored bar. Latest guess gets an amber edge highlight
/// (from the unknown-word screen's "last guess" row treatment).
class GuessRow extends StatelessWidget {
  const GuessRow({
    super.key,
    required this.guess,
    this.highlighted = false,
    this.animateIn = false,
  });

  final Guess guess;
  final bool highlighted;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final tier = guess.tier;
    final tierColor = Heat.color(tier);
    final rankColor = Heat.rankColor(tier);
    final fraction = Heat.fraction(guess.proximity);
    final dim = tier == HeatTier.freezing;

    Widget row = Opacity(
      opacity: dim && !highlighted ? 0.7 : 1,
      child: Stack(
        children: [
          GlassPanel(
            opacity: highlighted ? 0.40 : 0.20,
            borderRadius: BorderRadius.circular(8),
            padding: const EdgeInsets.all(8),
            child: Row(
              children: [
                SizedBox(
                  width: 56,
                  // Scale down instead of wrapping for 4-5 digit ranks.
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: Text(
                      '#${guess.rank}',
                      textAlign: TextAlign.center,
                      style: AppTypography.headlineMobile.copyWith(
                        color: rankColor,
                        shadows: highlighted && tier == HeatTier.blazing
                            ? AppTypography.amberTextGlow
                            : null,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    guess.word,
                    overflow: TextOverflow.ellipsis,
                    style: AppTypography.bodyLg.copyWith(
                      color: dim
                          ? AppColors.onSurfaceVariant
                          : AppColors.onSurface,
                      fontWeight:
                          highlighted ? FontWeight.w600 : FontWeight.w400,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 96,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            Heat.percentLabel(guess.proximity),
                            style: AppTypography.labelXs
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(width: 4),
                          Icon(heatIcon(tier), size: 14, color: tierColor),
                        ],
                      ),
                      const SizedBox(height: 4),
                      SizedBox(
                        width: 96,
                        child: HeatBarSmall(
                            fraction: fraction, color: tierColor),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          // Amber edge indicator for the highlighted (latest) row.
          if (highlighted)
            PositionedDirectional(
              start: 0,
              top: 0,
              bottom: 0,
              child: Container(
                width: 4,
                decoration: BoxDecoration(
                  color: AppColors.primary,
                  borderRadius: BorderRadius.circular(999),
                  boxShadow: [
                    BoxShadow(color: AppColors.amberGlow(0.8), blurRadius: 5),
                  ],
                ),
              ),
            ),
        ],
      ),
    );

    if (animateIn) {
      row = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.rowIn,
        curve: AppMotion.easeOut,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, 12 * (1 - t)),
            child: child,
          ),
        ),
        child: row,
      );
    }
    return row;
  }
}

/// Thin (h-1) flat bar used inside history rows.
class HeatBarSmall extends StatelessWidget {
  const HeatBarSmall({super.key, required this.fraction, required this.color});

  final double fraction;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: 4,
        color: AppColors.surfaceContainerLowest,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: fraction.clamp(0.0, 1.0)),
          duration: AppMotion.barFill,
          curve: AppMotion.easeOut,
          builder: (context, t, _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: t,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Localized heat label, e.g. «ساخن جداً» with a fire icon (best-guess pill).
class HeatLabel extends StatelessWidget {
  const HeatLabel({super.key, required this.tier, required this.loc});

  final HeatTier tier;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: AppColors.ivory.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(heatIcon(tier), size: 16, color: Heat.color(tier)),
          const SizedBox(width: 4),
          Text(
            loc(Heat.labelKey(tier)),
            style: AppTypography.labelMd.copyWith(color: AppColors.ivory),
          ),
        ],
      ),
    );
  }
}
