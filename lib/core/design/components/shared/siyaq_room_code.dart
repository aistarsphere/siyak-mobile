import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';

/// Uppercase alphanumeric room-code entry.
///
/// Covers Figma's `Siyaq/Room Code Input` (`Empty` / `Partial` / `Complete` /
/// `Error`).
///
/// A room code is a Latin token, never prose, so the field is pinned to LTR and
/// the mono family **in both app languages** — under RTL the digits would
/// otherwise reorder and the code would be read back wrong. The surrounding
/// label and error text still follow the app direction.
///
/// Input is normalised as it is typed: uppercased, non-alphanumerics dropped,
/// length-capped. That mirrors the pre-migration formatter exactly.
class SiyaqCodeField extends StatelessWidget {
  const SiyaqCodeField({
    super.key,
    required this.controller,
    this.label,
    this.hint = 'ABCD',
    this.errorText,
    this.enabled = true,
    this.autofocus = true,
    this.maxLength = 8,
    this.accent,
    this.onChanged,
    this.onSubmitted,
    this.semanticLabel,
  });

  final TextEditingController controller;
  final String? label;
  final String hint;

  /// Non-null switches the field to its error appearance.
  final String? errorText;

  final bool enabled;
  final bool autofocus;
  final int maxLength;

  /// Focus-ring colour. Defaults to `colors.borderFocus`.
  final Color? accent;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hasError = errorText != null;
    final focus = hasError ? c.error : (accent ?? c.borderFocus);

    OutlineInputBorder border(Color colour, double width) => OutlineInputBorder(
      borderRadius: BorderRadius.circular(SiyaqRadius.card),
      borderSide: BorderSide(color: colour, width: width),
    );

    final field = TextField(
      controller: controller,
      enabled: enabled,
      autofocus: autofocus,
      textAlign: TextAlign.center,
      textCapitalization: TextCapitalization.characters,
      // A code is Latin/numeric: force LTR so RTL bidi cannot reorder it.
      textDirection: TextDirection.ltr,
      inputFormatters: [
        TextInputFormatter.withFunction((o, n) {
          String clean(String s) =>
              s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
          final text = clean(n.text);
          // Dropping characters shortens the text, so the caret has to move back
          // by however many were dropped ahead of it. Keeping the raw offset
          // leaves it past the end and trips an assertion in TextEditingValue on
          // paste or IME commit.
          final caret = n.selection.baseOffset < 0
              ? n.text.length
              : n.selection.baseOffset;
          return TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(
              offset: clean(n.text.substring(0, caret)).length,
            ),
          );
        }),
        LengthLimitingTextInputFormatter(maxLength),
      ],
      style: context.type.custom(
        script: SiyaqScript.mono,
        size: SiyaqTextRole.displayMedium.size,
        color: enabled ? c.textPrimary : c.textDisabled,
        letterSpacing: 8,
      ),
      cursorColor: focus,
      onChanged: onChanged,
      onSubmitted: onSubmitted,
      decoration: InputDecoration(
        hintText: hint,
        hintStyle: context.type.custom(
          script: SiyaqScript.mono,
          size: SiyaqTextRole.displayMedium.size,
          color: c.textDisabled,
          letterSpacing: 8,
        ),
        filled: true,
        fillColor: enabled ? c.surface : c.surfaceDisabled,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: SiyaqSpacing.lg,
          vertical: SiyaqSpacing.lg,
        ),
        enabledBorder: border(hasError ? c.error : Colors.transparent, 1),
        border: border(Colors.transparent, 1),
        disabledBorder: border(Colors.transparent, 1),
        focusedBorder: border(focus, 2),
        counterText: '',
      ),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (label != null) ...[
          SiyaqText(
            label!,
            role: SiyaqTextRole.bodySmall,
            color: c.textSecondary,
          ),
          const SizedBox(height: SiyaqSpacing.md),
        ],
        Semantics(
          textField: true,
          label: semanticLabel ?? label,
          child: Directionality(textDirection: TextDirection.ltr, child: field),
        ),
        if (hasError) ...[
          const SizedBox(height: SiyaqSpacing.md),
          SiyaqText(
            errorText!,
            role: SiyaqTextRole.bodySmall,
            color: c.error,
            align: TextAlign.center,
          ),
        ],
      ],
    );
  }
}

/// Read-only room code with copy / share actions.
///
/// The counterpart to [SiyaqCodeField]: same LTR-pinned mono treatment, so the
/// code a host reads aloud matches the code a guest types.
class SiyaqCodeDisplay extends StatelessWidget {
  const SiyaqCodeDisplay({
    super.key,
    required this.code,
    required this.label,
    this.accent,
    this.onCopy,
    this.onShare,
    this.copyLabel,
    this.shareLabel,
  });

  final String code;

  /// Kicker above the code, e.g. "join code".
  final String label;

  final Color? accent;
  final VoidCallback? onCopy;
  final VoidCallback? onShare;

  /// Accessible names for the two icon actions.
  final String? copyLabel;
  final String? shareLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.success;
    return Container(
      padding: const EdgeInsets.all(SiyaqSpacing.xl),
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SiyaqRadius.xxxl),
        border: Border.all(color: a.withValues(alpha: 0.27)),
      ),
      child: Column(
        children: [
          SiyaqText(
            label.toUpperCase(),
            role: SiyaqTextRole.labelSmall,
            script: SiyaqScript.mono,
            color: a,
          ),
          const SizedBox(height: SiyaqSpacing.sm),
          // Announced as the code itself; the visual tracking is decorative.
          Semantics(
            container: true,
            label: '$label: $code',
            child: ExcludeSemantics(
              child: Directionality(
                textDirection: TextDirection.ltr,
                child: Text(
                  code,
                  style: context.type.custom(
                    script: SiyaqScript.mono,
                    size: 34,
                    letterSpacing: 8,
                    color: c.textPrimary,
                  ),
                ),
              ),
            ),
          ),
          if (onCopy != null || onShare != null) ...[
            const SizedBox(height: SiyaqSpacing.md),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (onCopy != null)
                  _Action(
                    icon: Icons.copy_rounded,
                    label: copyLabel ?? 'Copy',
                    accent: a,
                    onTap: onCopy!,
                  ),
                if (onCopy != null && onShare != null)
                  const SizedBox(width: SiyaqSpacing.md),
                if (onShare != null)
                  _Action(
                    icon: Icons.ios_share_rounded,
                    label: shareLabel ?? 'Share',
                    accent: a,
                    onTap: onShare!,
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _Action extends StatelessWidget {
  const _Action({
    required this.icon,
    required this.label,
    required this.accent,
    required this.onTap,
  });

  final IconData icon;
  final String label;
  final Color accent;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      button: true,
      label: label,
      onTap: onTap,
      child: ExcludeSemantics(
        child: Material(
          color: c.surfaceElevated,
          borderRadius: BorderRadius.circular(SiyaqRadius.full),
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(SiyaqRadius.full),
            child: Container(
              constraints: const BoxConstraints(
                minWidth: SiyaqSpacing.minTouchTarget,
                minHeight: SiyaqSpacing.minTouchTarget,
              ),
              padding: const EdgeInsets.symmetric(horizontal: SiyaqSpacing.lg),
              alignment: Alignment.center,
              child: Icon(icon, size: 18, color: accent),
            ),
          ),
        ),
      ),
    );
  }
}
