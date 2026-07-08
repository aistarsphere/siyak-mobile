import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/best_guess_card.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glow_button.dart';
import '../widgets/guess_row.dart';
import '../widgets/hint_pill.dart';
import '../widgets/pressable.dart';
import '../widgets/suggestion_chips.dart';
import '../widgets/top_app_bar.dart';
import '../widgets/unknown_word_card.dart';
import 'shell_screen.dart';
import 'solved_screen.dart';

class GameScreen extends ConsumerStatefulWidget {
  const GameScreen({super.key});

  @override
  ConsumerState<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends ConsumerState<GameScreen> {
  final _input = TextEditingController();
  final _focus = FocusNode();
  bool _focused = false;

  @override
  void initState() {
    super.initState();
    _focus.addListener(() => setState(() => _focused = _focus.hasFocus));
  }

  @override
  void dispose() {
    _input.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _submit([String? word]) async {
    final text = (word ?? _input.text).trim();
    if (text.isEmpty) return;
    final controller = ref.read(gameControllerProvider.notifier);
    await controller.submitGuess(text);
    final state = ref.read(gameControllerProvider);
    // Keep the invalid word in the field (as in the Stitch unknown-word
    // screen); clear it on any accepted/duplicate result.
    if (state.unknown == null && mounted) {
      _input.clear();
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(gameControllerProvider);

    // Duplicate canonical guess → transient snackbar, attempts unchanged.
    // Keyed on a monotonic sequence so every duplicate event notifies,
    // including re-submitting the same word.
    ref.listen(gameControllerProvider.select((s) => s.duplicateSeq),
        (prev, next) {
      if (next > (prev ?? 0)) {
        final word = ref.read(gameControllerProvider).duplicateWord;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
            content: Text('${loc('duplicateGuess')} · $word'),
            duration: const Duration(seconds: 2),
          ));
      }
    });

    // Non-400 errors → snackbar.
    ref.listen(gameControllerProvider.select((s) => s.error), (prev, next) {
      if (next != null && next != prev) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(loc.errorMessage(next))));
        ref.read(gameControllerProvider.notifier).clearError();
      }
    });

    // Solved → push the celebration screen.
    ref.listen(gameControllerProvider.select((s) => s.solved), (prev, next) {
      if (next == true && prev != true) {
        _input.clear();
        _focus.unfocus();
        Navigator.of(context).push(
          PageRouteBuilder(
            transitionDuration: AppMotion.screen,
            pageBuilder: (_, animation, _) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(
                    CurvedAnimation(parent: animation, curve: AppMotion.easeOut)),
                child: const SolvedScreen(),
              ),
            ),
          ),
        );
      }
    });

    final hasGame = state.hasGame;

    return Column(
      children: [
        SiyaqTopBar(
          title: loc('appTitle'),
          onLanguageTap: () =>
              ref.read(appSettingsProvider.notifier).toggleLang(),
          trailing: Pressable(
            onTap: () => ref.read(shellTabProvider.notifier).state = 2,
            child: const Icon(Icons.leaderboard_outlined,
                size: 20, color: AppColors.onSurfaceVariant),
          ),
        ),
        if (!hasGame)
          Expanded(child: _NoGame(loc: loc))
        else
          Expanded(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Top stats row
                  GlassPanel(
                    opacity: 0.10,
                    borderRadius: BorderRadius.circular(8),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Row(children: [
                          const Icon(Icons.category_outlined,
                              size: 16, color: AppColors.secondary),
                          const SizedBox(width: 4),
                          Text(state.categoryLabel,
                              style: AppTypography.labelMd
                                  .copyWith(color: AppColors.onSurface)),
                        ]),
                        Row(children: [
                          Text(loc('attempts'),
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                          const SizedBox(width: 4),
                          Text('${state.attempts}',
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.onSurface)),
                        ]),
                        Row(children: [
                          const Icon(Icons.emoji_events,
                              size: 16, color: AppColors.primary),
                          const SizedBox(width: 4),
                          Text(loc('best'),
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant)),
                          const SizedBox(width: 4),
                          Text(state.bestRank == 0 ? '—' : '#${state.bestRank}',
                              style: AppTypography.bodySm
                                  .copyWith(color: AppColors.primary)),
                        ]),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  // Input + send
                  _GuessInput(
                    controller: _input,
                    focusNode: _focus,
                    focused: _focused,
                    error: state.unknown != null,
                    busy: state.submitting,
                    hint: loc('inputHint'),
                    onChanged: (t) => ref
                        .read(gameControllerProvider.notifier)
                        .onInputChanged(t),
                    onSubmit: _submit,
                  ),
                  const SizedBox(height: 8),
                  // Autocomplete chips
                  SuggestionChips(
                    words: state.autocomplete,
                    onTap: (w) {
                      _input.text = w;
                      _submit(w);
                    },
                  ),
                  const SizedBox(height: 8),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.only(bottom: 120),
                      children: [
                        // Unknown word card
                        if (state.unknown != null) ...[
                          UnknownWordCard(
                            state: state.unknown!,
                            loc: loc,
                            onSuggestionTap: (w) {
                              _input.text = w;
                              _submit(w);
                            },
                          ),
                          const SizedBox(height: 12),
                        ],
                        // Best guess bento card
                        if (state.bestGuess != null) ...[
                          BestGuessCard(best: state.bestGuess!, loc: loc),
                          const SizedBox(height: 12),
                        ],
                        // Hints row (pills + request button)
                        _HintsRow(loc: loc, state: state, ref: ref),
                        const SizedBox(height: 12),
                        // History
                        if (state.guesses.isNotEmpty) ...[
                          Padding(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 4, vertical: 4),
                            child: Text(
                              '${loc('historyTitle')} (${state.attempts})',
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ),
                          for (final g in state.sortedGuesses)
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
          ),
      ],
    );
  }
}

