import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../a11y/siyaq_a11y.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';

/// Interaction states a control can be in, resolved together rather than as a
/// single enum — a control can be focused *and* pressed at once.
@immutable
class SiyaqInteraction {
  const SiyaqInteraction({
    this.pressed = false,
    this.focused = false,
    this.hovered = false,
    this.disabled = false,
    this.loading = false,
  });

  final bool pressed;
  final bool focused;
  final bool hovered;
  final bool disabled;
  final bool loading;

  /// Not accepting input, for either reason.
  bool get inert => disabled || loading;
}

/// The interaction primitive every Siyaq control is built on.
///
/// Centralises the behaviour the audit found missing across the app (§7): a
/// guaranteed 44×44 hit target, a visible focus ring, keyboard activation, and
/// `Semantics` that announce the control's role and state. Components get these
/// by construction instead of each screen re-implementing them.
///
/// Visual styling is entirely the caller's: [builder] receives the live
/// [SiyaqInteraction] and returns the appearance for it.
class SiyaqPressable extends StatefulWidget {
  const SiyaqPressable({
    super.key,
    required this.builder,
    this.onTap,
    this.onLongPress,
    this.semanticLabel,
    this.semanticHint,
    this.isButton = true,
    this.selected = false,
    this.loading = false,
    this.pressScale = 0.97,
    this.haptics = true,
    this.focusRadius = 12,
    this.enforceMinTarget = true,
    this.autofocus = false,
    this.focusNode,
  });

  /// Builds the visual for the current interaction state.
  final Widget Function(BuildContext context, SiyaqInteraction state) builder;

  final VoidCallback? onTap;
  final VoidCallback? onLongPress;

  /// Announced by assistive tech. Required in practice for icon-only controls —
  /// without it a screen reader can only say "button".
  final String? semanticLabel;
  final String? semanticHint;

  final bool isButton;
  final bool selected;

  /// Suppresses input and announces a busy state.
  final bool loading;

  final double pressScale;
  final bool haptics;

  /// Corner radius of the focus ring; should match the control's own radius.
  final double focusRadius;

  /// Pad the hit area out to [SiyaqSpacing.minTouchTarget] without changing the
  /// visual size. Disable for controls that are already large enough and must
  /// not gain outer padding (e.g. a full-width button in a tight column).
  final bool enforceMinTarget;

  final bool autofocus;
  final FocusNode? focusNode;

  @override
  State<SiyaqPressable> createState() => _SiyaqPressableState();
}

class _SiyaqPressableState extends State<SiyaqPressable> {
  bool _pressed = false;
  bool _focused = false;
  bool _hovered = false;

  bool get _enabled => widget.onTap != null && !widget.loading;

  void _setPressed(bool v) {
    if (_pressed != v) setState(() => _pressed = v);
  }

  void _activate() {
    if (!_enabled) return;
    if (widget.haptics) HapticFeedback.selectionClick();
    widget.onTap!();
  }

  @override
  Widget build(BuildContext context) {
    final state = SiyaqInteraction(
      pressed: _pressed,
      focused: _focused,
      hovered: _hovered,
      disabled: widget.onTap == null && !widget.loading,
      loading: widget.loading,
    );

    Widget child = widget.builder(context, state);

    // Press feedback: skipped while inert so a disabled control never appears
    // to respond.
    child = AnimatedScale(
      scale: _pressed && _enabled ? widget.pressScale : 1.0,
      duration: SiyaqMotion.tap,
      curve: SiyaqMotion.easeOut,
      child: child,
    );

    child = SiyaqFocusRing(
      focused: _focused && _enabled,
      color: context.colors.borderFocus,
      radius: widget.focusRadius,
      child: child,
    );

    child = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: _enabled ? (_) => _setPressed(true) : null,
      onTapUp: _enabled ? (_) => _setPressed(false) : null,
      onTapCancel: _enabled ? () => _setPressed(false) : null,
      onTap: _enabled ? _activate : null,
      onLongPress: _enabled ? widget.onLongPress : null,
      child: child,
    );

    if (widget.enforceMinTarget) {
      child = SiyaqA11y.minTarget(child: child);
    }

    // FocusableActionDetector wires keyboard activation, focus and hover in one
    // place, so every control is operable without a pointer.
    child = FocusableActionDetector(
      enabled: _enabled,
      autofocus: widget.autofocus,
      focusNode: widget.focusNode,
      onShowFocusHighlight: (v) {
        if (_focused != v) setState(() => _focused = v);
      },
      onShowHoverHighlight: (v) {
        if (_hovered != v) setState(() => _hovered = v);
      },
      actions: <Type, Action<Intent>>{
        ActivateIntent: CallbackAction<ActivateIntent>(
          onInvoke: (_) {
            _activate();
            return null;
          },
        ),
      },
      mouseCursor: _enabled
          ? SystemMouseCursors.click
          : SystemMouseCursors.basic,
      child: child,
    );

    return Semantics(
      container: true,
      button: widget.isButton,
      enabled: _enabled,
      selected: widget.selected ? true : null,
      label: widget.semanticLabel,
      hint: widget.semanticHint,
      // Announces the busy state during submission — the audit found zero
      // Semantics anywhere in the app, so loading was previously silent.
      liveRegion: widget.loading,
      // The tap action must be re-declared here. The subtree is wrapped in
      // ExcludeSemantics (so the label is announced once, not duplicated by
      // descendants), which also strips the GestureDetector's own tap action —
      // leaving a node that says "button" but cannot be activated by TalkBack or
      // VoiceOver. Without this, the control is focusable but unusable.
      onTap: _enabled ? _activate : null,
      onLongPress: _enabled ? widget.onLongPress : null,
      child: ExcludeSemantics(child: child),
    );
  }
}
