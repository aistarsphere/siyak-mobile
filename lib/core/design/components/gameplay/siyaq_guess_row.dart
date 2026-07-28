import 'package:flutter/material.dart';

import '../../gameplay/siyaq_heat.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';

/// One scored guess, as gameplay renders it.
///
/// The screens own the game state; this is the normalised shape the gameplay
/// components read, so Best Guess, Latest Guess and the history list cannot
/// drift apart in how they describe the same guess.
@immutable
class SiyaqGuessData {
  const SiyaqGuessData({
    required this.word,
    required this.rank,
    this.heat,
    this.solved = false,
  });

  /// The canonical word, in the *gameplay* language — not the UI language.
  final String word;

  /// Server rank. 1 is the secret word; this is the game's distance metric.
  final int rank;

  /// Closeness on the continuous heat ramp, 0..1.
  ///
  /// **Null means the mode has no closeness signal**, not "cold". Ranked
  /// snapshots carry a rank and nothing else, and deriving heat there would need
  /// a vocabulary size the server never sends — so the components render rank
  /// only rather than fabricate a band.
  final double? heat;

  final bool solved;

  /// Null when [heat] is null.
  SiyaqHeatBand? get band =>
      heat == null ? null : SiyaqHeat.bandOf(heat!, solved: solved);
}

/// Who played a guess, in a mode where more than one player can.
@immutable
class SiyaqGuessAttribution {
  const SiyaqGuessAttribution({
    required this.label,
    required this.icon,
    this.color,
  });

  /// Short display name, or a dash for a system-revealed hint.
  final String label;

  final IconData icon;

  /// Defaults to `colors.textMuted`. Rooms tint by author so a player can find
  /// their own guesses in a shared timeline at a glance.
  final Color? color;
}

/// A compact row in the ranked guess history.
///
/// Deliberately dense — roughly one 44px row per guess — because the player is
/// scanning twenty of these, not reading cards. Closeness is carried four ways
/// (edge bar, fill length, band icon, band label) so it survives greyscale and
/// colour vision deficiency; colour alone is never the signal.
class SiyaqGuessRow extends StatelessWidget {
  const SiyaqGuessRow({
    super.key,
    required this.guess,
    required this.rankLabel,
    this.bandLabel,
    this.isBest = false,
    this.isLatest = false,
    this.script,
    this.statusLabel,
    this.attribution,
    this.animateIn = false,
    this.pulseTrigger = 0,
  });

  final SiyaqGuessData guess;

  /// Localized word for "rank", spoken before the number. `#12` reads as
  /// "hash twelve" otherwise.
  final String rankLabel;

  /// Localized band label ("Blazing", "دافئ"). Supply it whenever the guess has
  /// a heat value — with heat but no label the row still renders, it just loses
  /// the band from its announcement. Passed in so the component stays free of
  /// localization plumbing.
  final String? bandLabel;

  final bool isBest;
  final bool isLatest;

  /// Script of the guessed word. Gameplay content follows the *game* language,
  /// which can differ from the UI locale.
  final SiyaqScript? script;

  /// Appended to the row's announcement, e.g. "closest so far".
  final String? statusLabel;

  /// Who played this guess. Only shown in shared modes (room, ranked); solo and
  /// weekly leave it null because every guess is the player's own.
  final SiyaqGuessAttribution? attribution;

  /// Fade+slide the row in — used for the guess just submitted.
  final bool animateIn;

  /// Bump to pulse the row — the "you already played this one" nudge on the
  /// existing duplicate. Zero means never.
  final int pulseTrigger;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final heat = guess.heat;
    // With no closeness signal the accent falls back to the solved/neutral pair
    // rather than pretending the guess is cold.
    final accent = heat == null
        ? (guess.solved ? c.success : c.border)
        : SiyaqHeat.color(heat, solved: guess.solved, solvedColor: c.success);

    // The gutter is a *minimum*, not a width: ranks run to five digits in a
    // 20k-word vocabulary, and a fixed box clipped them to "#184…".
    final scale = MediaQuery.textScalerOf(context).scale(1);

    final announcement = [
      guess.word,
      '$rankLabel ${guess.rank}',
      ?bandLabel,
      ?attribution?.label,
      ?statusLabel,
    ].join(', ');

