import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/gameplay/siyaq_heat.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/game_controller.dart';
import '../siyag_route.dart';
import 'siyag_game_view.dart';
import 'siyag_result_screen.dart';

/// Solo Practice gameplay — the shared game view wired to the V1 game
/// controller (V1 fallback preserved). Unlimited practice.
class SiyagPracticeGameScreen extends ConsumerStatefulWidget {
  const SiyagPracticeGameScreen({super.key});

  @override
  ConsumerState<SiyagPracticeGameScreen> createState() =>
      _SiyagPracticeGameScreenState();
}

class _SiyagPracticeGameScreenState
    extends ConsumerState<SiyagPracticeGameScreen> {
  final _input = TextEditingController();
  String? _flash;
  double? _prevBest;
  Timer? _flashTimer;

  @override
  void dispose() {
    _input.dispose();
    _flashTimer?.cancel();
    super.dispose();
  }

  double _heat(int rank, int total, bool solved) =>
      SiyaqHeat.fromRank(rank, total, solved: solved);

  Future<void> _submit(String word) async {
    await ref.read(gameControllerProvider.notifier).submitGuess(word);
    if (ref.read(gameControllerProvider).unknown == null && mounted) {
      _input.clear();
    }
  }

  void _showFlash(String msg) {
    setState(() => _flash = msg);
    _flashTimer?.cancel();
    _flashTimer = Timer(
      const Duration(milliseconds: 2200),
      () => mounted ? setState(() => _flash = null) : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(gameControllerProvider);

    ref.listen(gameControllerProvider.select((s) => s.guesses.length), (
      prev,
      next,
    ) {
      final s = ref.read(gameControllerProvider);
      if (s.guesses.isEmpty) return;
      final best = s.guesses
          .map((g) => _heat(g.rank, s.totalWords, g.isSecret))
          .reduce((a, b) => a > b ? a : b);
      _showFlash(SiyaqHeat.progressMessage(_prevBest, best));
      _prevBest = best;
    });
    ref.listen(gameControllerProvider.select((s) => s.duplicateSeq), (
      prev,
      next,
    ) {
      if (next > (prev ?? 0)) {
        final w = ref.read(gameControllerProvider).duplicateWord;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(
            SnackBar(content: Text('${loc('duplicateGuess')} · $w')),
          );
      }
    });
    ref.listen(gameControllerProvider.select((s) => s.error), (p, n) {
      if (n != null && n != p) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(loc.errorMessage(n))));
        ref.read(gameControllerProvider.notifier).clearError();
      }
    });
    ref.listen(gameControllerProvider.select((s) => s.solved), (prev, next) {
      if (next == true && prev != true) {
        final s = ref.read(gameControllerProvider);
        Navigator.of(context).pushReplacement(
          siyagRoute(
            SiyagResultScreen(
              secretWord:
                  s.secretWord ??
                  (s.guesses.where((g) => g.isSecret).firstOrNull?.word ?? ''),
              attempts: s.attempts,
              hintsUsed: s.hintsUsed,
              showLeaderboard: false,
            ),
          ),
        );
      }
    });

    final total = state.totalWords;
    return SiyagGameView(
      loc: loc,
      title: state.categoryLabel.isEmpty
          ? loc('modeSolo')
          : state.categoryLabel,
      guesses: [
        for (final g in state.guesses)
          SiyagGuessVM(
            g.word,
            g.rank,
            _heat(g.rank, total, g.isSecret),
            solved: g.isSecret,
          ),
      ],
      controller: _input,
      onSubmit: _submit,
      submitting: state.submitting,
      flash: _flash,
      hints: [for (final h in state.hints) SiyagHintVM(h.word, h.rank)],
      // Server-authoritative (contract §6 `hints_remaining`), reconciled in the
      // controller on each guess/hint — not a hard-coded client cap.
      hintsRemaining: state.hintsRemaining,
      hintLoading: state.hintLoading,
      onRequestHint: () =>
          ref.read(gameControllerProvider.notifier).requestHint(),
      unknownSuggestions: state.unknown != null
          ? state.unknown!.suggestions
          : const [],
      onSuggestionTap: (w) {
        _input.text = w;
        _submit(w);
      },
      lastWord: state.lastGuessWord,
    );
  }
}
