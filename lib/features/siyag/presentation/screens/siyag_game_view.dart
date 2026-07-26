import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_guess.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import 'siyag_topbar.dart';

/// Normalized guess for the view (word, rank, heat 0..1, solved).
class SiyagGuessVM {
  const SiyagGuessVM(this.word, this.rank, this.heat, {this.solved = false});
  final String word;
  final int rank;
  final double heat;
  final bool solved;
}

class SiyagHintVM {
  const SiyagHintVM(this.word, this.rank);
  final String word;
  final int rank;
}

enum SiyagSort { closest, newest, timeline }

/// Shared gameplay UI (gameplay.tsx). Presentation only — data + actions come
/// from a controller via the params. Used by weekly and practice games.
class SiyagGameView extends StatefulWidget {
  const SiyagGameView({
    super.key,
    required this.loc,
    required this.title,
    required this.guesses,
    required this.controller,
    required this.onSubmit,
    required this.submitting,
    required this.flash,
    required this.hints,
    required this.hintsRemaining,
    required this.hintLoading,
    required this.onRequestHint,
    this.unknownSuggestions = const [],
    this.onSuggestionTap,
    this.lastWord,
  });

  final AppLocalizations loc;
  final String title;
  final List<SiyagGuessVM> guesses; // attempt order (oldest first)
  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final bool submitting;
  final String? flash;
  final List<SiyagHintVM> hints;
  final int hintsRemaining;
  final bool hintLoading;
  final VoidCallback onRequestHint;
  final List<String> unknownSuggestions;
  final ValueChanged<String>? onSuggestionTap;
  final String? lastWord;

  @override
  State<SiyagGameView> createState() => _SiyagGameViewState();
}

class _SiyagGameViewState extends State<SiyagGameView> {
  SiyagSort _sort = SiyagSort.closest;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  void _submit() {
    final t = widget.controller.text.trim();
    if (t.isEmpty) return;
    widget.onSubmit(t);
    setState(() => _sort = SiyagSort.newest);
  }

