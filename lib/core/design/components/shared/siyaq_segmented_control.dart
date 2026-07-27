import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_pressable.dart';
import '../foundation/siyaq_text.dart';

/// One option in a [SiyaqSegmentedControl].
@immutable
class SiyaqSegment<T> {
  const SiyaqSegment({
    required this.value,
    required this.label,
    this.icon,
    this.semanticLabel,
  });

  final T value;
  final String label;

  /// Decorative — the label already names the option.
  final IconData? icon;

  final String? semanticLabel;
}

/// Exclusive choice among 2–4 options.
///
/// Covers Figma's `Siyaq/Segmented Control` and replaces the two near-identical
/// private selectors the audit flagged (`_AppearanceSelector`,
/// `_LanguageSelector` — §6.5): same markup, different payload, duplicated.
///
/// Generic over the value type, so it carries a `ThemeMode`, a language code or
/// any enum without stringly-typed plumbing. Mirrors under RTL for free — it is
/// a [Row] of [Expanded] with no directional branch.
///
/// At tight widths or large text scales the icon is dropped before the label is
/// truncated, because the label is what identifies the option.
class SiyaqSegmentedControl<T> extends StatelessWidget {
  const SiyaqSegmentedControl({
    super.key,
    required this.segments,
    required this.value,
    required this.onChanged,
    this.accent,
    this.iconMinCellWidth = 92,
  });

  final List<SiyaqSegment<T>> segments;
  final T value;
  final ValueChanged<T> onChanged;

  /// Fill for the active segment. Defaults to `colors.primary`.
  final Color? accent;

  /// Below this per-cell width (scaled by text scale) icons are hidden.
  final double iconMinCellWidth;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    return LayoutBuilder(
      builder: (context, constraints) {
        final cell = constraints.maxWidth / segments.length;
        final showIcons = cell >= iconMinCellWidth * scale;

        return Container(
          padding: const EdgeInsets.all(SiyaqSpacing.xxs),
          decoration: BoxDecoration(
            color: c.surface,
            borderRadius: BorderRadius.circular(SiyaqRadius.card),
            border: Border.all(color: c.border),
          ),
          // IntrinsicHeight so every segment matches the tallest — a bare
          // `CrossAxisAlignment.stretch` would demand an infinite height inside
          // a scroll view.
          child: IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final segment in segments)
                  Expanded(
                    child: _Segment<T>(
                      segment: segment,
                      selected: segment.value == value,
                      accent: a,
                      showIcon: showIcons && segment.icon != null,
                      onTap: () => onChanged(segment.value),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _Segment<T> extends StatelessWidget {
  const _Segment({
    required this.segment,
    required this.selected,
    required this.accent,
    required this.showIcon,
    required this.onTap,
  });

  final SiyaqSegment<T> segment;
  final bool selected;
  final Color accent;
  final bool showIcon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fg = selected ? c.foregroundOn(accent) : c.textSecondary;

    return SiyaqPressable(
      onTap: onTap,
      selected: selected,
      semanticLabel: segment.semanticLabel ?? segment.label,
      // Announced as a selectable option rather than a button, which is what a
      // segmented control's members actually are.
      isButton: false,
      focusRadius: SiyaqRadius.lg,
      pressScale: 0.98,
      enforceMinTarget: false,
      builder: (context, state) => AnimatedContainer(
        duration: SiyaqMotion.quick,
        curve: SiyaqMotion.easeOut,
        constraints: const BoxConstraints(
          minHeight: SiyaqSpacing.minTouchTarget - SiyaqSpacing.sm,
        ),
        padding: const EdgeInsets.symmetric(
          horizontal: SiyaqSpacing.sm,
          vertical: SiyaqSpacing.smd,
        ),
        decoration: BoxDecoration(
          color: selected
              ? accent
              : state.pressed
              ? c.surfaceElevated
              : Colors.transparent,
          borderRadius: BorderRadius.circular(SiyaqRadius.lg),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (showIcon) ...[
              Icon(segment.icon, size: SiyaqIconSize.sm, color: fg),
              const SizedBox(width: SiyaqSpacing.xs),
            ],
            Flexible(
              child: SiyaqText(
                segment.label,
                role: SiyaqTextRole.labelLarge,
                color: fg,
                align: TextAlign.center,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