class _NoGame extends ConsumerWidget {
  const _NoGame({required this.loc});

  final dynamic loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.play_circle_outline,
                size: 64, color: AppColors.primary.withValues(alpha: 0.5)),
            const SizedBox(height: 16),
            Text(
              loc('tagline'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: loc('newGame'),
              icon: Icons.play_arrow,
              onTap: () => ref.read(shellTabProvider.notifier).state = 0,
            ),
          ],
        ),
      ),
    );
  }
}

/// Large glass input with the Stitch focus treatment (amber bottom border
/// fading in) and the glowing amber send button at the trailing edge.
class _GuessInput extends StatelessWidget {
  const _GuessInput({
    required this.controller,
    required this.focusNode,
    required this.focused,
    required this.error,
    required this.busy,
    required this.hint,
    required this.onChanged,
    required this.onSubmit,
  });

  final TextEditingController controller;
  final FocusNode focusNode;
  final bool focused;
  final bool error;
  final bool busy;
  final String hint;
  final ValueChanged<String> onChanged;
  final VoidCallback onSubmit;

  @override
  Widget build(BuildContext context) {
    final underline = error
        ? AppColors.error
        : focused
            ? AppColors.amber
            : Colors.transparent;
    return Stack(
      alignment: AlignmentDirectional.centerEnd,
      children: [
        AnimatedContainer(
          duration: AppMotion.focus,
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(12),
            border: Border(bottom: BorderSide(color: underline, width: 2)),
            boxShadow: focused
                ? [BoxShadow(color: AppColors.amberGlow(0.15), blurRadius: 16)]
                : const [],
          ),
          child: TextField(
            controller: controller,
            focusNode: focusNode,
            onChanged: onChanged,
            onSubmitted: (_) => onSubmit(),
            textInputAction: TextInputAction.send,
            style: AppTypography.bodyLg.copyWith(
                color: error ? AppColors.error : AppColors.onSurface),
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTypography.bodyLg.copyWith(
                color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
              ),
              border: InputBorder.none,
              contentPadding: const EdgeInsetsDirectional.only(
                  start: 16, end: 64, top: 20, bottom: 20),
            ),
          ),
        ),
        PositionedDirectional(
          end: 8,
          child: Pressable(
            onTap: busy ? null : onSubmit,
            child: Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: error
                    ? AppColors.error.withValues(alpha: 0.15)
                    : AppColors.primaryContainer,
                borderRadius: BorderRadius.circular(8),
                boxShadow: error
                    ? const []
                    : [
                        BoxShadow(
                            color: AppColors.amberGlow(0.4), blurRadius: 15),
                      ],
              ),
              child: busy
                  ? const SizedBox(
                      width: 22,
                      height: 22,
                      child: CircularProgressIndicator(
                          strokeWidth: 2.4,
                          color: AppColors.onPrimaryContainer),
                    )
                  : Icon(Icons.send,
                      size: 22,
                      color: error
                          ? AppColors.error
                          : AppColors.onPrimaryContainer),
            ),
          ),
        ),
      ],
    );
  }
}

class _HintsRow extends StatelessWidget {
  const _HintsRow({required this.loc, required this.state, required this.ref});

  final dynamic loc;
  final GameState state;
  final WidgetRef ref;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        for (var i = 0; i < state.hints.length; i++)
          HintPill(
            hint: state.hints[i],
            loc: ref.read(localizationsProvider),
            animateIn: i == state.hints.length - 1,
          ),
        // Request-hint pill
        Pressable(
          onTap: state.hintsExhausted || state.hintLoading || state.solved
              ? null
              : () =>
                  ref.read(gameControllerProvider.notifier).requestHint(),
          child: Opacity(
            opacity: state.hintsExhausted ? 0.45 : 1,
            child: Container(
              padding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.secondary.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(
                    color: AppColors.secondary.withValues(alpha: 0.5)),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (state.hintLoading)
                    const SizedBox(
                      width: 14,
                      height: 14,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: AppColors.secondary),
                    )
                  else
                    const Icon(Icons.lightbulb_outline,
                        size: 14, color: AppColors.secondary),
                  const SizedBox(width: 4),
                  Text(
                    state.hintsExhausted
                        ? loc('noMoreHints')
                        : '${loc('hint')} ${state.hintsUsed}/5',
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.secondary),
                  ),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }
}
