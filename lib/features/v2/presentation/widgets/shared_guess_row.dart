import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/domain/entities/heat.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/guess_row.dart'
    show heatIcon, HeatBarSmall;
import '../../domain/entities/room.dart';

/// A live shared-guess row: canonical word + rank + heat, attributed to the
/// player. My guesses get an amber leading edge; other players a neutral edge;
/// system hints a distinct secondary (orange) treatment + icon. Inserts with
/// a fade/slide animation.
class SharedGuessRow extends StatelessWidget {
  const SharedGuessRow({
    super.key,
    required this.shared,
    this.animateIn = false,
  });

  final SharedGuess shared;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final g = shared.guess;
    final tier = g.tier;
    final edge = shared.isSystemHint
        ? AppColors.secondary
        : shared.isMine
        ? AppColors.primary
        : AppColors.onSurfaceVariant;

    Widget row = Stack(
      children: [
        GlassPanel(
          opacity: shared.isMine ? 0.35 : 0.18,
          borderRadius: BorderRadius.circular(8),
          padding: const EdgeInsetsDirectional.fromSTEB(14, 8, 8, 8),
          child: Row(
            children: [
              SizedBox(
                width: 56,
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  child: Text(
                    '#${g.rank}',
                    style: AppTypography.headlineMobile.copyWith(
                      color: Heat.rankColor(tier),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      g.word,
                      overflow: TextOverflow.ellipsis,
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.onSurface,
                        fontWeight: shared.isMine
                            ? FontWeight.w600
                            : FontWeight.w400,
                      ),
                    ),
                    Row(
                      children: [
                        Icon(
                          shared.isSystemHint
                              ? Icons.lightbulb
                              : (shared.isMine ? Icons.person : Icons.group),
                          size: 11,
                          color: edge,
                        ),
                        const SizedBox(width: 3),
                        Text(
                          shared.isSystemHint ? '—' : shared.byLabel,
                          style: AppTypography.labelXs.copyWith(color: edge),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              SizedBox(
                width: 84,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          Heat.percentLabel(g.proximity),
                          style: AppTypography.labelXs.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        const SizedBox(width: 4),
                        Icon(heatIcon(tier), size: 14, color: Heat.color(tier)),
                      ],
                    ),
                    const SizedBox(height: 4),
                    HeatBarSmall(
                      fraction: Heat.fraction(g.proximity),
                      color: Heat.color(tier),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        PositionedDirectional(
          start: 0,
          top: 0,
          bottom: 0,
          child: Container(
            width: 4,
            decoration: BoxDecoration(
              color: edge,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
        ),
      ],
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
