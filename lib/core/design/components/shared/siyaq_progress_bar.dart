import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';

/// Linear progress with an optional label row.
///
/// Covers Figma's `Siyaq/Progress Bar` (`Progress=0% / 33% / 66% / 100%`).
///
/// The track is a **semantic surface token**, not a white alpha overlay — the
/// pattern the audit found in the old heat bar, which rendered invisible in Light
/// theme (§6.4). The fill animates so a value change reads as motion rather than
/// a jump.
///
/// Progress is announced as a percentage; a bare bar is invisible to a screen
/// reader.
class SiyaqProgressBar extends StatelessWidget {
  const SiyaqProgressBar({
    super.key,
    required this.value,
    this.label,
    this.trailingLabel,
    this.accent,
    this.height = 8,
    this.semanticLabel,
    this.animate = true,
  });

  /// 0..1, clamped. Values outside the range are a caller bug, not a crash.
  final double value;

  /// Leading caption above the bar.
  final String? label;

  /// Trailing caption above the bar — e.g. the remaining time.
  final String? trailingLabel;

  final Color? accent;
  final double height;

  /// Spoken name. The percentage is appended automatically.
  final String? semanticLabel;

  final bool animate;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;
    final v = value.clamp(0.0, 1.0);
    final pct = (v * 100).round();

    final bar = ClipRRect(
      borderRadius: BorderRadius.circular(SiyaqRadius.full),
      child: Container(
        height: height,
        color: c.surfaceStrong,
        alignment: AlignmentDirectional.centerStart,
        child: animate
            ? TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: v),
                duration: SiyaqMotion.barFill,
                curve: SiyaqMotion.easeOutQuint,
                builder: (context, t, _) => _Fill(fraction: t, colour: a),
              )
            : _Fill(fraction: v, colour: a),
      ),
    );

    return Semantics(
      container: true,
      label: semanticLabel == null ? '$pct%' : '$semanticLabel: $pct%',
      value: '$pct%',
      child: ExcludeSemantics(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (label != null || trailingLabel != null) ...[
              Row(
                children: [
                  if (label != null)
                    Expanded(
                      child: SiyaqText(
                        label!,
                        role: SiyaqTextRole.labelMedium,
                        color: c.textMuted,
                        maxLines: 1,
                      ),
                    )
                  else
                    const Spacer(),
                  if (trailingLabel != null)
                    SiyaqText.numeric(
                      trailingLabel!,
                      role: SiyaqTextRole.labelMedium,
                      color: a,
                      maxLines: 1,
                    ),
                ],
              ),
              const SizedBox(height: SiyaqSpacing.xs),
            ],
            bar,
          ],
        ),
      ),
    );
  }
}

class _Fill extends StatelessWidget {
  const _Fill({required this.fraction, required this.colour});

  final double fraction;
  final Color colour;

  @override
  Widget build(BuildContext context) => FractionallySizedBox(
    alignment: AlignmentDirectional.centerStart,
    widthFactor: fraction,
    // heightFactor: 1 is load-bearing — without a tight height the childless
    // DecoratedBox collapses to zero and the fill never paints.
    heightFactor: 1,
    child: DecoratedBox(
      decoration: BoxDecoration(
        color: colour,
        borderRadius: BorderRadius.circular(SiyaqRadius.full),
      ),
    ),
  );
}
