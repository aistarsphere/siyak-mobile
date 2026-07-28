import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_pressable.dart';
import '../foundation/siyaq_text.dart';

/// A square icon-over-label selection tile, for a grid of choices.
///
/// Covers the category grid in room creation and is the shape Figma uses for
/// `Game Mode Card`. Replaces the screen-local tile that rendered **emoji** as
/// its icon — emoji ignore [IconTheme], cannot be tinted per state and are
/// invisible to screen readers (audit §6.6).
///
/// Announced as a selectable option rather than a button, which is what a member
/// of a single-choice grid actually is.
class SiyaqSelectTile extends StatelessWidget {
  const SiyaqSelectTile({
    super.key,
    required this.icon,
    required this.label,
    required this.selected,
    required this.onTap,
    this.accent,
    this.size = 104,
  });

  final IconData icon;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  /// Selected border and icon tint. Defaults to `colors.primary`.
  final Color? accent;

  /// Edge length at 1.0 text scale; the tile grows with the text scaler so a
  /// long label is never clipped.
  final double size;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return SiyaqPressable(
      onTap: onTap,
      selected: selected,
      isButton: false,
      semanticLabel: label,
      focusRadius: SiyaqRadius.xxl,
      pressScale: 0.97,
      enforceMinTarget: false,
      builder: (context, state) => AnimatedContainer(
        duration: context.motion.quick,
        curve: SiyaqMotion.easeOut,
        width: size * scale.clamp(1.0, 1.6),
        constraints: BoxConstraints(minHeight: size * scale.clamp(1.0, 1.6)),
        padding: const EdgeInsets.all(SiyaqSpacing.md),
        decoration: BoxDecoration(
          color: selected
              ? a.withValues(alpha: 0.12)
              : state.pressed
              ? c.surfaceElevated
              : c.surface,
          borderRadius: BorderRadius.circular(SiyaqRadius.xxl),
          border: Border.all(
            color: selected ? a : c.border,
            width: selected ? 2 : 1,
          ),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: SiyaqIconSize.xl,
              color: selected ? a : c.iconSecondary,
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqText(
              label,
              role: SiyaqTextRole.labelLarge,
              color: selected ? c.textPrimary : c.textSecondary,
              align: TextAlign.center,
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }
}

/// Progress dots for a multi-step flow; the active step widens.
///
/// Announced as "step N of M" so the position is available without sight — the
/// dots alone carry no accessible meaning.
class SiyaqStepDots extends StatelessWidget {
  const SiyaqStepDots({
    super.key,
    required this.step,
    required this.total,
    this.accent,
    this.semanticLabel,
  });

  /// Zero-based active index.
  final int step;
  final int total;
  final Color? accent;

  /// Spoken position, e.g. "Step 2 of 5". Composed by the caller so it can be
  /// localized.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;
    return Semantics(
      container: true,
      label: semanticLabel ?? '${step + 1} / $total',
      child: ExcludeSemantics(
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            for (var i = 0; i < total; i++)
              AnimatedContainer(
                duration: context.motion.quick,
                curve: SiyaqMotion.easeOut,
                margin: const EdgeInsets.symmetric(
                  horizontal: SiyaqSpacing.xxxs,
                ),
                width: i == step ? 22 : 8,
                height: 8,
                decoration: BoxDecoration(
                  color: i <= step ? a : c.border,
                  borderRadius: BorderRadius.circular(SiyaqRadius.full),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
