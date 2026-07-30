/// ─── Organic primitives ──────────────────────────────────────────────────────
///
/// Ported from the component layer of `_ds/organic-…/styles.css`, which the
/// system's readme calls its source of truth. Every number below is that file's;
/// the notable ones are called out where they would otherwise look arbitrary.
///
/// Three rules the CSS establishes that these widgets enforce rather than leave to
/// call sites:
///
/// 1. **Small controls are pills.** The stylesheet's closing "rounded frame"
///    block overrides `.btn`, `.tag`, `.seg` and `.input` to `999px`, so the
///    16px radius they declare earlier never actually applies to them.
/// 2. **Buttons are set in the display face.** `.btn` uses `--font-heading`
///    (Caprasimo) at weight 400, not the body font — easy to get wrong, and very
///    visible when it is.
/// 3. **Focus is themed, never the platform ring.** `:focus-visible` is a 2px
///    accent outline at 2px offset; the segmented control insets it to −2px so it
///    does not escape the clipped track.
library;

import 'package:flutter/material.dart' show Theme;
import 'package:flutter/widgets.dart';

import 'organic_colors.dart';
import 'organic_tokens.dart';
import 'organic_type.dart';

/// Reads the Organic palette out of the enclosing theme.
///
/// Falls back to the light theme rather than throwing, so a primitive still
/// renders inside a bare `WidgetsApp`, a painter preview or a test that has not
/// installed the extension.
OrganicColors organicColorsOf(BuildContext context) =>
    // `Theme.of` is itself null-safe (it falls back when there is no Theme
    // ancestor), so this works in a bare WidgetsApp too.
    Theme.of(context).extension<OrganicColors>() ?? OrganicColors.light;

// ─────────────────────────────────────────────────────────────────────────────
// Button
// ─────────────────────────────────────────────────────────────────────────────

enum SyButtonVariant {
  /// Solid accent fill. Cream text, **not** white — `.btn-primary` sets
  /// `color: var(--color-bg)`.
  primary,

  /// Outlined in the divider colour.
  secondary,

  /// Text-only in the accent, with tighter horizontal padding.
  ghost,
}

/// `.btn` with `.btn-primary` / `.btn-secondary` / `.btn-ghost`.
class SyButton extends StatefulWidget {
  const SyButton({
    super.key,
    required this.label,
    this.onPressed,
    this.variant = SyButtonVariant.primary,
    this.icon,
    this.block = false,
    this.semanticHint,
  });

  final String label;

  /// Null disables the button — `.btn:disabled` drops it to 45% opacity.
  final VoidCallback? onPressed;

  final SyButtonVariant variant;

  /// Leading glyph. `.btn` sets `gap: 6px`.
  final Widget? icon;

  /// `.btn-block`: full width with a `--space-2` top margin.
  final bool block;

  final String? semanticHint;

  bool get enabled => onPressed != null;

  @override
  State<SyButton> createState() => _SyButtonState();
}

class _SyButtonState extends State<SyButton> {
  bool _pressed = false;
  bool _hovered = false;
  bool _focused = false;

  static const _gap = 6.0;
  static const _fontSize = 14.0;

  /// `padding: var(--space-2) calc(var(--space-3) * 1.2)`.
  static const _padV = OrganicSpacing.s2;
  static const _padH = OrganicSpacing.s3 * 1.2;

  @override
  Widget build(BuildContext context) {
    final c = organicColorsOf(context);
    final script = OrganicTextStyles.scriptForLanguage(
      Localizations.maybeLocaleOf(context)?.languageCode,
    );

    final (background, foreground, border) = _colours(c);

    Widget content = Row(
      mainAxisSize: widget.block ? MainAxisSize.max : MainAxisSize.min,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        if (widget.icon != null) ...[
          IconTheme.merge(
            data: IconThemeData(color: foreground, size: 16),
            child: widget.icon!,
          ),
          const SizedBox(width: _gap),
        ],
        Text(
          widget.label,
          textAlign: TextAlign.center,
          // `.btn` is set in the heading face at weight 400.
          style: OrganicTextStyles.resolve(
            OrganicTextRole.headingSmall,
            script: script,
            color: foreground,
            sizeOverride: _fontSize,
          ).copyWith(height: 1.2),
        ),
      ],
    );

