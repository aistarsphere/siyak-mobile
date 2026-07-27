import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_surface.dart';
import '../foundation/siyaq_text.dart';

/// A single metric: a value over a caption.
///
/// Covers Figma's `Siyaq/Stat Card`. Replaces the `_stat` / `_meta` helpers
/// duplicated across Profile, Result, Weekly and Leaderboard.
///
/// The value is mono so columns of figures align. [placeholder] is rendered when
/// [value] is null, so "no data yet" is a first-class state rather than each
/// caller inventing its own em dash.
class SiyaqStatCard extends StatelessWidget {
  const SiyaqStatCard({
    super.key,
    required this.value,
    required this.label,
    this.placeholder = '—',
    this.loading = false,
    this.accent,
    this.semanticLabel,
    this.numeric = true,
  });

  /// `null` renders [placeholder].
  final String? value;
  final String label;
  final String placeholder;

  /// Renders a skeleton block instead of the value.
  final bool loading;

  /// Tints the value — e.g. a personal best in the primary colour.
  final Color? accent;

  /// Spoken form, e.g. "Games played: 128". Without it a screen reader reads the
  /// number and caption as two disconnected fragments.
  final String? semanticLabel;

  /// `true` renders [value] as a tabular figure (mono, single line) so columns of
  /// numbers align.
  ///
  /// Set `false` for a **word** value — a category name, a status. Those get the
  /// script-aware family, a smaller role and two lines, because forcing them
  /// through the numeric style truncates them to "Litera…" in a narrow cell.
  final bool numeric;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final body = Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (loading)
          Container(
            height: SiyaqTextRole.headingMedium.size,
            width: 44,
            decoration: BoxDecoration(
              color: c.surfaceStrong,
              borderRadius: BorderRadius.circular(SiyaqRadius.sm),
            ),
          )
        else if (numeric)
          SiyaqText.numeric(
            value ?? placeholder,
            role: SiyaqTextRole.headingMedium,
            color: accent ?? c.textPrimary,
            maxLines: 1,
          )
        else
          SiyaqText(
            value ?? placeholder,
            role: SiyaqTextRole.headingSmall,
            color: accent ?? c.textPrimary,
            align: TextAlign.center,
            maxLines: 2,
          ),
        const SizedBox(height: SiyaqSpacing.xxs),
        SiyaqText(
          label,
          role: SiyaqTextRole.labelSmall,
          color: c.textMuted,
          align: TextAlign.center,
          // Two lines so a long Arabic caption wraps instead of being clipped —
          // the old 9px single-line caption overflowed at large text scales.
          maxLines: 2,
        ),
      ],
    );

    return Semantics(
      // container: true is essential — without it adjacent stat cards merge into
      // a single node and a screen reader reads "Games: 128 Solved: 96 …" as one
      // run-on string instead of four separate figures.
      container: true,
      label: semanticLabel,
      excludeSemantics: semanticLabel != null,
      child: SiyaqSurface(
        padding: const EdgeInsets.symmetric(
          horizontal: SiyaqSpacing.sm,
          vertical: SiyaqSpacing.md,
        ),
        child: Center(child: body),
      ),
    );
  }
}

/// Lays stat cards out in a grid that reflows instead of overflowing.
///
/// The old Profile put four stats in a bare `Row` of `Expanded`, which overflows
/// by ~83px at 320px width and 1.6× text scale. This measures the available
/// width and drops from [columns] to fewer when each cell would fall below
/// [minCellWidth], scaled by the active text scale so the breakpoint tracks how
/// large the text actually is.
class SiyaqStatGrid extends StatelessWidget {
  const SiyaqStatGrid({
    super.key,
    required this.children,
    this.columns = 4,
    this.minCellWidth = 68,
    this.gap = SiyaqSpacing.sm,
  });

  final List<Widget> children;
  final int columns;

  /// Minimum comfortable cell width at 1.0 text scale.
  ///
  /// Calibrated on a real 360dp phone, where four cards get 72dp each: the
  /// default keeps 4-across there (matching the pre-migration layout) and drops
  /// to 2×2 only on a 320dp screen (62dp) or once text scaling makes the cells
  /// genuinely too small.
  final double minCellWidth;

  final double gap;

  @override
  Widget build(BuildContext context) {
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return LayoutBuilder(
      builder: (context, constraints) {
        final available = constraints.maxWidth;
        final needed = minCellWidth * scale;

        var cols = columns;
        while (cols > 1) {
          final cell = (available - gap * (cols - 1)) / cols;
          if (cell >= needed) break;
          // Halve rather than decrement so 4 → 2 → 1 keeps rows balanced.
          cols = cols == 3 ? 2 : cols ~/ 2;
        }

        // IntrinsicHeight so all cards in a row share the tallest card's height
        // — a bare `CrossAxisAlignment.stretch` would demand an infinite height
        // inside a scroll view.
        Widget row(List<Widget> cells) => IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              for (var i = 0; i < cells.length; i++) ...[
                if (i > 0) SizedBox(width: gap),
                Expanded(child: cells[i]),
              ],
            ],
          ),
        );

        if (cols >= children.length) return row(children);

        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += cols) {
          final slice = children.sublist(
            i,
            (i + cols).clamp(0, children.length),
          );
          rows.add(
            row([
              for (var j = 0; j < cols; j++)
                // Pad the final short row with empty cells so columns line up.
                j < slice.length ? slice[j] : const SizedBox(),
            ]),
          );
        }
        return Column(
          children: [
            for (var i = 0; i < rows.length; i++) ...[
              if (i > 0) SizedBox(height: gap),
              rows[i],
            ],
          ],
        );
      },
    );
  }
}
