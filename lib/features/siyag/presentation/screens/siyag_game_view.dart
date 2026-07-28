import 'package:flutter/material.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/widgets/translation_assist.dart';
import '../../../v2/domain/entities/gameplay_language.dart';

/// Normalized guess for the view (word, rank, heat 0..1, solved).
typedef SiyagGuessVM = SiyaqGuessData;

/// A revealed hint (word, rank).
typedef SiyagHintVM = SiyaqHintData;

/// The shared core gameplay experience — used by Solo Practice and Weekly.
///
/// Presentation only: data and actions come from a controller through the
/// params. The hierarchy is fixed even though the layout is not:
///
///   header → hints → timeline (scrolls up) → best → latest → composer
///
/// The timeline is **bottom-anchored** on a real `reverse: true` viewport, not a
/// reordered list, so submitting never shifts what is already on screen — the
/// scroll offset is measured from the bottom.
///
/// It is ordered **by closeness, not by time**: the best guess climbs to the top
/// and the weakest sits by the composer. The API returns `previous_guesses`
/// ranked and sends no per-guess timestamp, so a true chronology cannot be
/// reconstructed here; the most recent guess is marked instead, via [lastWord].
///
/// **Two languages, two directions.** The chrome (title, labels, buttons)
/// follows the app locale via [loc]; the *content* — every guessed word, every
/// hint, the composer itself — follows [gameLanguage]. An English game played
/// inside an Arabic app types and reads left-to-right with Latin metrics, and
/// vice versa. Mixing the two was the pre-existing bug this replaces.
class SiyagGameView extends StatefulWidget {
  const SiyagGameView({
    super.key,
    required this.loc,
    required this.title,
    required this.gameLanguage,
    required this.guesses,
    required this.controller,
    required this.onSubmit,
    required this.submitting,
    required this.flash,
    required this.hints,
    required this.hintsRemaining,
    required this.hintLoading,
    required this.onRequestHint,
    this.solved = false,
    this.unknownSuggestions = const [],
    this.onSuggestionTap,
    this.inputError,
    this.lastWord,
    this.duplicateWord,
    this.duplicateSeq = 0,
    this.onBack,
  });

  final AppLocalizations loc;
  final String title;

  /// Language of the game *content* — locked when the session was created.
  final GameplayLanguage gameLanguage;

  /// Every guess played so far. **Order is not chronological** — see the class
  /// doc; use [lastWord] to identify the most recent one.
  final List<SiyagGuessVM> guesses;

  final TextEditingController controller;
  final ValueChanged<String> onSubmit;
  final bool submitting;

  /// Transient progress message shown under the header.
  final String? flash;

  final List<SiyagHintVM> hints;
  final int hintsRemaining;
  final bool hintLoading;
  final VoidCallback onRequestHint;

  /// The word has been found — the composer goes inert.
  final bool solved;

  final List<String> unknownSuggestions;
  final ValueChanged<String>? onSuggestionTap;

  /// Rejection reason for the last attempt, already localized.
  final String? inputError;

  /// The word played most recently. The only reliable chronology signal the
  /// screen receives, so both the pinned "Latest" row and the row highlight
  /// derive from it rather than from list position.
  final String? lastWord;

  /// Canonical word of the last duplicate rejection and its monotonically
  /// increasing sequence — used purely to pulse the already-played row.
  final String? duplicateWord;
  final int duplicateSeq;

  final VoidCallback? onBack;

  @override
  State<SiyagGameView> createState() => _SiyagGameViewState();
}

class _SiyagGameViewState extends State<SiyagGameView> {
  bool _hintsExpanded = false;
  bool _keyboardWasUp = false;
  final _focus = FocusNode();

  @override
  void dispose() {
    _focus.dispose();
    super.dispose();
  }