    content = Container(
      padding: EdgeInsets.symmetric(
        vertical: _padV,
        horizontal: widget.variant == SyButtonVariant.ghost
            // `.btn-ghost { padding-inline: var(--space-1) }`
            ? OrganicSpacing.s1
            : _padH,
      ),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(OrganicRadius.pill),
        border: border == null ? null : Border.all(color: border),
      ),
      child: content,
    );

    if (_focused) {
      content = _FocusRing(accent: OrganicPalette.accent, child: content);
    }

    // Disabled drops the whole control to 45%, per `.btn:disabled`.
    if (!widget.enabled) {
      content = Opacity(opacity: 0.45, child: content);
    }

    final button = Semantics(
      button: true,
      enabled: widget.enabled,
      label: widget.label,
      hint: widget.semanticHint,
      child: ExcludeSemantics(
        child: MouseRegion(
          cursor: widget.enabled
              ? SystemMouseCursors.click
              // `.btn:disabled { cursor: not-allowed }`
              : SystemMouseCursors.forbidden,
          onEnter: (_) => setState(() => _hovered = true),
          onExit: (_) => setState(() => _hovered = false),
          child: Focus(
            canRequestFocus: widget.enabled,
            onFocusChange: (v) => setState(() => _focused = v),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: widget.enabled
                  ? (_) => setState(() => _pressed = true)
                  : null,
              onTapCancel: widget.enabled
                  ? () => setState(() => _pressed = false)
                  : null,
              onTap: widget.enabled
                  ? () {
                      setState(() => _pressed = false);
                      widget.onPressed!();
                    }
                  : null,
              child: content,
            ),
          ),
        ),
      ),
    );

    if (!widget.block) return button;
    return Padding(
      // `.btn-block { margin-top: var(--space-2) }`
      padding: const EdgeInsets.only(top: OrganicSpacing.s2),
      child: SizedBox(width: double.infinity, child: button),
    );
  }

  /// (background, foreground, border) for the current variant and state.
  ///
  /// Pressed and hover values are the stylesheet's own `:active` / `:hover`
  /// steps, never an ad-hoc darkening.
  (Color?, Color, Color?) _colours(OrganicColors c) {
    switch (widget.variant) {
      case SyButtonVariant.primary:
        final bg = _pressed
            ? OrganicPalette.accent700
            : _hovered
            ? OrganicPalette.accent600
            : OrganicPalette.accent;
        // `.btn-primary { color: var(--color-bg) }` — the cream ground, so the
        // label reads as cut out of the page rather than printed in white.
        return (bg, OrganicPalette.bg, null);
      case SyButtonVariant.secondary:
        final tint = _pressed
            ? 0.14
            : _hovered
            ? 0.07
            : 0.0;
        return (
          tint == 0 ? null : c.text.withValues(alpha: tint),
          c.text,
          OrganicPalette.divider,
        );
      case SyButtonVariant.ghost:
        final tint = _pressed
            ? 0.18
            : _hovered
            ? 0.10
            : 0.0;
        return (
          tint == 0 ? null : OrganicPalette.accent.withValues(alpha: tint),
          // Body-size text in the accent must use the deep step — the system
          // states accent-on-ground is only ~3:1.
          OrganicPalette.accent700,
          null,
        );
    }
  }
}

/// The system's focus treatment: `2px solid var(--color-accent)` at `2px` offset.
class _FocusRing extends StatelessWidget {
  const _FocusRing({required this.child, required this.accent});

  final Widget child;
  final Color accent;

  @override
  Widget build(BuildContext context) => Container(
    // `outline-offset: 2px`. The segmented control will need an inset variant
    // (`-2px`) so its ring stays inside the clipped track; added with it.
    padding: const EdgeInsets.all(2),
    decoration: BoxDecoration(
      borderRadius: BorderRadius.circular(OrganicRadius.pill),
      border: Border.all(color: accent, width: 2),
    ),
    child: child,
  );
}

// ─────────────────────────────────────────────────────────────────────────────
// Tag
// ─────────────────────────────────────────────────────────────────────────────

enum SyTagVariant { accent, accent2, neutral, outline }

