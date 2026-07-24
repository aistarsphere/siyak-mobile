import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/widgets/pressable.dart';

/// Amber Noir guess input reused by weekly + room gameplay: glass field with
/// the focus underline glow and the glowing amber send button.
class V2GuessInput extends StatefulWidget {
  const V2GuessInput({
    super.key,
    required this.controller,
    required this.hint,
    required this.onSubmit,
    this.busy = false,
    this.error = false,
    this.enabled = true,
  });

  final TextEditingController controller;
  final String hint;
  final ValueChanged<String> onSubmit;
  final bool busy;
  final bool error;
  final bool enabled;

  @override
  State<V2GuessInput> createState() => _V2GuessInputState();
}

class _V2GuessInputState extends State<V2GuessInput> {
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _submit() => widget.onSubmit(widget.controller.text);

  @override
  Widget build(BuildContext context) {
    final underline = widget.error
        ? AppColors.error
        : _focused
        ? AppColors.amber
        : Colors.transparent;
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        AnimatedContainer(
          duration: AppMotion.focus,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border(bottom: BorderSide(color: underline, width: 2)),
            boxShadow: _focused
                ? [BoxShadow(color: AppColors.amberGlow(0.15), blurRadius: 16)]
                : const [],
          ),
          child: TextField(
            controller: widget.controller,
            focusNode: _focus,
            enabled: widget.enabled,
            onSubmitted: (_) => _submit(),
            textInputAction: TextInputAction.send,
            style: AppTypography.bodyLg.copyWith(
              color: widget.error ? AppColors.error : AppColors.onSurface,
            ),
            decoration: InputDecoration(
              hintText: widget.hint,
              hintStyle: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsetsDirectional.only(
                start: 16,
                end: 64,
                top: 18,
                bottom: 18,
              ),
            ),
          ),
        ),
        PositionedDirectional(
          end: 8,
          child: Pressable(
            onTap: widget.busy || !widget.enabled ? null : _submit,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: [
                  BoxShadow(color: AppColors.amberGlow(0.4), blurRadius: 15),
                ],
              ),
              child: widget.busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: AppColors.onPrimaryContainer,
                      ),
                    )
                  : const Icon(
                      Icons.send,
                      size: 22,
                      color: AppColors.onPrimaryContainer,
                    ),
            ),
          ),
        ),
      ],
    );
  }
}