  /// The hint panel yields to the keyboard by **closing**, not by being
  /// overridden at paint time.
  ///
  /// It used to render as `_hintsExpanded && !keyboardUp`, which made the header
  /// inert while typing: on device the tap did nothing visible and the panel
  /// then sprang open later, whenever the keyboard happened to close. Worse, the
  /// obvious fix — unfocus and let the insets drop — silently depends on the
  /// platform actually retracting the keyboard.
  ///
  /// So the yield happens here instead, on the transition into typing. After
  /// that, `_hintsExpanded` is the single source of truth and an explicit tap
  /// always wins.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final up = MediaQuery.viewInsetsOf(context).bottom > 0;
    if (up && !_keyboardWasUp && _hintsExpanded) _hintsExpanded = false;
    _keyboardWasUp = up;
  }

  /// Content script follows the game language, not the app locale.
  SiyaqScript get _script =>
      widget.gameLanguage.isArabic ? SiyaqScript.arabic : SiyaqScript.latin;

  /// Open/close the hint panel. Opening also drops the keyboard, so the panel
  /// has somewhere to go — but the panel opens either way.
  void _toggleHints({required bool keyboardUp}) {
    final opening = !_hintsExpanded;
    if (opening && keyboardUp) _focus.unfocus();
    setState(() => _hintsExpanded = opening);
  }

  /// The guess the player played most recently — identified by [lastWord],
  /// never by list position.
  ///
  /// The server returns `previous_guesses` ordered by *rank*, not by when each
  /// word was played, so `guesses.last` is the **worst-ranked** guess rather
  /// than the newest. Reading position as chronology is what made the pinned
  /// "Latest" row show the wrong word on device: played sun → moon → star, row
  /// showed "moon". The timeline rows already key off [lastWord]; this brings
  /// the pinned row in line with them.
  ///
  /// Falls back to the last element only when there is no [lastWord] to match
  /// (a resumed session, where nothing in the payload records what came last).
  SiyaqGuessData? _resolveLatest(List<SiyaqGuessData> guesses) {
    final word = widget.lastWord;
    if (word != null) {
      for (final g in guesses) {
        if (g.word == word) return g;
      }
    }
    return guesses.isNotEmpty ? guesses.last : null;
  }

  String? _band(SiyaqGuessData g) {
    final band = g.band;
    return band == null ? null : widget.loc(band.labelKey);
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final c = context.colors;
    final g = widget.guesses;

    // Hints close themselves when typing starts (see didChangeDependencies);
    // from here on the player's choice is simply honoured.
    final keyboardUp = MediaQuery.viewInsetsOf(context).bottom > 0;
    final hintsOpen = _hintsExpanded;

    SiyaqGuessData? best;
    for (final x in g) {
      if (best == null || (x.heat ?? 0) > (best.heat ?? 0)) best = x;
    }

    final latest = _resolveLatest(g);

    // Only worth its own row when it is not already the best — otherwise the
    // player would read the same word twice and learn nothing.
    final showLatest =
        latest != null && best != null && latest.word != best.word;

    // Ordered worst → best so that, in the reversed viewport, the *best* guess
    // climbs to the top and the weakest sits by the composer. Sorted here
    // rather than trusting the response order, which is a server detail this
    // screen should not depend on. See `guessesRanked` in the docs: this list
    // is a ranking, not a chronology — chronological history needs per-guess
    // timestamps the API does not send.
    final timeline = [...g]
      ..sort((a, b) => (a.heat ?? 0).compareTo(b.heat ?? 0));

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          // The keyboard shrinks this box (resizeToAvoidBottomInset), and on a
          // short screen the fixed rows alone can outgrow it. Rather than
          // overflow, the screen sheds chrome in a fixed order of priority:
          // hint panel first, then Latest. Best Guess and the composer are
          // never sacrificed — the brief requires both to stay reachable.
          // Thresholds scale with the text scaler because every row grows.
          child: LayoutBuilder(
            builder: (context, box) {
              final scale = MediaQuery.textScalerOf(context).scale(1);
              // Deliberately does not vary with `hintsOpen`: raising the bar for
              // an expanded panel just sheds the panel the player only just
              // asked for, which is the inert-control bug again. The expanded
              // content is small and bounded (up to five hint lines and one
              // button) and the timeline above is `Expanded`, so it gives up the
              // space instead.
              final showHints = box.maxHeight > 400 * scale;
              final showLatestRow = showLatest && box.maxHeight > 330 * scale;
              return Column(
                children: [
                  _Header(
                    loc: loc,
                    title: widget.title,
                    gameLanguage: widget.gameLanguage,
                    onBack: widget.onBack,
                  ),
                  if (widget.flash != null)
                    _Flash(message: widget.flash!, key: ValueKey(widget.flash)),
                  if (showHints)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SiyaqSpacing.lg,
                        0,
                        SiyaqSpacing.lg,
                        SiyaqSpacing.sm,
                      ),
                      child: SiyaqHintPanel(
                        expanded: hintsOpen,
                        onToggle: () => _toggleHints(keyboardUp: keyboardUp),
                        title: loc('hints'),
                        remainingLabel: widget.hintsRemaining > 0
                            ? loc.fill('hintsLeftN', {
                                'n': '${widget.hintsRemaining}',
                              })
                            : loc('hintsNone'),
                        toggleSemanticLabel: hintsOpen
                            ? loc('hideHints')
                            : loc('showHints'),
                        hints: widget.hints,
                        rankLabel: loc('rankLabel'),
                        emptyLabel: loc('noHintsYet'),
                        revealLabel: loc('revealHint'),
                        loading: widget.hintLoading,
                        script: _script,
                        onRequestHint:
                            widget.hintsRemaining > 0 && !widget.solved
                            ? widget.onRequestHint
                            : null,
                      ),
                    ),
                  Expanded(
                    child: g.isEmpty
                        ? Center(
                            child: SiyaqEmptyState(
                              title: loc('noGuessesYet'),
                              body: loc('noGuessesBody'),
                              icon: SiyaqIcons.hint,
                            ),
                          )
                        : _Timeline(
                            loc: loc,
                            timeline: timeline,
                            total: g.length,
                            best: best,
                            lastWord: widget.lastWord,
                            duplicateWord: widget.duplicateWord,
                            duplicateSeq: widget.duplicateSeq,
                            script: _script,
                            band: _band,
                          ),
                  ),
                  // Pinned summaries: these are the two facts a player checks before
                  // every guess, so they never scroll away and never move when the
                  // keyboard opens.
                  if (best != null)
                    _PinnedGuess(
                      child: SiyaqGuessHighlight(
                        label: loc('closest'),
                        guess: best,
                        bandLabel: _band(best),
                        distanceLabel: loc('distanceLabel'),
                        script: _script,
                        emphasised: true,
                      ),
                    ),
                  if (showLatestRow)
                    _PinnedGuess(
                      child: SiyaqGuessHighlight(
                        label: loc('latest'),
                        guess: latest,
                        bandLabel: _band(latest),
                        distanceLabel: loc('distanceLabel'),
                        script: _script,
                        accent: c.info,
                      ),
                    ),
                  _Composer(
                    loc: loc,
                    gameLanguage: widget.gameLanguage,
                    script: _script,
                    controller: widget.controller,
                    focus: _focus,
                    submitting: widget.submitting,
                    solved: widget.solved,
                    inputError: widget.inputError,
                    suggestions: widget.unknownSuggestions,
                    onSuggestionTap: widget.onSuggestionTap,
                    onSubmit: widget.onSubmit,
                  ),
                ],
              );
            },
          ),
        ),
      ),
    );
  }
}

