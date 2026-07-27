import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';

/// A small pill carrying a count — pending invitations, unread notifications.
///
/// Renders nothing when [count] is zero, so a caller can pass the value
/// unconditionally instead of guarding at every site.
///
/// [semanticLabel] is required: a bare "3" tells a screen-reader user nothing,
/// and the count is exactly the kind of value that needs naming ("3 invitations").
///
/// ⚠️ Placed inside an **interactive** container (a tappable [SiyaqListRow], a
/// button), this label is discarded — that container merges its subtree into one
/// node, which is correct for a screen reader but means the count would go
/// unannounced. Fold the same text into the container's own `semanticLabel`.
class SiyaqCountBadge extends StatelessWidget {
  const SiyaqCountBadge({
    super.key,
    required this.count,
    required this.semanticLabel,
    this.accent,
    this.max = 99,
  });

  final int count;

  /// Spoken form, e.g. "3 invitations".
  final String semanticLabel;

  /// Fill colour. Defaults to `colors.primary`.
  final Color? accent;

  /// Counts above this render as "max+" so the pill cannot grow unbounded.
  final int max;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    final c = context.colors;
    final a = accent ?? c.primary;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Container(
          constraints: const BoxConstraints(minWidth: 22),
          padding: const EdgeInsets.symmetric(
            horizontal: SiyaqSpacing.xs,
            vertical: 2,
          ),
          decoration: BoxDecoration(
            color: a,
            borderRadius: BorderRadius.circular(SiyaqRadius.full),
          ),
          // Center(widthFactor: 1) rather than Container(alignment:) — the latter
          // expands to fill loose constraints, which stretched the pill across
          // the row when the trailing slot wrapped to its own line.
          child: Center(
            widthFactor: 1,
            child: SiyaqText.numeric(
              count > max ? '$max+' : '$count',
              role: SiyaqTextRole.labelSmall,
              color: c.foregroundOn(a),
              maxLines: 1,
            ),
          ),
        ),
      ),
    );
  }
}
