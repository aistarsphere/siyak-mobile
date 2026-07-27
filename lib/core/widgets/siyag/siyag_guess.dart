import 'package:flutter/material.dart';

import '../../design/theme/context_tokens.dart';
import '../../design/theme/legacy_type_bridge.dart';
import '../../design/tokens/siyaq_motion.dart';
import '../../design/gameplay/siyaq_heat.dart';
import 'siyag_tap.dart';

/// Animated heat bar (ui.tsx `HeatBar`): continuous color + glow, fills to
/// `heat` (or 1 when solved) over 550ms.
class SiyagHeatBar extends StatelessWidget {
  const SiyagHeatBar({
    super.key,
    required this.heat,
    this.solved = false,
    this.height = 4,
  });

  final double heat;
  final bool solved;
  final double height;

  @override
  Widget build(BuildContext context) {
    final color = SiyaqHeat.color(
      heat,
      solved: solved,
      solvedColor: context.colors.success,
    );
    final target = (solved ? 1.0 : heat).clamp(0.0, 1.0);
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: height,
        color: Colors.white.withValues(alpha: 0.05),
        alignment: AlignmentDirectional.centerStart,
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 0, end: target),
          duration: SiyaqMotion.barFill,
          curve: SiyaqMotion.easeOutQuint,
          builder: (context, t, _) => FractionallySizedBox(
            alignment: AlignmentDirectional.centerStart,
            widthFactor: t,
            child: Container(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(999),
                boxShadow: [
                  BoxShadow(color: color.withValues(alpha: 0.4), blurRadius: 8),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Compact timeline row (ui.tsx `GuessRow`). RTL word/heat, rank pill, bar,
/// and a status dot (newest) or 🔥 (closest). Newest row gets a raised surface.
class SiyagGuessRow extends StatelessWidget {
  const SiyagGuessRow({
    super.key,
    required this.word,
    required this.rank,
    required this.heat,
    this.solved = false,
    this.isNewest = false,
    this.isClosest = false,
    this.animateIn = false,
  });

  final String word;
  final int rank;
  final double heat;
  final bool solved;
  final bool isNewest;
  final bool isClosest;
  final bool animateIn;

  @override
  Widget build(BuildContext context) {
    final color = SiyaqHeat.color(
      heat,
      solved: solved,
      solvedColor: context.colors.success,
    );
    Widget row = Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: isNewest ? context.colors.surfaceElevated : Colors.transparent,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          // Rank pill
          Container(
            width: 48,
            padding: const EdgeInsets.symmetric(vertical: 4),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.04),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              solved ? '✓' : '#$rank',
              style: context.legacyType.mono(
                12,
                color: context.colors.textSecondary,
              ),
            ),
          ),
          const SizedBox(width: 12),
          // Word + bar (RTL)
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  textDirection: TextDirection.rtl,
                  crossAxisAlignment: CrossAxisAlignment.baseline,
                  textBaseline: TextBaseline.alphabetic,
                  children: [
                    Expanded(
                      child: Text(
                        word,
                        textDirection: TextDirection.rtl,
                        overflow: TextOverflow.ellipsis,
                        style: context.legacyType.ar(
                          19,
                          weight: FontWeight.w500,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      SiyaqHeat.labelAr(heat, solved: solved),
                      style: context.legacyType.mono(11, color: color),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                SiyagHeatBar(heat: heat, solved: solved, height: 3),
              ],
            ),
          ),
          const SizedBox(width: 12),
          // Status dot
          SizedBox(
            width: 16,
            child: Center(
              child: isNewest
                  ? Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: color,
                        shape: BoxShape.circle,
                        boxShadow: [BoxShadow(color: color, blurRadius: 6)],
                      ),
                    )
                  : (isClosest
                        ? const Text('🔥', style: TextStyle(fontSize: 12))
                        : const SizedBox.shrink()),
            ),
          ),
        ],
      ),
    );

    if (animateIn) {
      row = TweenAnimationBuilder<double>(
        tween: Tween(begin: 0, end: 1),
        duration: SiyaqMotion.rowIn,
        curve: SiyaqMotion.easeOutQuint,
        builder: (context, t, child) => Opacity(
          opacity: t,
          child: Transform.translate(
            offset: Offset(0, -12 * (1 - t)),
            child: child,
          ),
        ),
        child: row,
      );
    }
    return row;
  }
}

/// Closest/Latest summary chip (ui.tsx `SummaryChip`).
class SiyagSummaryChip extends StatelessWidget {
  const SiyagSummaryChip({
    super.key,
    required this.label,
    required this.emoji,
    required this.word,
    required this.rank,
    required this.color,
    this.solved = false,
  });

  final String label;
  final String emoji;
  final String word;
  final int rank;
  final Color color;
  final bool solved;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Text(emoji, style: const TextStyle(fontSize: 11)),
              const SizedBox(width: 6),
              Text(
                label.toUpperCase(),
                style: context.legacyType.mono(10, color: color),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            textDirection: TextDirection.rtl,
            crossAxisAlignment: CrossAxisAlignment.baseline,
            textBaseline: TextBaseline.alphabetic,
            children: [
              Expanded(
                child: Text(
                  word,
                  textDirection: TextDirection.rtl,
                  overflow: TextOverflow.ellipsis,
                  style: context.legacyType.ar(22, weight: FontWeight.w600),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                solved ? '✓' : '#$rank',
                style: context.legacyType.mono(
                  12,
                  color: context.colors.textMuted,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Hint pill (ui.tsx `HintPill`): locked → "افتح تلميحاً"; revealed → 💡 word #rank
/// with a cyan-tinted surface.
class SiyagHintPill extends StatelessWidget {
  const SiyagHintPill({
    super.key,
    required this.revealed,
    this.word,
    this.rank,
    this.onReveal,
    this.loading = false,
    this.revealLabel = 'افتح تلميحاً',
  });

  final bool revealed;
  final String? word;
  final int? rank;
  final VoidCallback? onReveal;
  final bool loading;
  final String revealLabel;

  @override
  Widget build(BuildContext context) {
    return SiyagTap(
      onTap: revealed ? null : onReveal,
      scale: 0.95,
      child: Container(
        padding: const EdgeInsetsDirectional.only(
          start: 16,
          end: 12,
          top: 10,
          bottom: 10,
        ),
        decoration: BoxDecoration(
          color: revealed
              ? context.colors.info.withValues(alpha: 0.16)
              : context.colors.surfaceElevated,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: revealed
                ? context.colors.info.withValues(alpha: 0.33)
                : context.colors.border,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(revealed ? '💡' : '🔒', style: const TextStyle(fontSize: 14)),
            const SizedBox(width: 10),
            AnimatedSwitcher(
              duration: const Duration(milliseconds: 200),
              child: loading
                  ? SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: context.colors.info,
                      ),
                    )
                  : (revealed
                        ? Row(
                            textDirection: TextDirection.rtl,
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                word ?? '',
                                textDirection: TextDirection.rtl,
                                style: context.legacyType.ar(
                                  17,
                                  weight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                '#${rank ?? 0}',
                                style: context.legacyType.mono(
                                  11,
                                  color: context.colors.info,
                                ),
                              ),
                            ],
                          )
                        : Text(
                            revealLabel,
                            style: context.legacyType.ar(
                              13,
                              color: context.colors.textSecondary,
                            ),
                          )),
            ),
          ],
        ),
      ),
    );
  }
}
