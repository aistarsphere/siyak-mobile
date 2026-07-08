import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../domain/entities/guess.dart';
import 'glass_panel.dart';
import 'guess_row.dart';
import 'heat_bar.dart';

/// "أقرب تخمين" bento card from the Stitch gameplay screen: glass panel with
/// a blurred amber blob in the corner, the closest word in glowing amber,
/// a heat pill, the rank and a shimmering gradient progress bar.
class BestGuessCard extends StatelessWidget {
  const BestGuessCard({super.key, required this.best, required this.loc});

  final Guess best;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.10,
      borderRadius: BorderRadius.circular(12),
      child: Stack(
        children: [
          // Decorative blurred amber blob (top corner).
          PositionedDirectional(
            top: -40,
            end: -40,
            child: Container(
              width: 128,
              height: 128,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primaryContainer.withValues(alpha: 0.20),
                boxShadow: [
                  BoxShadow(
                    color: AppColors.primaryContainer.withValues(alpha: 0.20),
                    blurRadius: 48,
                    spreadRadius: 24,
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            loc('bestGuess'),
                            style: AppTypography.labelXs
                                .copyWith(color: AppColors.onSurfaceVariant),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            best.word,
                            overflow: TextOverflow.ellipsis,
                            style: AppTypography.displaySm.copyWith(
                              color: AppColors.primary,
                              shadows: AppTypography.amberTextGlow,
                            ),
                          ),
                        ],
                      ),
                    ),
                    HeatLabel(tier: best.tier, loc: loc),
                  ],
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    Text(
                      '#${best.rank}',
                      style: AppTypography.headlineLg
                          .copyWith(color: AppColors.onSurface),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: HeatBar(
                        fraction: (best.proximity / 100).clamp(0.02, 1.0),
                        gradient: true,
                        shimmer: true,
                        glow: true,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