    final row = Semantics(
      container: true,
      label: announcement,
      child: ExcludeSemantics(
        child: Container(
          decoration: BoxDecoration(
            color: isBest
                ? accent.withValues(alpha: 0.10)
                : isLatest
                ? c.surface
                : Colors.transparent,
            borderRadius: BorderRadius.circular(SiyaqRadius.md),
            border: BorderDirectional(
              start: BorderSide(color: accent, width: isBest ? 3 : 2),
            ),
          ),
          padding: const EdgeInsetsDirectional.fromSTEB(
            SiyaqSpacing.md,
            SiyaqSpacing.sm,
            SiyaqSpacing.md,
            SiyaqSpacing.sm,
          ),
          child: LayoutBuilder(
            builder: (context, box) {
              // Attribution is a hard requirement in shared modes, so when the
              // row runs out of width the meter goes first: it is the one
              // closeness signal already restated by the icon and the band.
              final tight = box.maxWidth < 260 * scale;
              return Row(
                children: [
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      minWidth: 44 * scale.clamp(1.0, 1.6),
                    ),
                    child: SiyaqText.numeric(
                      '#${guess.rank}',
                      role: SiyaqTextRole.labelMedium,
                      color: c.textMuted,
                      maxLines: 1,
                    ),
                  ),
                  const SizedBox(width: SiyaqSpacing.sm),
                  Expanded(
                    child: SiyaqText(
                      guess.word,
                      role: SiyaqTextRole.bodyLarge,
                      script: script,
                      weight: isBest ? FontWeight.w700 : FontWeight.w500,
                      color: guess.solved ? c.success : c.textPrimary,
                      maxLines: 1,
                    ),
                  ),
                  if (heat != null) ...[
                    if (!tight) ...[
                      const SizedBox(width: SiyaqSpacing.sm),
                      _HeatMeter(value: heat, color: accent),
                    ],
                    const SizedBox(width: SiyaqSpacing.sm),
                    Icon(
                      guess.solved ? SiyaqIcons.success : guess.band!.icon,
                      size: SiyaqIconSize.sm,
                      color: accent,
                    ),
                  ] else if (guess.solved) ...[
                    const SizedBox(width: SiyaqSpacing.sm),
                    Icon(
                      SiyaqIcons.success,
                      size: SiyaqIconSize.sm,
                      color: c.success,
                    ),
                  ],
                  if (attribution != null) ...[
                    const SizedBox(width: SiyaqSpacing.sm),
                    _Attribution(data: attribution!, tight: tight),
                  ],
                ],
              );
            },
          ),
        ),
      ),
    );

    final pulsed = pulseTrigger == 0
        ? row
        : _RowPulse(trigger: pulseTrigger, color: accent, child: row);

    if (!animateIn) return pulsed;
    return TweenAnimationBuilder<double>(
      key: ValueKey('in-${guess.word}'),
      tween: Tween(begin: 0, end: 1),
      duration: context.motion.summaryIn,
      curve: SiyaqMotion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, 8 * (1 - t)),
          child: child,
        ),
      ),
      child: pulsed,
    );
  }
}

/// Brief background flash used to point at an already-played word — colour
/// pulses in and decays, no layout change. Skipped under reduced motion.
class _RowPulse extends StatefulWidget {
  const _RowPulse({
    required this.trigger,
    required this.color,
    required this.child,
  });

  final int trigger;
  final Color color;
  final Widget child;

  @override
  State<_RowPulse> createState() => _RowPulseState();
}

class _RowPulseState extends State<_RowPulse>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: SiyaqMotion.pulse,
  );

  @override
  void initState() {
    super.initState();
    // A row can mount *because of* the duplicate (list rebuilt) — pulse once on
    // arrival too, not only on in-place trigger changes.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && !context.motion.reduced) _controller.forward(from: 0);
    });
  }

  @override
  void didUpdateWidget(_RowPulse old) {
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
      // Fast attack, slow decay.
      final strength = t < 0.2 ? t / 0.2 : 1 - ((t - 0.2) / 0.8);
      return DecoratedBox(
        decoration: BoxDecoration(
          color: widget.color.withValues(alpha: 0.18 * strength),
          borderRadius: BorderRadius.circular(SiyaqRadius.md),
        ),
        child: child,
      );
    },
    child: widget.child,
  );
}

/// The short fixed-width closeness meter used inside a history row.
class _HeatMeter extends StatelessWidget {
  const _HeatMeter({required this.value, required this.color});

  final double value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    // Shrinks rather than disappears at large text scales: the meter is one of
    // four redundant closeness signals, so losing width is acceptable but
    // losing the row to overflow is not.
    final scale = MediaQuery.textScalerOf(context).scale(1);
    final width = (56 / scale).clamp(24.0, 56.0);
    return SizedBox(
      width: width,
      height: 6,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: context.colors.surfaceStrong,
          borderRadius: BorderRadius.circular(SiyaqRadius.full),
        ),
        child: Align(
          alignment: AlignmentDirectional.centerStart,
          child: FractionallySizedBox(
            widthFactor: value.clamp(0.04, 1.0),
            heightFactor: 1,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: color,
                borderRadius: BorderRadius.circular(SiyaqRadius.full),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Author badge at the reading end of a shared-history row.
class _Attribution extends StatelessWidget {
  const _Attribution({required this.data, this.tight = false});

  final SiyaqGuessAttribution data;

  /// Narrow row: cap the name harder rather than push the word off the edge.
  final bool tight;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final colour = data.color ?? c.textMuted;
    final scale = MediaQuery.textScalerOf(context).scale(1);
    return ConstrainedBox(
      // Capped so a long display name can never squeeze the word it belongs to.
      constraints: BoxConstraints(
        maxWidth: tight ? 48 : (72 * scale).clamp(56.0, 120.0),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(data.icon, size: SiyaqIconSize.xs, color: colour),
          const SizedBox(width: SiyaqSpacing.xxxs),
          Flexible(
            child: SiyaqText(
              data.label,
              role: SiyaqTextRole.labelSmall,
              script: SiyaqScript.mono,
              color: colour,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}
