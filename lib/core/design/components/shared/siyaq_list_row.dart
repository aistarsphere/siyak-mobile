import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_surface.dart';
import '../foundation/siyaq_text.dart';

/// A leading-icon / title / subtitle / trailing row.
///
/// Covers Figma's `Settings Row`, `Player Row` and `Transaction Row` shapes, and
/// replaces the five near-duplicate private row classes the audit found (`_Row`,
/// `_PlayerRow`, `_Participant`, `_SharedRow`, `_TierRow` — §6.5).
///
/// Direction handling is structural: it is a [Row] with `EdgeInsetsDirectional`
/// padding, so "leading" is on the right under RTL with no branch. The
/// navigation chevron mirrors itself — the glyph declares `matchTextDirection`.
class SiyaqListRow extends StatelessWidget {
  const SiyaqListRow({
    super.key,
    required this.title,
    this.subtitle,
    this.leading,
    this.leadingIcon,
    this.leadingColor,
    this.trailing,
    this.onTap,
    this.showChevron = false,
    this.tone,
    this.surface = true,
    this.titleRole = SiyaqTextRole.bodyMedium,
    this.subtitleRole = SiyaqTextRole.bodySmall,
    this.semanticLabel,
    this.stackTrailingBelow = 300,
    this.padding,
    this.radius = SiyaqRadius.card,
    this.selected = false,
    this.showSelectionIndicator = false,
    this.selectionAccent,
  });

  final String title;
  final String? subtitle;

  /// Arbitrary leading widget — a [SiyaqIconTile], an avatar, a checkbox.
  /// Takes precedence over [leadingIcon] when both are supplied.
  final Widget? leading;

  final IconData? leadingIcon;

  /// Tints the leading icon — e.g. `colors.success` on a verified row.
  final Color? leadingColor;

  /// Trailing widget: a chip, a switch, a button. Mutually exclusive in practice
  /// with [showChevron].
  final Widget? trailing;

  final VoidCallback? onTap;

  /// Renders a direction-correct navigation chevron.
  final bool showChevron;

  /// Tints title and icon for a status row (destructive action, warning).
  final SiyaqTone? tone;

  /// Wrap in a [SiyaqSurface]. Set `false` when the row sits inside an existing
  /// surface, e.g. as one of several rows in a settings card.
  final bool surface;

  final SiyaqTextRole titleRole;
  final SiyaqTextRole subtitleRole;
  final String? semanticLabel;

  /// Overrides the surface padding — a hub "action card" is roomier than a
  /// settings row.
  final EdgeInsetsGeometry? padding;

  final double radius;

  /// Draws the selected treatment (accent border + tinted fill) and announces the
  /// row as selected.
  final bool selected;

  /// Appends a radio/check glyph reflecting [selected] — turns the row into a
  /// single-choice option without a second component.
  final bool showSelectionIndicator;

  final Color? selectionAccent;

  /// Below this width (scaled by the active text scale) a [trailing] widget moves
  /// onto its own line instead of competing with the title for horizontal space.
  ///
  /// Without this, a trailing button squeezes the title to a few characters per
  /// line at large text scales — observed at 320px / 1.6× on the Profile
  /// linked-account row.
  final double stackTrailingBelow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final toneColor = tone?.resolve(c).$1;
    final titleColor = toneColor ?? c.textPrimary;

    Widget text() => Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        SiyaqText(title, role: titleRole, color: titleColor),
        if (subtitle != null) ...[
          const SizedBox(height: SiyaqSpacing.xxxs),
          SiyaqText(subtitle!, role: subtitleRole, color: c.textMuted),
        ],
      ],
    );

    final selectAccent = selectionAccent ?? c.primary;

    Widget? selectionMark() => showSelectionIndicator
        ? Icon(
            selected ? SiyaqIcons.checkCircle : SiyaqIcons.radioOff,
            size: SiyaqIconSize.lg,
            color: selected ? selectAccent : c.textDisabled,
          )
        : null;

    Widget? chevron() => showChevron
        ? Icon(
            // `chevron_right` declares matchTextDirection, so Flutter mirrors it
            // in RTL — it always points "forward" in the reading direction.
            // Choosing `chevron_left` for RTL by hand double-flips it.
            Icons.chevron_right_rounded,
            size: SiyaqIconSize.md,
            color: c.textMuted,
          )
        : null;

    Widget? lead() =>
        leading ??
        (leadingIcon == null
            ? null
            : Icon(
                leadingIcon,
                size: SiyaqIconSize.md,
                color: leadingColor ?? toneColor ?? c.iconSecondary,
              ));

    final content = LayoutBuilder(
      builder: (context, constraints) {
        final scale = MediaQuery.textScalerOf(context).scale(1);
        final stack =
            trailing != null &&
            constraints.maxWidth < stackTrailingBelow * scale;

        final head = Row(
          children: [
            if (lead() != null) ...[
              lead()!,
              const SizedBox(width: SiyaqSpacing.md),
            ],
            Expanded(child: text()),
            if (!stack && trailing != null) ...[
              const SizedBox(width: SiyaqSpacing.md),
              trailing!,
            ],
            if (selectionMark() != null) ...[
              const SizedBox(width: SiyaqSpacing.md),
              selectionMark()!,
            ],
            if (chevron() != null) ...[
              const SizedBox(width: SiyaqSpacing.sm),
              chevron()!,
            ],
          ],
        );

        if (!stack) return head;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            head,
            const SizedBox(height: SiyaqSpacing.md),
            // Explicitly start-aligned: a stacked trailing widget should sit at
            // the reading-start edge, not stretch across the row.
            Align(
              alignment: AlignmentDirectional.centerStart,
              child: trailing!,
            ),
          ],
        );
      },
    );

    if (!surface) {
      return Semantics(
        container: true,
        label: semanticLabel,
        excludeSemantics: semanticLabel != null,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: SiyaqSpacing.md),
          child: content,
        ),
      );
    }

    return SiyaqSurface(
      onTap: onTap,
      selected: selected,
      accent: selectionAccent,
      semanticLabel: semanticLabel ?? title,
      radius: radius,
      padding:
          padding ??
          const EdgeInsets.symmetric(
            horizontal: SiyaqSpacing.lg,
            vertical: SiyaqSpacing.md,
          ),
      child: content,
    );
  }
}