/// `.tag` — a small label tinted from one of the ramps.
///
/// Each filled variant pairs a 100-step fill with an 800-step text, which is what
/// keeps the label readable instead of relying on the base colour.
class SyTag extends StatelessWidget {
  const SyTag({
    super.key,
    required this.label,
    this.variant = SyTagVariant.accent,
    this.semanticLabel,
  });

  final String label;
  final SyTagVariant variant;

  /// Overrides what assistive tech announces. A band tag like "Touching" already
  /// reads well, so this is usually left null.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final script = OrganicTextStyles.scriptForLanguage(
      Localizations.maybeLocaleOf(context)?.languageCode,
    );
    final (fill, ink, border) = switch (variant) {
      SyTagVariant.accent => (
        OrganicPalette.accent100,
        OrganicPalette.accent800,
        null,
      ),
      SyTagVariant.accent2 => (
        OrganicPalette.accent2100,
        OrganicPalette.accent2800,
        null,
      ),
      SyTagVariant.neutral => (
        OrganicPalette.neutral100,
        OrganicPalette.neutral800,
        null,
      ),
      SyTagVariant.outline => (
        null,
        OrganicPalette.accent700,
        OrganicPalette.accent,
      ),
    };

    return Semantics(
      label: semanticLabel,
      child: Container(
        // `.tag { padding: 3px 10px }`
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
        decoration: BoxDecoration(
          color: fill,
          borderRadius: BorderRadius.circular(OrganicRadius.pill),
          border: border == null ? null : Border.all(color: border),
        ),
        child: Text(
          label,
          style: OrganicTextStyles.resolve(
            OrganicTextRole.tag,
            script: script,
            color: ink,
            sizeOverride: 11,
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Card
// ─────────────────────────────────────────────────────────────────────────────

/// `.card` — a surface-filled content card.
///
/// The radius is `calc(var(--radius-lg) * 1.15)` = 32.2, from the rounded-frame
/// block, not the 16px `.card` declares earlier.
class SyCard extends StatelessWidget {
  const SyCard({
    super.key,
    required this.children,
    this.elevation = SyElevation.none,
    this.padding,
    this.semanticLabel,
  });

  static const radius = OrganicRadius.lg * 1.15;

  final List<Widget> children;
  final SyElevation elevation;
  final EdgeInsetsGeometry? padding;
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = organicColorsOf(context);
    final card = Container(
      padding: padding ?? const EdgeInsets.all(OrganicSpacing.s3),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(radius),
        boxShadow: switch (elevation) {
          SyElevation.none => null,
          SyElevation.sm => OrganicElevation.small(c.brightness),
          SyElevation.md => OrganicElevation.medium(c.brightness),
          SyElevation.lg => OrganicElevation.lg,
        },
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          for (var i = 0; i < children.length; i++) ...[
            if (i > 0) const SizedBox(height: OrganicSpacing.s2),
            children[i],
          ],
        ],
      ),
    );
    return semanticLabel == null
        ? card
        : Semantics(container: true, label: semanticLabel, child: card);
  }
}

enum SyElevation { none, sm, md, lg }

/// `.card-kicker` — 10px, uppercase, accent. **Latin only**: the design forbids
/// uppercase and tracking in Arabic, so Arabic renders the text as written.
class SyKicker extends StatelessWidget {
  const SyKicker(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final script = OrganicTextStyles.scriptForLanguage(
      Localizations.maybeLocaleOf(context)?.languageCode,
    );
    final upper = OrganicTextStyles.allowsUppercase(script);
    return Text(
      upper ? text.toUpperCase() : text,
      style: OrganicTextStyles.resolve(
        OrganicTextRole.kicker,
        script: script,
        // The kicker is 10px accent text — small, so it takes the deep ramp step
        // rather than the base accent.
        color: OrganicPalette.accent700,
        sizeOverride: 10,
      ),
    );
  }
}

/// `.card-title` — heading face at 17px.
class SyCardTitle extends StatelessWidget {
  const SyCardTitle(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final c = organicColorsOf(context);
    final script = OrganicTextStyles.scriptForLanguage(
      Localizations.maybeLocaleOf(context)?.languageCode,
    );
    return Text(
      text,
      style: OrganicTextStyles.resolve(
        OrganicTextRole.headingSmall,
        script: script,
        color: c.text,
        sizeOverride: 17,
      ),
    );
  }
}