  @override
  Widget build(BuildContext context) {
    final g = widget.guesses;
    SiyagGuessVM? closest;
    for (final x in g) {
      if (closest == null || x.heat > closest.heat) closest = x;
    }
    final newest = g.isNotEmpty ? g.last : null;
    final showLatest =
        newest != null && closest != null && newest.word != closest.word;

    final sorted = [...g];
    switch (_sort) {
      case SiyagSort.closest:
        sorted.sort((a, b) => b.heat.compareTo(a.heat));
        break;
      case SiyagSort.newest:
      case SiyagSort.timeline:
        // newest first for 'newest'; oldest-first for 'timeline'
        if (_sort == SiyagSort.newest) {
          // reverse insertion order
          sorted.setAll(0, [...g.reversed]);
        }
        break;
    }

    return Directionality(
      textDirection: widget.loc.direction,
      child: Scaffold(
        backgroundColor: SC.bg,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(title: widget.title, subtitle: '${g.length} GUESSES'),
              // Input
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                child: Container(
                  decoration: BoxDecoration(
                    color: SC.surface,
                    borderRadius: BorderRadius.circular(22),
                    border: Border.all(color: SC.lineStrong),
                  ),
                  padding: const EdgeInsetsDirectional.only(start: 16, end: 8),
                  child: Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: widget.controller,
                          focusNode: _focus,
                          textDirection: widget.loc.direction,
                          onSubmitted: (_) => _submit(),
                          textInputAction: TextInputAction.send,
                          style: ST.ar(20),
                          decoration: InputDecoration(
                            hintText: widget.loc('enterYourWord'),
                            hintStyle: ST.ar(20, color: SC.textFaint),
                            border: InputBorder.none,
                            contentPadding: const EdgeInsets.symmetric(
                              vertical: 16,
                            ),
                          ),
                        ),
                      ),
                      SiyagTap(
                        onTap: widget.submitting ? null : _submit,
                        scale: 0.88,
                        child: Container(
                          width: 48,
                          height: 48,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: SC.coral,
                            borderRadius: BorderRadius.circular(16),
                          ),
                          child: AnimatedSwitcher(
                            duration: const Duration(milliseconds: 200),
                            child: widget.submitting
                                ? SizedBox(
                                    width: 18,
                                    height: 18,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2.2,
                                      color: SC.onGold,
                                    ),
                                  )
                                : Icon(
                                    Icons.send_rounded,
                                    size: 18,
                                    color: SC.onGold,
                                  ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              // Flash
              SizedBox(
                height: 24,
                child: widget.flash == null
                    ? null
                    : Center(
                        child: Text(
                          widget.flash!,
                          style: ST.ar(13, color: SC.coral),
                        ),
                      ),
              ),
              // Unknown suggestions (edge state extended in-grammar)
              if (widget.unknownSuggestions.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in widget.unknownSuggestions)
                        SiyagTap(
                          onTap: () => widget.onSuggestionTap?.call(w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 8,
                            ),
                            decoration: BoxDecoration(
                              color: SC.surfaceHi,
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(color: SC.line),
                            ),
                            child: Text(w, style: ST.ar(14, color: SC.textDim)),
                          ),
                        ),
                    ],
                  ),
                ),
              // Summary chips
              if (closest != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
                  child: Row(
                    children: [
                      Expanded(
                        child: SiyagSummaryChip(
                          label: widget.loc('closest'),
                          emoji: '🔥',
                          word: closest.word,
                          rank: closest.rank,
                          color: SC.coral,
                          solved: closest.solved,
                        ),
                      ),
                      if (showLatest) ...[
                        const SizedBox(width: 10),
                        Expanded(
                          child: SiyagSummaryChip(
                            label: widget.loc('latest'),
                            emoji: '🆕',
                            word: newest.word,
                            rank: newest.rank,
                            color: SC.cyan,
                            solved: newest.solved,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              // Hints
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Kicker(widget.loc('hints')),
                ),
              ),
              SizedBox(
                height: 44,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  children: [
                    for (final h in widget.hints) ...[
                      SiyagHintPill(revealed: true, word: h.word, rank: h.rank),
                      const SizedBox(width: 8),
                    ],
                    if (widget.hintsRemaining > 0)
                      SiyagHintPill(
                        revealed: false,
                        loading: widget.hintLoading,
                        onReveal: widget.onRequestHint,
                        revealLabel: widget.loc('revealHint'),
                      ),
                  ],
                ),
              ),
              // Sort tabs
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
                child: Row(
                  children: [
                    for (final m in SiyagSort.values) ...[
                      _sortTab(m),
                      const SizedBox(width: 6),
                    ],
                  ],
                ),
              ),
              // Timeline
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                  children: [
                    for (final x in sorted)
                      SiyagGuessRow(
                        key: ValueKey(x.word),
                        word: x.word,
                        rank: x.rank,
                        heat: x.heat,
                        solved: x.solved,
                        isNewest: x.word == (widget.lastWord ?? newest?.word),
                        isClosest: x.word == closest?.word,
                        animateIn: x.word == widget.lastWord,
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sortTab(SiyagSort m) {
    final labels = {
      SiyagSort.closest: widget.loc('closest'),
      SiyagSort.newest: widget.loc('latest'),
      SiyagSort.timeline: widget.loc('timeline'),
    };
    final active = _sort == m;
    return SiyagTap(
      onTap: () {
        HapticFeedback.selectionClick();
        setState(() => _sort = m);
      },
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 180),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: active ? SC.coral : SC.surface,
          borderRadius: BorderRadius.circular(999),
        ),
        child: Text(
          labels[m]!,
          style: ST.ar(12, color: active ? SC.bg : SC.textMute),
        ),
      ),
    );
  }
}
