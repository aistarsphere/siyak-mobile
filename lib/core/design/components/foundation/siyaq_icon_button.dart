import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import 'siyaq_pressable.dart';

enum SiyaqIconButtonType {
  /// Filled surface — a standalone action.
  standard,

  /// No fill until pressed — sits inside a bar or row.
  ghost,

  /// Primary accent fill — the one emphasised action on a surface.
  accent,
}

enum SiyaqIconButtonSize {
  small(32, SiyaqIconSize.sm),
  medium(40, SiyaqIconSize.md),
  large(48, SiyaqIconSize.lg);

  const SiyaqIconButtonSize(this.box, this.icon);

  final double box;
  final double icon;
}

/// An icon-only action.
///
/// [semanticLabel] is **required**: an icon-only control with no label is
/// unusable with a screen reader, and the audit found zero `Semantics` in the
/// app (§7). Making it a required parameter means the omission cannot recur.
///
/// [SiyaqIconButtonSize.small] is 32px visually but still gets a 44px hit target
/// from [SiyaqPressable], satisfying Figma's touch-target rule without inflating
/// the visual design.
class SiyaqIconButton extends StatelessWidget {
  const SiyaqIconButton({
    super.key,
    required this.icon,
    required this.semanticLabel,
    this.onPressed,
    this.type = SiyaqIconButtonType.ghost,
    this.size = SiyaqIconButtonSize.medium,
    this.loading = false,
    this.circular = true,
  });

  final IconData icon;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final SiyaqIconButtonType type;
  final SiyaqIconButtonSize size;
  final bool loading;

  /// Pill/circle by default; square-with-radius when `false`.
  final bool circular;

  @override
  Widget build(BuildContext context) {
    final radius = circular ? size.box / 2 : SiyaqRadius.md;
    return SiyaqPressable(
      onTap: onPressed,
      loading: loading,
      semanticLabel: semanticLabel,
      focusRadius: radius,
      builder: (context, state) {
        final c = context.colors;
        final (bg, fg) = switch (type) {
          _ when state.disabled => (
            type == SiyaqIconButtonType.ghost
                ? Colors.transparent
                : c.surfaceDisabled,
            c.textDisabled,
          ),
          SiyaqIconButtonType.accent => (
            state.pressed ? c.primaryStrong : c.primary,
            c.onAction,
          ),
          SiyaqIconButtonType.standard => (
            state.pressed ? c.surfaceStrong : c.surfaceElevated,
            c.iconPrimary,
          ),
          SiyaqIconButtonType.ghost => (
            state.pressed ? c.surfaceElevated : Colors.transparent,
            c.iconPrimary,
          ),
        };

        return Container(
          width: size.box,
          height: size.box,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(radius),
          ),
          child: state.loading
              ? SizedBox(
                  width: size.icon,
                  height: size.icon,
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Icon(icon, size: size.icon, color: fg),
        );
      },
    );
  }
}
