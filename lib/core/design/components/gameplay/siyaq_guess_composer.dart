import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_pressable.dart';
import '../foundation/siyaq_text.dart';

/// The fixed submit-guess control at the bottom of gameplay.
///
/// It borrows a chat composer's *ergonomics* — pinned above the keyboard, always
/// reachable with a thumb, one primary action — and none of its furniture. There
/// is no attachment affordance, no bubble styling and no send-a-message framing:
/// this submits one word into a ranking.
///
/// Content direction is the **gameplay** language, not the UI locale, so an
/// English game inside an Arabic app still types left-to-right with Latin
/// metrics. The surrounding error text follows the UI locale.
class SiyaqGuessComposer extends StatefulWidget {
  const SiyaqGuessComposer({
    super.key,
    required this.controller,
    required this.onSubmit,
    required this.hintText,
    required this.submitLabel,
    required this.fieldSemanticLabel,
    this.focusNode,
    this.direction,
    this.script,
    this.submitting = false,
    this.enabled = true,
    this.errorText,
    this.onChanged,
    this.accent,
  });

  final TextEditingController controller;

  /// Called with the trimmed word. Never fires for empty input.
  final ValueChanged<String> onSubmit;

  final String hintText;

  /// Accessible name of the submit button.
  final String submitLabel;

  /// Accessible name of the text field.
  final String fieldSemanticLabel;

  final FocusNode? focusNode;

  /// Writing direction of the guess — from the gameplay language.
  final TextDirection? direction;

  /// Script of the guess — from the gameplay language.
  final SiyaqScript? script;

  /// A guess is in flight: the field stays readable, the button spins.
  final bool submitting;

  /// False when the game is over. The field and the button both go inert.
  final bool enabled;

  /// Rejection reason for the last attempt — unknown word, duplicate. Non-null
  /// also switches the frame to the error colour.
  final String? errorText;

  final ValueChanged<String>? onChanged;

  final Color? accent;

  @override
  State<SiyaqGuessComposer> createState() => _SiyaqGuessComposerState();
}

class _SiyaqGuessComposerState extends State<SiyaqGuessComposer> {
  FocusNode? _owned;
  bool _focused = false;
  bool _hasText = false;

  /// Bumped whenever a *new* rejection arrives, retriggering the shake even
  /// when two consecutive errors carry the same message.
  int _shakeSeq = 0;

  FocusNode get _focus => widget.focusNode ?? (_owned ??= FocusNode());

  @override
  void initState() {
    super.initState();
    _hasText = widget.controller.text.trim().isNotEmpty;
    widget.controller.addListener(_onText);
    _focus.addListener(_onFocus);
  }

  @override
  void didUpdateWidget(SiyaqGuessComposer old) {
    super.didUpdateWidget(old);
    if (old.controller != widget.controller) {
      old.controller.removeListener(_onText);
      widget.controller.addListener(_onText);
      _onText();
    }
    if (widget.errorText != null && widget.errorText != old.errorText) {
      _shakeSeq++;
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onText);
    _focus.removeListener(_onFocus);
    _owned?.dispose();
    super.dispose();
  }

  void _onText() {
    final has = widget.controller.text.trim().isNotEmpty;
    if (has != _hasText) setState(() => _hasText = has);
  }

  void _onFocus() {
    if (_focus.hasFocus != _focused) setState(() => _focused = _focus.hasFocus);
  }

  void _submit() {
    final word = widget.controller.text.trim();
    if (word.isEmpty || widget.submitting || !widget.enabled) return;
    widget.onSubmit(word);
  }

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = widget.accent ?? c.primary;
    final hasError = widget.errorText != null;
    final canSubmit = _hasText && !widget.submitting && widget.enabled;

