import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../domain/entities/adaptive_hint.dart';

/// Compact hint pill for V2 adaptive/standard hints: `💡 تلميح 1 · خوارزمية · #31`.
/// Shows revealed word + semantic rank; pops in. Never an attempt.
class AdaptiveHintPill extends StatelessWidget {
  const AdaptiveHintPill({
    super.key,
    required this.hint,
    required this.hintLabel,
    this.animateIn = false,
  });

  final AdaptiveHint hint;
  final String hintLabel; // localized "تلميح"/"Hint"
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    Widget pill = GlassPanel(
      opacity: 0.2,
      borderRadius: BorderRadius.circular(999),
      border: Border.all(color: AppColors.onSurface.withValues(alpha: 0.05)),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.lightbulb, size: 14, color: AppColors.secondary),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              '$hintLabel ${hint.number} · ${hint.word} · #${hint.semanticRank}',
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
      ),
    );
    if (animateIn) {
      pill = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: AppMotion.hintPop,
        curve: AppMotion.pop,
        builder: (context, t, child) => Transform.scale(
          scale: 0.6 + 0.4 * t,
          child: Opacity(opacity: t.clamp(0.0, 1.0), child: child),
        ),
        child: pill,
      );
    }
    return pill;
  }
}
