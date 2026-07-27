import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_colors.dart';
import '../../tokens/siyaq_elevation.dart';
import '../../tokens/siyaq_spacing.dart';
import 'siyaq_pressable.dart';

/// Surface role — how the container sits relative to the canvas.
enum SiyaqSurfaceVariant {
  /// Base card on the app background.
  base,

  /// Raised above a base card.
  elevated,

  /// Reads as tappable.
  interactive,

  /// Transparent with a hairline border — grouping without visual weight.
  outlined,

  /// Tinted with the primary accent — a highlighted or selected card.
  accent,
}

/// The single container component.
///
/// Replaces the **64 inline `BoxDecoration` constructions** across 15 screens
/// (audit §6.5) and the 10 near-duplicate private `_*Card` classes. Colour,
/// radius, border and elevation all come from tokens; nothing is passed as a raw
/// value.
///
/// Supplying [onTap] makes it a real control — it gains press feedback, a focus
/// ring, keyboard activation and `Semantics` via [SiyaqPressable] — rather than
/// a bare `GestureDetector` around a `Container`.
class SiyaqSurface extends StatelessWidget {
  const SiyaqSurface({
    super.key,
    required this.child,
    this.variant = SiyaqSurfaceVariant.base,
    this.padding = const EdgeInsets.all(SiyaqSpacing.lg),
    this.radius = SiyaqRadius.card,
    this.elevation = SiyaqElevation.none,
    this.onTap,
    this.selected = false,
    this.disabled = false,
    this.bordered,
    this.accent,
    this.semanticLabel,
    this.width,
    this.constraints,
  });

  final Widget child;
  final SiyaqSurfaceVariant variant;
  final EdgeInsetsGeometry padding;
  final double radius;
  final SiyaqElevation elevation;

  /// When set, the surface becomes an interactive control.
  final VoidCallback? onTap;

  /// Draws the selected treatment (accent border + tinted fill).
  final bool selected;

  final bool disabled;

  /// Force the hairline border on or off. Defaults per [variant].
  final bool? bordered;

  /// Accent colour for [SiyaqSurfaceVariant.accent] and [selected]. Defaults to
  /// `colors.primary`; pass a `game*` token for mode-coloured cards.
  final Color? accent;

  final String? semanticLabel;
  final double? width;
  final BoxConstraints? constraints;

  @override
  Widget build(BuildContext context) {
    if (onTap == null && !disabled) {
      final plain = _decorated(context, const SiyaqInteraction());
      // A non-interactive surface still owns its announcement. Without this the
      // label composed by the caller (e.g. "Sara, host, offline") is dropped and
      // the reader hears the child fragments as unrelated nodes.
      return semanticLabel == null
          ? plain
          : Semantics(
              container: true,
              label: semanticLabel,
              child: ExcludeSemantics(child: plain),
            );
    }
    return SiyaqPressable(
      onTap: disabled ? null : onTap,
      selected: selected,
      semanticLabel: semanticLabel,
      focusRadius: radius,
      isButton: true,
      // Cards are already far larger than 44px; outer padding would disturb list
      // rhythm and grid alignment.
      enforceMinTarget: false,
      builder: _decorated,
    );
  }

  Widget _decorated(BuildContext context, SiyaqInteraction state) {
    final c = context.colors;
    final a = accent ?? c.primary;
    final inert = disabled || state.disabled;

    Color bg = switch (variant) {
      SiyaqSurfaceVariant.base => c.surface,
      SiyaqSurfaceVariant.elevated => c.surfaceElevated,
      SiyaqSurfaceVariant.interactive => c.surfaceElevated,
      SiyaqSurfaceVariant.outlined => Colors.transparent,
      SiyaqSurfaceVariant.accent => a.withValues(alpha: 0.14),
    };
    if (state.pressed) {
      bg = variant == SiyaqSurfaceVariant.outlined
          ? c.surfaceElevated
          : c.surfaceStrong;
    }
    if (selected && variant != SiyaqSurfaceVariant.accent) {
      bg = a.withValues(alpha: 0.14);
    }
    if (inert) bg = c.surfaceDisabled;

    final showBorder =
        bordered ??
        (variant == SiyaqSurfaceVariant.outlined ||
            variant == SiyaqSurfaceVariant.base ||
            selected);
    final borderColor = selected && !inert ? a : c.border;

    return Opacity(
      opacity: inert ? 0.6 : 1,
      child: Container(
        width: width,
        constraints: constraints,
        padding: padding,
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(radius),
          border: showBorder
              ? Border.all(
                  color: borderColor,
                  width: selected && !inert ? 1.5 : 1,
                )
              : null,
          boxShadow: elevation.shadows(c.shadow),
        ),
        child: child,
      ),
    );
  }
}

/// Soft status/accent tint — banners, badges and inline callouts.
///
/// Pairs each status colour with its `*Subtle` fill so callers cannot invent a
/// tint by guessing an alpha.
class SiyaqTintedSurface extends StatelessWidget {
  const SiyaqTintedSurface({
    super.key,
    required this.child,
    required this.tone,
    this.padding = const EdgeInsets.all(SiyaqSpacing.md),
    this.radius = SiyaqRadius.card,
  });

  final Widget child;
  final SiyaqTone tone;
  final EdgeInsetsGeometry padding;
  final double radius;

  @override
  Widget build(BuildContext context) {
    final (fg, bg) = tone.resolve(context.colors);
    return Container(
      padding: padding,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(radius),
        border: Border.all(color: fg.withValues(alpha: 0.4)),
      ),
      child: child,
    );
  }
}

/// Semantic tone for feedback surfaces.
enum SiyaqTone {
  success,
  warning,
  error,
  info,
  accent;

  /// (foreground, subtle background) for this tone.
  (Color, Color) resolve(SiyaqColors c) => switch (this) {
    SiyaqTone.success => (c.success, c.successSubtle),
    SiyaqTone.warning => (c.warning, c.warningSubtle),
    SiyaqTone.error => (c.error, c.errorSubtle),
    SiyaqTone.info => (c.info, c.infoSubtle),
    SiyaqTone.accent => (c.primary, c.primaryContainer),
  };
}
