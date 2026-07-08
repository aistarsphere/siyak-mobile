import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import 'pressable.dart';

enum ChipAccent { primary, secondary }

/// Home-screen selector chip. Active: tinted fill + colored border + soft
/// glow (`bg-primary/15 border-primary shadow amber 25%`); inactive: dim
/// surface + outline-variant border.
class SelectorChip extends StatelessWidget {
  const SelectorChip({
    super.key,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent = ChipAccent.primary,
  });

  final String label;
  final bool selected;
  final VoidCallback onTap;
  final ChipAccent accent;

  @override
  Widget build(BuildContext context) {
    final accentColor = accent == ChipAccent.primary
        ? AppColors.primaryContainer
        : AppColors.secondary;
    final textColor = accent == ChipAccent.primary
        ? AppColors.primary
        : AppColors.secondary;
    return Pressable(
      onTap: onTap,
      child: AnimatedContainer(
        duration: AppMotion.focus,
        curve: Curves.easeOut,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
        decoration: BoxDecoration(
          color: selected
              ? accentColor.withValues(alpha: 0.15)
              : AppColors.surfaceContainerHighest.withValues(alpha: 0.30),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected ? accentColor : AppColors.outlineVariant,
          ),
          boxShadow: selected
              ? [BoxShadow(color: accentColor.withValues(alpha: 0.25), blurRadius: 12)]
              : const [],
        ),
        child: Text(
          label,
          style: AppTypography.bodySm.copyWith(
            color: selected ? textColor : AppColors.onSurfaceVariant,
          ),
        ),
      ),
    );
  }
}
