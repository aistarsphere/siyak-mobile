import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/best_guess_card.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/guess_row.dart';
import '../../../game/presentation/widgets/pressable.dart';
import '../../domain/entities/hint_mode.dart';
import '../controllers/weekly_controller.dart';
import '../widgets/adaptive_hint_pill.dart';
import '../widgets/v2_guess_input.dart';
import '../widgets/v2_scaffold.dart';
import 'weekly_result_screen.dart';

/// Weekly gameplay — reuses the accepted game components, clearly labelled as
/// the Weekly Challenge. Gameplay language is locked (no language toggle here).
class WeeklyGameScreen extends ConsumerStatefulWidget {
  const WeeklyGameScreen({super.key});

  @override
  ConsumerState<WeeklyGameScreen> createState() => _WeeklyGameScreenState();
}

class _WeeklyGameScreenState extends ConsumerState<WeeklyGameScreen> {
  final _input = TextEditingController();

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(String word) async {
    await ref.read(weeklyRunControllerProvider.notifier).submitGuess(word);
    if (ref.read(weeklyRunControllerProvider).unknownWord == null && mounted) {
      _input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(weeklyRunControllerProvider);
    final run = state.run;

    // Canonical duplicate → transient message (no attempt added).
    ref.listen(weeklyRunControllerProvider.select((s) => s.duplicateSeq), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) {
        final w = ref.read(weeklyRunControllerProvider).duplicateCanonical;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(
              content: Text(loc.fill('canonicalDuplicate', {'w': w ?? ''})),
              duration: const Duration(seconds: 2),
            ),
          );
      }
    });
    ref.listen(weeklyRunControllerProvider.select((s) => s.error), (p, n) {
      if (n != null && n != p) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(loc.errorMessage(n))));
        ref.read(weeklyRunControllerProvider.notifier).clearError();
      }
    });
    ref.listen(
      weeklyRunControllerProvider.select((s) => s.run?.solved ?? false),
      (prev, next) {
        if (next == true && prev != true) {
          Navigator.of(context).pushReplacement(
            PageRouteBuilder(
              transitionDuration: AppMotion.screen,
              pageBuilder: (_, a, _) =>
                  FadeTransition(opacity: a, child: const WeeklyResultScreen()),
            ),
          );
        }
      },
    );

    return V2Scaffold(
      title: loc('modeWeekly'),
      child: run == null
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Mode label + stats (attempts / best / hints)
                  GlassPanel(
                    opacity: 0.1,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 10,
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.calendar_today,
                              size: 14,
                              color: AppColors.secondary,
                            ),
                            const SizedBox(width: 4),
                            Text(
                              loc('modeWeekly'),
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurface,
                              ),
                            ),
                          ],
                        ),
                        Text(
                          '${loc('attempts')} ${run.attempts}',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                          ),
                        ),
                        Text(
                          run.bestUserGeneratedRank == null
                              ? '${loc('best')} —'
                              : '${loc('best')} #${run.bestUserGeneratedRank}',
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  V2GuessInput(
                    controller: _input,
                    hint: loc('inputHint'),
                    busy: state.submitting,
                    error: state.unknownWord != null,
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 12),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 100),
                      children: [
                        if (state.unknownWord != null) ...[
                          _UnknownRow(
                            suggestions: state.unknownSuggestions,
                            loc: loc,
                            onTap: (w) {
                              _input.text = w;
                              _submit(w);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        if (run.bestGuess != null) ...[
                          BestGuessCard(best: run.bestGuess!, loc: loc),
                          const SizedBox(height: 12),
                        ],
                        // Hints (adaptive/standard) + request button
                        Wrap(
                          spacing: 8,
                          runSpacing: 8,
                          children: [
                            for (var i = 0; i < state.hints.length; i++)
                              AdaptiveHintPill(
                                hint: state.hints[i],
                                hintLabel: loc('hintPrefix'),
                                animateIn: i == state.hints.length - 1,
                              ),
                            _HintButton(run: run, state: state, loc: loc),
                          ],
                        ),
                        const SizedBox(height: 12),
                        if (run.guesses.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 4,
                              vertical: 4,
                            ),
                            child: Text(
                              '${loc('historyTitle')} (${run.attempts})',
                              style: AppTypography.labelMd.copyWith(
                                color: AppColors.onSurfaceVariant,
                              ),
                            ),
                          ),
                          for (final g in run.sortedGuesses)
                            Padding(
                              padding: const EdgeInsets.only(bottom: 4),
                              child: GuessRow(
                                key: ValueKey(g.word),
                                guess: g,
                                highlighted: g.word == state.lastGuessWord,
                                animateIn: g.word == state.lastGuessWord,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

class _HintButton extends ConsumerWidget {
  const _HintButton({
    required this.run,
    required this.state,
    required this.loc,
  });

  final dynamic run;
  final WeeklyRunState state;
  final dynamic loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final exhausted = run.hintsExhausted as bool;
    return Pressable(
      onTap: exhausted || state.hintLoading || (run.solved as bool)
          ? null
          : () {
              // Adaptive when the run was started adaptive; here we request
              // adaptive if capabilities enabled it (best-effort mock).
              ref
                  .read(weeklyRunControllerProvider.notifier)
                  .requestHint(HintMode.adaptive);
            },
      child: Opacity(
        opacity: exhausted ? 0.45 : 1,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.secondary.withValues(alpha: 0.12),
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color: AppColors.secondary.withValues(alpha: 0.5),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (state.hintLoading)
                const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: AppColors.secondary,
                  ),
                )
              else
                const Icon(
                  Icons.lightbulb_outline,
                  size: 14,
                  color: AppColors.secondary,
                ),
              const SizedBox(width: 4),
              Text(
                exhausted
                    ? loc('noMoreHints')
                    : '${loc('hint')} ${run.hintsUsed}/${run.maxHints}',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.secondary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _UnknownRow extends StatelessWidget {
  const _UnknownRow({
    required this.suggestions,
    required this.loc,
    required this.onTap,
  });

  final List<String> suggestions;
  final dynamic loc;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.3,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.error_outline, size: 20, color: AppColors.error),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  loc('unknownWord'),
                  style: AppTypography.bodySm.copyWith(
                    color: AppColors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (suggestions.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(
              loc('didYouMean'),
              style: AppTypography.labelXs.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final w in suggestions)
                  Pressable(
                    onTap: () => onTap(w),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHighest.withValues(
                          alpha: 0.6,
                        ),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: AppColors.outline.withValues(alpha: 0.2),
                        ),
                      ),
                      child: Text(
                        w,
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}
