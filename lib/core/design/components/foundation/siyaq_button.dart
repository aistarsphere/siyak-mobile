import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_colors.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import 'siyaq_pressable.dart';
import 'siyaq_text.dart';

/// Button style, matching Figma's `Siyaq/Button` `Type` axis.
enum SiyaqButtonType { primary, secondary, ghost, destructive }

/// Button size.
///
/// Figma's `Siyaq/Button` variants have **no size axis** (its own documentation
/// claims two sizes that do not exist — audit §11-6), but the bound
/// `Siyaq/Button/Large` and `Siyaq/Button/Medium` text styles do define two, so
/// the axis is reconstructed from those.
enum SiyaqButtonSize {
  large(SiyaqTextRole.buttonLarge, 48, SiyaqSpacing.xl, SiyaqIconSize.md),
  medium(SiyaqTextRole.buttonMedium, 40, SiyaqSpacing.lg, SiyaqIconSize.sm);

  const SiyaqButtonSize(this.role, this.minHeight, this.padX, this.iconSize);

  final SiyaqTextRole role;

  /// A **minimum**, not a fixed height. Figma specifies `h-[48px]`, which clips
  /// at large text scales (audit §11-16); the button grows instead.
  final double minHeight;

  final double padX;
  final double iconSize;
}

/// The single button component for the whole app.
///
/// Replaces `SiyagPrimaryButton` and `SiyagGhostButton` — two separate classes
/// where one component with a `type` belongs (audit §17) — and adds the states
/// the old pair lacked: **pressed**, **focused** and **loading**, plus proper
/// `Semantics`. Disabled is a real token pair rather than `Opacity(0.5)`.
class SiyaqButton extends StatelessWidget {
  const SiyaqButton({
    super.key,
    required this.label,
    this.onPressed,
    this.type = SiyaqButtonType.primary,
    this.size = SiyaqButtonSize.large,
    this.icon,
    this.trailingIcon,
    this.fullWidth = false,
    this.loading = false,
    this.semanticHint,
    this.accent,
  });

  final String label;
  final VoidCallback? onPressed;
  final SiyaqButtonType type;
  final SiyaqButtonSize size;

  /// Overrides the fill for a semantic action that is none of the four [type]s —
  /// a positive-confirm (`colors.success`), an informational action
  /// (`colors.info`), a game-mode accent, or a brand-mandated colour such as the
  /// Apple sign-in black.
  ///
  /// The label colour is **derived by measured contrast**
  /// ([SiyaqColors.foregroundOn]), not chosen by the caller and not guessed from
  /// a luminance threshold — so an accent fill cannot reintroduce the
  /// `onColorLegacy` defect. Prefer a [type] where one fits; reach for this only
  /// when the action genuinely carries its own semantic colour.
  final Color? accent;

  /// Leading icon. Decorative — the label already carries the meaning.
  final IconData? icon;
  final IconData? trailingIcon;

  /// Stretch to the parent's width. Leave `false` inside an unbounded [Row].
  final bool fullWidth;

  /// Shows a spinner, blocks input, and announces a busy state.
  final bool loading;

  final String? semanticHint;

  @override
  Widget build(BuildContext context) {
    return SiyaqPressable(
      onTap: onPressed,
      loading: loading,
      semanticLabel: label,
      semanticHint: semanticHint,
      focusRadius: SiyaqRadius.button,
      // A button already exceeds the 44px minimum; extra outer padding would
      // break full-width layouts and vertical rhythm.
      enforceMinTarget: false,
      builder: (context, state) => _build(context, state),
    );
  }

  Widget _build(BuildContext context, SiyaqInteraction state) {
    final c = context.colors;
    final (bg, fg, border) = _palette(c, state);

    return Container(
      width: fullWidth ? double.infinity : null,
      constraints: BoxConstraints(minHeight: size.minHeight),
      padding: EdgeInsets.symmetric(
        horizontal: size.padX,
        vertical: SiyaqSpacing.md,
      ),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(SiyaqRadius.button),
        border: border == null ? null : Border.all(color: border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
        children: [
          if (state.loading)
            _Spinner(color: fg, size: size.iconSize)
          else if (icon != null)
            Icon(icon, size: size.iconSize, color: fg),
          if (state.loading || icon != null)
            const SizedBox(width: SiyaqSpacing.sm),
          // Flexible so a long or expanded label wraps instead of overflowing.
          Flexible(
            child: SiyaqText(
              label,
              role: size.role,
              color: fg,
              align: TextAlign.center,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: SiyaqSpacing.sm),
            Icon(trailingIcon, size: size.iconSize, color: fg),
          ],
        ],
      ),
    );
  }

  /// (background, foreground, border) for the current state.
  ///
  /// Every foreground is a paired `on*` token rather than a luminance guess, so
  /// contrast is known rather than hoped for — this is where the Light-theme
  /// `onColorLegacy` defect (2.19:1, audit §4) is actually fixed.
  (Color, Color?, Color?) _palette(SiyaqColors c, SiyaqInteraction state) {
    if (state.disabled) {
      return switch (type) {
        SiyaqButtonType.ghost => (Colors.transparent, c.textDisabled, null),
        _ => (c.surfaceDisabled, c.textDisabled, null),
      };
    }
    final override = accent;
    if (override != null) {
      final fill = state.pressed
          ? Color.alphaBlend(c.scrim.withValues(alpha: 0.2), override)
          : override;
      return (fill, c.foregroundOn(override), null);
    }
    return switch (type) {
      SiyaqButtonType.primary => (
        state.pressed ? c.primaryStrong : c.primary,
        c.onAction,
        null,
      ),
      SiyaqButtonType.secondary => (
        state.pressed ? c.surfaceStrong : c.actionSecondary,
        c.onActionSecondary,
        c.border,
      ),
      SiyaqButtonType.ghost => (
        state.pressed ? c.surfaceElevated : Colors.transparent,
        c.textPrimary,
        null,
      ),
      SiyaqButtonType.destructive => (
        state.pressed
            ? Color.alphaBlend(
                c.scrim.withValues(alpha: 0.2),
                c.actionDestructive,
              )
            : c.actionDestructive,
        c.onActionDestructive,
        null,
      ),
    };
  }
}

class _Spinner extends StatelessWidget {
  const _Spinner({required this.color, required this.size});

  final Color? color;
  final double size;

  @override
  Widget build(BuildContext context) => SizedBox(
    width: size,
    height: size,
    child: CircularProgressIndicator(strokeWidth: 2.2, color: color),
  );
}
