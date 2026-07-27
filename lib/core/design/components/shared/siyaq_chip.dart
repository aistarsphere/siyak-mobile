import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_pressable.dart';
import '../foundation/siyaq_text.dart';

/// Chip style.
enum SiyaqChipVariant {
  /// Neutral outlined pill — metadata, ids, counts.
  neutral,

  /// Accent-tinted — an active mode or highlighted value.
  accent,

  /// Filled with the accent — a selected filter.
  selected,
}

/// Compact pill for metadata, selection and status.
///
/// Consolidates the five near-duplicate private pill classes the audit found
/// (`_CoinsPill`, `_PresenceChip`, `_Chip`, `_PlayerIdChip`, `_ConnBadge` — §6.5)
/// and covers Figma's `Category Chip` and `Mode Badge`.
///
/// The label uses mono when [numeric] so ids, codes and counts align; leading and
/// trailing icons are decorative, since the label already carries the meaning.
class SiyaqChip extends StatelessWidget {
  const SiyaqChip({
    super.key,
    required this.label,
    this.icon,
    this.trailingIcon,
    this.variant = SiyaqChipVariant.neutral,
    this.accent,
    this.onTap,
    this.numeric = false,
    this.semanticLabel,
    this.semanticHint,
  });

  final String label;
  final IconData? icon;
  final IconData? trailingIcon;
  final SiyaqChipVariant variant;

  /// Tint for [SiyaqChipVariant.accent] / [SiyaqChipVariant.selected].
  final Color? accent;

  final VoidCallback? onTap;

  /// Render the label in the mono family — ids, room codes, counts.
  final bool numeric;

  final String? semanticLabel;
  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    if (onTap == null) return _chip(context, const SiyaqInteraction());
    return SiyaqPressable(
      onTap: onTap,
      semanticLabel: semanticLabel ?? label,
      semanticHint: semanticHint,
      focusRadius: SiyaqRadius.full,
      pressScale: 0.95,
      builder: _chip,
    );
  }

  Widget _chip(BuildContext context, SiyaqInteraction state) {
    final c = context.colors;
    final a = accent ?? c.primary;

    final (bg, fg, border) = switch (variant) {
      SiyaqChipVariant.selected => (a, c.foregroundOn(a), null),
      SiyaqChipVariant.accent => (
        a.withValues(alpha: 0.16),
        a,
        a.withValues(alpha: 0.4),
      ),
      SiyaqChipVariant.neutral => (
        state.pressed ? c.surfaceElevated : c.surface,
        c.textSecondary,
        c.border,
      ),
    };

    return Container(
      padding: const EdgeInsetsDirectional.only(
        start: SiyaqSpacing.md,
        end: SiyaqSpacing.md,
        top: SiyaqSpacing.xs,
        bottom: SiyaqSpacing.xs,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SiyaqRadius.full),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: SiyaqIconSize.xs, color: fg),
            const SizedBox(width: SiyaqSpacing.xs),
          ],
          // Flexible so a long category name ellipsizes rather than overflowing
          // the row it sits in.
          Flexible(
            child: SiyaqText(
              label,
              role: SiyaqTextRole.labelMedium,
              script: numeric ? SiyaqScript.mono : null,
              color: fg,
              maxLines: 1,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: SiyaqSpacing.xs),
            Icon(trailingIcon, size: SiyaqIconSize.xs, color: fg),
          ],
        ],
      ),
    );
  }
}