/// Horizontal gutter for a pinned summary row, with just enough breathing room
/// above it to read as a separate band from the timeline.
class _PinnedGuess extends StatelessWidget {
  const _PinnedGuess({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      SiyaqSpacing.lg,
      SiyaqSpacing.xs,
      SiyaqSpacing.lg,
      0,
    ),
    child: child,
  );
}

// ── Timeline ──────────────────────────────────────────────────────────────────

/// The bottom-anchored guess history.
///
/// `reverse: true` is doing the real work: the viewport's zero offset is the
/// *bottom*, so a guess prepended at index 0 appears against the composer and
/// nothing already on screen moves. Faking this by sorting a normal list would
/// scroll the player away from their own last guess on every submit.
class _Timeline extends StatelessWidget {
  const _Timeline({
    required this.loc,
    required this.timeline,
    required this.total,
    required this.best,
    required this.lastWord,
    required this.duplicateWord,
    required this.duplicateSeq,
    required this.script,
    required this.band,
  });

  final AppLocalizations loc;
  final List<SiyaqGuessData> timeline;
  final int total;
  final SiyaqGuessData? best;
  final String? lastWord;
  final String? duplicateWord;
  final int duplicateSeq;
  final SiyaqScript script;
  final String? Function(SiyaqGuessData) band;

  @override
  Widget build(BuildContext context) => ListView.builder(
    reverse: true,
    padding: const EdgeInsets.fromLTRB(
      SiyaqSpacing.lg,
      SiyaqSpacing.md,
      SiyaqSpacing.lg,
      SiyaqSpacing.xs,
    ),
    // One extra slot for the list heading, which sits above the oldest guess —
    // the top of the timeline, where a heading belongs.
    itemCount: timeline.length + 1,
    itemBuilder: (context, i) {
      if (i == timeline.length) {
        return Padding(
          padding: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
          child: SiyaqText(
            '${loc('guessHistory').toUpperCase()} · '
            '${loc.fill('guessesCount', {'n': '$total'})}',
            role: SiyaqTextRole.labelSmall,
            script: SiyaqScript.mono,
            color: context.colors.textMuted,
            header: true,
            maxLines: 2,
          ),
        );
      }
      final x = timeline[i];
      return Padding(
        key: ValueKey(x.word),
        padding: const EdgeInsets.only(bottom: SiyaqSpacing.xs),
        child: SiyaqGuessRow(
          guess: x,
          bandLabel: band(x),
          rankLabel: loc('rankLabel'),
          script: script,
          isBest: x.word == best?.word,
          isLatest: x.word == lastWord,
          statusLabel: x.word == best?.word ? loc('closest') : null,
          animateIn: x.word == lastWord,
          pulseTrigger: x.word == duplicateWord ? duplicateSeq : 0,
        ),
      );
    },
  );
}

