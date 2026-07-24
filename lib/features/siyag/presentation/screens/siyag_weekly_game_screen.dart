import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/hint_mode.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';
import '../siyag_route.dart';
import 'siyag_game_view.dart';
import 'siyag_result_screen.dart';

/// Weekly gameplay — the shared game view wired to the live V2 weekly run.
class SiyagWeeklyGameScreen extends ConsumerStatefulWidget {
  const SiyagWeeklyGameScreen({super.key});

  @override
  ConsumerState<SiyagWeeklyGameScreen> createState() =>
      _SiyagWeeklyGameScreenState();
}

class _SiyagWeeklyGameScreenState
    extends ConsumerState<SiyagWeeklyGameScreen> {
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
      SiyagHeat.fromRank(rank, total, solved: solved);

  Future<void> _submit(String word) async {
    await ref.read(weeklyRunControllerProvider.notifier).submitGuess(word);
    final s = ref.read(weeklyRunControllerProvider);
    if (s.unknownWord == null && mounted) _input.clear();
  }

  void _showFlash(String msg) {
    setState(() => _flash = msg);
    _flashTimer?.cancel();
    _flashTimer = Timer(const Duration(milliseconds: 2200),
        () => mounted ? setState(() => _flash = null) : null);
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(weeklyRunControllerProvider);
    final run = state.run;

    // Progress flash on each newly accepted guess.
    ref.listen(weeklyRunControllerProvider.select((s) => s.run?.guesses.length),
        (prev, next) {
      final r = ref.read(weeklyRunControllerProvider).run;
      if (r == null || r.guesses.isEmpty) return;
      final best = r.guesses
          .map((g) => _heat(g.rank, r.totalWords, g.isSecret))
          .reduce((a, b) => a > b ? a : b);
      _showFlash(SiyagHeat.progressMessage(_prevBest, best));
      _prevBest = best;
    });

    // Duplicate feedback.
    ref.listen(weeklyRunControllerProvider.select((s) => s.duplicateSeq),
        (prev, next) {
      if (next > (prev ?? 0)) {
        final w = ref.read(weeklyRunControllerProvider).duplicateCanonical;
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(
              content:
                  Text(loc.fill('canonicalDuplicate', {'w': w ?? ''}))));
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
    // Solved → result.
    ref.listen(weeklyRunControllerProvider.select((s) => s.run?.solved ?? false),
        (prev, next) {
      if (next == true && prev != true) {
        final r = ref.read(weeklyRunControllerProvider).run;
        Navigator.of(context).pushReplacement(siyagRoute(SiyagResultScreen(
          secretWord: r?.secretWord ?? '',
          attempts: r?.attempts ?? 0,
          hintsUsed: r?.hintsUsed ?? 0,
          elapsed: r?.elapsed,
        )));
      }
    });

    if (run == null) {
      return const Scaffold(
        backgroundColor: SC.bg,
        body: Center(child: CircularProgressIndicator(color: SC.coral)),
      );
    }

    final total = run.totalWords;
    return SiyagGameView(
      title: 'التحدي الأسبوعي',
      guesses: [
        for (final g in run.guesses)
          SiyagGuessVM(g.word, g.rank, _heat(g.rank, total, g.isSecret),
              solved: g.isSecret),
      ],
      controller: _input,
      onSubmit: _submit,
      submitting: state.submitting,
      flash: _flash,
      hints: [for (final h in state.hints) SiyagHintVM(h.word, h.semanticRank)],
      hintsRemaining: run.hintsRemaining,
      hintLoading: state.hintLoading,
      onRequestHint: () => ref
          .read(weeklyRunControllerProvider.notifier)
          .requestHint(HintMode.adaptive),
      unknownSuggestions:
          state.unknownWord != null ? state.unknownSuggestions : const [],
      onSuggestionTap: (w) {
        _input.text = w;
        _submit(w);
      },
      lastWord: state.lastGuessWord,
    );
  }
}
