import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import 'siyaq_text.dart';

/// Section separator — Figma's `Siyaq/Divider` (`Default` / `WithLabel`).
///
/// The labelled form is direction-agnostic: it is built from [Row] with
/// [Expanded] rails, so it mirrors correctly under RTL with no branch on
/// direction.
class SiyaqDivider extends StatelessWidget {
  const SiyaqDivider({super.key, this.indent = 0})
    : label = null,
      _thickness = 1;

  /// A rule with centred text, for separating alternative actions.
  const SiyaqDivider.labelled(this.label, {super.key, this.indent = 0})
    : _thickness = 1;

  final String? label;
  final double indent;
  final double _thickness;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rule = Container(height: _thickness, color: c.divider);

    if (label == null) {
      return Padding(
        padding: EdgeInsetsDirectional.only(start: indent, end: indent),
        child: rule,
      );
    }

    return Padding(
      padding: EdgeInsetsDirectional.only(start: indent, end: indent),
      child: Row(
        children: [
          Expanded(child: rule),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: SiyaqSpacing.md),
            child: SiyaqText(
              label!,
              role: SiyaqTextRole.labelSmall,
              color: c.textMuted,
            ),
          ),
          Expanded(child: rule),
        ],
      ),
    );
  }
}