// ── Header ────────────────────────────────────────────────────────────────────

class _Header extends StatelessWidget {
  const _Header({
    required this.loc,
    required this.title,
    required this.gameLanguage,
    required this.onBack,
  });

  final AppLocalizations loc;
  final String title;
  final GameplayLanguage gameLanguage;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) => SiyaqScreenHeader(
    // Kicker only, no large title: a heading beside the language chip has ~90px
    // at 320px/2.0x and wraps one word to four lines, eating the game screen.
    kicker: title,
    onBack: onBack,
    backLabel: loc('back'),
    padding: const EdgeInsets.fromLTRB(
      SiyaqSpacing.lg,
      SiyaqSpacing.md,
      SiyaqSpacing.lg,
      SiyaqSpacing.sm,
    ),
    // The game language is locked for the session, so it is stated rather than
    // offered: the player picks it before starting, and seeing which vocabulary
    // they are playing removes the "why is this word unknown?" confusion.
    trailing: SiyaqChip(
      label: loc(gameLanguage.labelKey),
      variant: SiyaqChipVariant.neutral,
      icon: SiyaqIcons.language,
      semanticLabel: '${loc('gameLanguage')}: ${loc(gameLanguage.labelKey)}',
    ),
  );
}

class _Flash extends StatelessWidget {
  const _Flash({super.key, required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(
      SiyaqSpacing.lg,
      0,
      SiyaqSpacing.lg,
      SiyaqSpacing.sm,
    ),
    child: SiyaqText(
      message,
      role: SiyaqTextRole.bodySmall,
      color: context.colors.primary,
      align: TextAlign.center,
    ),
  );
}

// ── Composer block ────────────────────────────────────────────────────────────

class _Composer extends StatelessWidget {
  const _Composer({
    required this.loc,
    required this.gameLanguage,
    required this.script,
    required this.controller,
    required this.focus,
    required this.submitting,
    required this.solved,
    required this.inputError,
    required this.suggestions,
    required this.onSuggestionTap,
    required this.onSubmit,
  });

  final AppLocalizations loc;
  final GameplayLanguage gameLanguage;
  final SiyaqScript script;
  final TextEditingController controller;
  final FocusNode focus;
  final bool submitting;
  final bool solved;
  final String? inputError;
  final List<String> suggestions;
  final ValueChanged<String>? onSuggestionTap;
  final ValueChanged<String> onSubmit;

  @override
  Widget build(BuildContext context) => Padding(
    padding: EdgeInsets.fromLTRB(
      SiyaqSpacing.lg,
      SiyaqSpacing.sm,
      SiyaqSpacing.lg,
      // Clears the keyboard when it is up and the home indicator when it is not.
      MediaQuery.viewInsetsOf(context).bottom > 0
          ? SiyaqSpacing.md
          : SiyaqSpacing.xl,
    ),
    child: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        // Thinking in the other language? Offer gameplay-language candidates.
        // Rebuilds with every keystroke via the composer's own controller; the
        // pick only fills the field — submission stays explicit.
        ValueListenableBuilder<TextEditingValue>(
          valueListenable: controller,
          builder: (context, value, _) => TranslationAssist(
            text: value.text,
            gameLanguage: gameLanguage,
            noCandidatesLabel: loc('noTranslations'),
            onPick: (word) {
              controller.text = word;
              controller.selection = TextSelection.collapsed(
                offset: word.length,
              );
            },
          ),
        ),
        if (suggestions.isNotEmpty) ...[
          SiyaqText(
            loc('didYouMean'),
            role: SiyaqTextRole.bodySmall,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: SiyaqSpacing.sm),
          Wrap(
            spacing: SiyaqSpacing.sm,
            runSpacing: SiyaqSpacing.sm,
            children: [
              for (final w in suggestions)
                Directionality(
                  textDirection: gameLanguage.direction,
                  child: SiyaqChip(
                    label: w,
                    variant: SiyaqChipVariant.neutral,
                    onTap: () => onSuggestionTap?.call(w),
                  ),
                ),
            ],
          ),
          const SizedBox(height: SiyaqSpacing.md),
        ],
        SiyaqGuessComposer(
          controller: controller,
          focusNode: focus,
          onSubmit: onSubmit,
          hintText: loc('enterYourWord'),
          submitLabel: loc('submitGuess'),
          fieldSemanticLabel: loc('enterYourWord'),
          direction: gameLanguage.direction,
          script: script,
          submitting: submitting,
          enabled: !solved,
          errorText: inputError,
        ),
      ],
    ),
  );
}
