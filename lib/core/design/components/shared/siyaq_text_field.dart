import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';

/// Single-line text input.
///
/// Covers Figma's `Siyaq/Text Input` states (Empty / Filled / Focused / Error /
/// Disabled). Focus and error are driven from the theme's `borderFocus` and
/// `error` tokens, so the 2px focus ring Figma mandates but never shipped a
/// variant for (audit §11-11) is real here.
///
/// The counter and error text are part of the component rather than each caller
/// re-styling `InputDecoration`.
class SiyaqTextField extends StatelessWidget {
  const SiyaqTextField({
    super.key,
    this.controller,
    this.label,
    this.hint,
    this.helper,
    this.errorText,
    this.maxLength,
    this.enabled = true,
    this.autofocus = false,
    this.textInputAction,
    this.onChanged,
    this.onSubmitted,
    this.role = SiyaqTextRole.bodyLarge,
    this.semanticLabel,
  });

  final TextEditingController? controller;
  final String? label;
  final String? hint;
  final String? helper;

  /// Non-null switches the field to its error appearance.
  final String? errorText;

  final int? maxLength;
  final bool enabled;
  final bool autofocus;
  final TextInputAction? textInputAction;
  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  /// Type role for the entered text.
  final SiyaqTextRole role;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = errorText != null;

    OutlineInputBorder border(Color colour, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(SiyaqRadius.card),
      borderSide: BorderSide(color: colour, width: width),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (label != null) ...[
          SiyaqText(
            label!,
            role: SiyaqTextRole.labelMedium,
            color: c.textSecondary,
          ),
          const SizedBox(height: SiyaqSpacing.xs),
        ],
        TextField(
          controller: controller,
          enabled: enabled,
          autofocus: autofocus,
          maxLength: maxLength,
          textInputAction: textInputAction,
          onChanged: onChanged,
          onSubmitted: onSubmitted,
          style: context.type.role(
            role,
            color: enabled ? c.textPrimary : c.textDisabled,
          ),
          cursorColor: c.primary,
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: context.type.role(role, color: c.textDisabled),
            filled: true,
            fillColor: enabled ? c.surfaceElevated : c.surfaceDisabled,
            counterStyle: context.type.numeric(
              SiyaqTextRole.labelSmall,
              color: c.textMuted,
            ),
            contentPadding: const EdgeInsets.symmetric(
              horizontal: SiyaqSpacing.lg,
              vertical: SiyaqSpacing.md,
            ),
            enabledBorder: border(hasError ? c.error : Colors.transparent, 1),
            border: border(Colors.transparent, 1),
            disabledBorder: border(Colors.transparent, 1),
            focusedBorder: border(hasError ? c.error : c.borderFocus, 2),
            errorStyle: const TextStyle(height: 0, fontSize: 0),
          ),
        ),
        if (hasError || helper != null) ...[
          const SizedBox(height: SiyaqSpacing.xs),
          SiyaqText(
            errorText ?? helper!,
            role: SiyaqTextRole.bodySmall,
            color: hasError ? c.error : c.textMuted,
          ),
        ],
      ],
    );
  }
}