    final frame = hasError
        ? c.error
        : _focused
        ? (widget.accent ?? c.borderFocus)
        : c.border;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        if (hasError)
          Padding(
            padding: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
            child: Row(
              children: [
                Icon(
                  Icons.error_outline_rounded,
                  size: SiyaqIconSize.sm,
                  color: c.error,
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                Expanded(
                  child: SiyaqText(
                    widget.errorText!,
                    role: SiyaqTextRole.bodySmall,
                    color: c.error,
                  ),
                ),
              ],
            ),
          ),
        _Shake(
          trigger: _shakeSeq,
          child: AnimatedContainer(
            duration: context.motion.quick,
            curve: SiyaqMotion.easeOut,
            decoration: BoxDecoration(
              color: widget.enabled ? c.surface : c.surfaceDisabled,
              borderRadius: BorderRadius.circular(SiyaqRadius.xxl),
              border: Border.all(
                color: frame,
                width: hasError || _focused ? 2 : 1,
              ),
            ),
            padding: const EdgeInsetsDirectional.fromSTEB(
              SiyaqSpacing.lg,
              SiyaqSpacing.xs,
              SiyaqSpacing.xs,
              SiyaqSpacing.xs,
            ),
            child: Row(
              children: [
                Expanded(
                  child: Semantics(
                    textField: true,
                    label: widget.fieldSemanticLabel,
                    child: TextField(
                      controller: widget.controller,
                      focusNode: _focus,
                      enabled: widget.enabled,
                      textDirection: widget.direction,
                      textInputAction: TextInputAction.send,
                      onSubmitted: (_) => _submit(),
                      onChanged: widget.onChanged,
                      style: context.type.role(
                        SiyaqTextRole.headingSmall,
                        script: widget.script,
                        color: widget.enabled ? c.textPrimary : c.textDisabled,
                      ),
                      cursorColor: a,
                      decoration: InputDecoration(
                        isDense: true,
                        hintText: widget.hintText,
                        // The placeholder is UI chrome ("Type your word…"), not
                        // game content: it keeps the app locale's script and
                        // direction. Forcing it into the game direction put the
                        // ellipsis of an Arabic hint on the wrong side.
                        hintStyle: context.type.role(
                          SiyaqTextRole.headingSmall,
                          color: c.textDisabled,
                        ),
                        border: InputBorder.none,
                        enabledBorder: InputBorder.none,
                        focusedBorder: InputBorder.none,
                        disabledBorder: InputBorder.none,
                        contentPadding: const EdgeInsets.symmetric(
                          vertical: SiyaqSpacing.md,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                _SubmitButton(
                  label: widget.submitLabel,
                  accent: a,
                  loading: widget.submitting,
                  onPressed: canSubmit ? _submit : null,
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Horizontal reject shake — the physical "no" for an invalid or duplicate
/// word. Restarts whenever [trigger] changes; renders nothing extra when idle
/// and is skipped entirely under reduced motion.
class _Shake extends StatefulWidget {
  const _Shake({required this.trigger, required this.child});

  final int trigger;
  final Widget child;

  @override
  State<_Shake> createState() => _ShakeState();
}

class _ShakeState extends State<_Shake> with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SiyaqMotion.nudge,
  );

  @override
  void didUpdateWidget(_Shake old) {
    super.didUpdateWidget(old);
    if (widget.trigger != old.trigger && !context.motion.reduced) {
      _controller.forward(from: 0);
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AnimatedBuilder(
    animation: _controller,
    builder: (context, child) {
      final t = _controller.value;
      // Three damped oscillations, ±6px at the start settling to zero.
      final dx = t >= 1 ? 0.0 : math.sin(t * math.pi * 6) * 6 * (1 - t);
      return Transform.translate(offset: Offset(dx, 0), child: child);
    },
    child: widget.child,
  );
}

/// Square accent button. An upward arrow rather than a paper plane: the plane
/// reads as "send a message", and it needs mirroring in RTL that the arrow
/// does not.
class _SubmitButton extends StatelessWidget {
  const _SubmitButton({
    required this.label,
    required this.accent,
    required this.loading,
    required this.onPressed,
  });

  final String label;
  final Color accent;
  final bool loading;
  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = onPressed != null && !loading;
    final bg = enabled ? accent : c.surfaceStrong;
    final fg = enabled ? c.foregroundOn(accent) : c.textDisabled;

    return SiyaqPressable(
      onTap: onPressed,
      semanticLabel: label,
      focusRadius: SiyaqRadius.lg,
      pressScale: 0.90,
      // Deliberately silent: the scored result lands ~300ms later with its own
      // sound and haptic, and on device the pair read as one stuttering event.
      // The press animation is feedback enough for the tap itself.
      haptics: false,
      sound: false,
      enforceMinTarget: false,
      builder: (context, state) => AnimatedContainer(
        duration: context.motion.quick,
        curve: SiyaqMotion.easeOut,
        width: SiyaqSpacing.minTouchTarget,
        height: SiyaqSpacing.minTouchTarget,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: state.pressed ? bg.withValues(alpha: 0.85) : bg,
          borderRadius: BorderRadius.circular(SiyaqRadius.lg),
        ),
        child: loading
            ? SizedBox(
                width: SiyaqIconSize.sm,
                height: SiyaqIconSize.sm,
                child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
              )
            : Icon(
                Icons.arrow_upward_rounded,
                size: SiyaqIconSize.md,
                color: fg,
              ),
      ),
    );
  }
}
