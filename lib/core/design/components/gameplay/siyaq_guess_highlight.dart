import 'package:flutter/material.dart';

import '../../gameplay/siyaq_heat.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';
import 'siyaq_guess_row.dart';

/// A persistent, single-line readout of one significant guess.
///
/// Gameplay pins two of these above the composer and they answer different
/// questions: **Closest** is the best result achieved so far, **Latest** is what
/// the player just submitted. They are frequently *not* the same guess, and the
/// difference between them is the feedback — submitting a worse word must
/// visibly not move the best result.
///
/// One 44px line, everything on it:
///
///     [band icon]  مطر …………………… #427  الأقرب
///
/// No kicker above the word, no stacked labels — this is glanced at before
/// every guess, and each extra line here is a history row the player loses.
/// When the Best word changes, [emphasised] rows flash briefly so an improved
/// best registers even mid-typing.
class SiyaqGuessHighlight extends StatelessWidget {
  const SiyaqGuessHighlight({
    super.key,
    required this.label,
    required this.guess,
    required this.distanceLabel,
    this.bandLabel,
    this.script,
    this.accent,
    this.emphasised = false,
  });

  /// State label — "Closest" or "Latest". Rendered at the trailing edge.
  final String label;

  final SiyaqGuessData guess;

  /// Localized band label ("Blazing", "دافئ") — spoken, and shown in place of
  /// the icon's tooltip meaning. Null when the mode carries no closeness
  /// signal — see [SiyaqGuessData.heat].
  final String? bandLabel;

  /// Localized word for the rank metric, e.g. "Distance". Spoken only; the
  /// visual is `#rank` (the phrase truncated to "Distance…" at 320px/2.0×).
  final String distanceLabel;

  /// Script of the guessed word — the *gameplay* language, not the UI locale.
  final SiyaqScript? script;

  /// Overrides the heat colour for the frame. Latest passes an informational
  /// accent so it never competes with Closest for "this is your best".
  final Color? accent;

  /// Heavier treatment + improvement flash. Used for Closest.
  final bool emphasised;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final heat = guess.heat;
    final heatColor = heat == null
        ? (guess.solved ? c.success : c.textSecondary)
        : SiyaqHeat.color(heat, solved: guess.solved, solvedColor: c.success);
    final frame = accent ?? heatColor;
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final row = Semantics(
      container: true,
      label: [
        '$label: ${guess.word}',
        ?bandLabel,
        '$distanceLabel ${guess.rank}',
      ].join(', '),
      child: ExcludeSemantics(
        child: AnimatedContainer(
          duration: context.motion.quick,
          curve: SiyaqMotion.easeOut,
          constraints: const BoxConstraints(minHeight: 44),
          padding: const EdgeInsets.symmetric(
            horizontal: SiyaqSpacing.md,
            vertical: SiyaqSpacing.xs,
          ),
          decoration: BoxDecoration(
            color: frame.withValues(alpha: emphasised ? 0.12 : 0.07),
            borderRadius: BorderRadius.circular(SiyaqRadius.lg),
            border: Border.all(
              color: frame.withValues(alpha: emphasised ? 0.55 : 0.30),
              width: emphasised ? 1.5 : 1,
            ),
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // At 320px/2.0x the full line cannot hold word + rank + label at
              // fixed widths. The word always survives; the rank drops its
              // alignment gutter first, then the state label truncates.
              final tight = box.maxWidth < 280 * scale;
              return Row(
                children: [
                  Icon(
                    guess.solved
                        ? SiyaqIcons.success
                        : (guess.band?.icon ?? SiyaqIcons.target),
                    size: SiyaqIconSize.sm,
                    color: heatColor,
                  ),
                  const SizedBox(width: SiyaqSpacing.sm),
                  Expanded(
                    child: SiyaqText(
                      guess.word,
                      role: SiyaqTextRole.bodyLarge,
                      script: script,
                      weight: emphasised ? FontWeight.w700 : FontWeight.w500,
                      color: guess.solved ? c.success : c.textPrimary,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: SiyaqSpacing.sm),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: tight ? 0 : 44 * scale.clamp(1.0, 1.6),
                    ),
                    // The rank *is* the score, and on device it was the least
                    // prominent thing in the row — muted 14px next to a bold
                    // 16px word. [SiyaqTextRole.gameDistance] exists for exactly
                    // this numeral and was unused outside the gallery.
                    //
                    // Kept at [textPrimary], never the heat colour: the ramp
                    // tokens are indicators and measure 1.69:1–2.80:1 as text.
                    child: SiyaqText.numeric(
                      '#${guess.rank}',
                      role: tight
                          ? SiyaqTextRole.labelMedium
                          : SiyaqTextRole.gameDistance,
                      color: c.textPrimary,
                      align: TextAlign.end,
                      maxLines: 1,
                    ),
                  ),
                  SizedBox(width: tight ? SiyaqSpacing.sm : SiyaqSpacing.md),
                  Flexible(
                    // Demoted to the smallest label: it tags the row, it is not
                    // the content, and at labelMedium/w600 it competed with the
                    // rank for the eye.
                    child: SiyaqText(
                      label,
                      role: SiyaqTextRole.labelSmall,
                      weight: FontWeight.w600,
                      color: frame,
                      maxLines: 1,
                    ),
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );

    // Only Best flashes — an improved best should register mid-typing; Latest
    // changes on every submit and flashing it would be noise.
    if (!emphasised) return row;
    return _ImprovementFlash(word: guess.word, color: frame, child: row);
  }
}

/// Brief glow when the tracked word changes — the Best row's "you just beat
/// your record". Skipped under reduced motion.
class _ImprovementFlash extends StatefulWidget {
  const _ImprovementFlash({
    required this.word,
    required this.color,
    required this.child,
  });

  final String word;
  final Color color;
  final Widget child;

  @override
  State<_ImprovementFlash> createState() => _ImprovementFlashState();
}

class _ImprovementFlashState extends State<_ImprovementFlash>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SiyaqMotion.reward,
  );

  @override
  void didUpdateWidget(_ImprovementFlash old) {
    super.didUpdateWidget(old);
    if (widget.word != old.word && !context.motion.reduced) {
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
      if (t == 0 || t == 1) return child!;
      // Quick swell, slow fade.
      final strength = t < 0.25 ? t / 0.25 : 1 - ((t - 0.25) / 0.75);
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(SiyaqRadius.lg),
          boxShadow: [
            BoxShadow(
              color: widget.color.withValues(alpha: 0.35 * strength),
              blurRadius: 14,
              spreadRadius: 1,
            ),
          ],
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}
