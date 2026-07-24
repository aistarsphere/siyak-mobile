import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/hint_result.dart';
import 'glass_panel.dart';

/// Compact hint pill: `💡 تلميح 1 · حرب · #152` — glass, rounded-full,
/// lightbulb in secondary orange; pops in with an ease-out-back scale.
class HintPill extends StatelessWidget {
  const HintPill({
    super.key,
    required this.hint,
    required this.loc,
    this.animateIn = false,
  });

  final HintResult hint;
  final AppLocalizations loc;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    // e.g. «تلميح 1 · حرب · #152». Never render an empty word.
    final label = hint.word.isEmpty
        ? '${loc('hintPrefix')} ${hint.number}'
        : '${loc('hintPrefix')} ${hint.number} · ${hint.word} · #${hint.rank}';

    Widget pill = GlassPanel(
      opacity: 0.20,
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
              label,
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
