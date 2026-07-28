import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/sound/feedback_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/domain/entities/guess.dart';
import '../../../game/domain/entities/heat.dart' as v1heat;
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/room.dart';
import '../../../v2/presentation/controllers/realtime_room_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';

/// Live shared multiplayer game: one timeline every player contributes to, with
/// per-author attribution and system-revealed hints, plus a winner overlay and a
/// reconnecting banner.
///
/// Built from the Siyaq gameplay components, so a room guess reads exactly like a
/// solo guess — same rank gutter, same closeness signals, same composer. What is
/// specific to a room is the *attribution*: a shared history needs to say who
/// played each word, which solo and weekly never do.
///
/// Realtime wiring, the guess/hint calls and room lifecycle are unchanged.
class SiyagRoomGameScreen extends ConsumerStatefulWidget {
  const SiyagRoomGameScreen({super.key});

  @override
  ConsumerState<SiyagRoomGameScreen> createState() => _S();
}

class _S extends ConsumerState<SiyagRoomGameScreen> {
  final _input = TextEditingController();
  bool _submitting = false;
  bool _hintsExpanded = false;
  String? _inputError;
  String? _lastWord;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  /// Client-side heat from the server rank and the room's own vocabulary size.
  ///
  /// The vocabulary size used to be hardcoded to 22548 here, which silently
  /// mis-scaled every room whose category was smaller; `room.totalWords` is the
  /// value the snapshot already carries.
  double _heat(Guess g, int totalWords) =>
      SiyaqHeat.fromRank(g.rank, totalWords, solved: g.isSecret);

  Future<void> _submit(String word) async {
    final loc = ref.read(localizationsProvider);
    final room = ref.read(realtimeRoomControllerProvider).room;
    if (word.isEmpty || room == null || _submitting || room.isSolved) return;
    setState(() {
      _submitting = true;
      _inputError = null;
    });
    try {
      final res = await ref
          .read(roomRepositoryProvider)
          .guess(roomId: room.roomId, word: word);
      final ctrl = ref.read(realtimeRoomControllerProvider.notifier);
      final feedback = ref.read(feedbackServiceProvider);
      if (res.unknown) {
        feedback.invalidWord();
        if (mounted) {
          setState(() => _inputError = loc('v2ErrNotInVocabulary'));
        }
      } else if (res.duplicate) {
        feedback.guessResult(solved: false, duplicate: true);
        if (mounted) {
          setState(
            () => _inputError = res.firstByLabel != null
                ? loc.fill('sharedDuplicateBy', {'name': res.firstByLabel!})
                : loc('v2ErrDuplicateRoomGuess'),
          );
        }
      } else {
        final me = room.me;
        final g = Guess(
          word: res.canonicalWord ?? word,
          rank: res.rank ?? 0,
          proximity: res.proximity ?? 0,
          tier: v1heat.Heat.fromLevel(res.heatLevel, res.proximity ?? 0),
          isSecret: res.solved,
        );
        ctrl.addAcceptedGuess(
          SharedGuess(
            guess: g,
            byParticipantId: me?.participantId ?? 'me',
            byLabel: me?.label ?? loc('you'),
            isMine: true,
          ),
        );
        feedback.guessResult(solved: res.solved, proximity: res.proximity);
        if (res.solved) ctrl.markSolved(winner: me, secret: res.secretWord);
        _input.clear();
        if (mounted) setState(() => _lastWord = g.word);
      }
    } catch (e) {
      if (mounted) setState(() => _inputError = loc.errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  Future<void> _requestHint(Room room) async {
    final loc = ref.read(localizationsProvider);
    try {
      await ref
          .read(roomRepositoryProvider)
          .hint(roomId: room.roomId, mode: room.hintMode);
      ref.read(feedbackServiceProvider).hintRevealed();
    } catch (e) {
      if (mounted) setState(() => _inputError = loc.errorMessage(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final conn = ref.watch(realtimeRoomControllerProvider);
    final room = conn.room;

    // Solved by another player, arriving over the socket: the defeat cue.
    // (Solving it yourself plays victory from _submit before this fires —
    // the sound service's celebration tier keeps them from overlapping.)
    ref.listen(realtimeRoomControllerProvider.select((s) => s.room?.isSolved), (
      prev,
      next,
    ) {
      if (next == true && prev != true) {
        final r = ref.read(realtimeRoomControllerProvider).room;
        final mine = r?.winner?.isMe ?? false;
        if (!mine) {
          ref.read(feedbackServiceProvider).play(SiyaqSoundEvent.defeat);
        }
      }
    });

    if (room == null) {
      return Scaffold(
        backgroundColor: c.background,
        body: SafeArea(child: SiyaqLoader(semanticLabel: loc('loading'))),
      );
    }

    final solved = room.isSolved;
    final reconnecting =
        conn.status == RoomConnStatus.reconnecting ||
        conn.status == RoomConnStatus.recovering;
    final script = room.language.isArabic
        ? SiyaqScript.arabic
        : SiyaqScript.latin;

    // A system-revealed hint is a history row on the wire. Lifting those into the
    // hint panel keeps the timeline to actual player guesses and gives the hints
    // a place that can be collapsed away.
    final hintRows = [
      for (final s in room.sharedHistory)
        if (s.isSystemHint) s,
    ];
    final playerRows = [
      for (final s in room.sortedHistory)
        if (!s.isSystemHint) s,
    ];

    SiyaqGuessData data(SharedGuess s) => SiyaqGuessData(
      word: s.guess.word,
      rank: s.guess.rank,
      heat: _heat(s.guess, room.totalWords),
      solved: s.guess.isSecret,
    );

    SharedGuess? best;
    for (final s in playerRows) {
      if (best == null || s.guess.rank < best.guess.rank) best = s;
    }
    final latest = _latest(room);
    final showLatest =
        latest != null && best != null && latest.guess.word != best.guess.word;

    String band(SiyaqGuessData g) => loc(g.band!.labelKey);

    SiyaqGuessAttribution attribution(SharedGuess s) => SiyaqGuessAttribution(
      label: s.isSystemHint ? loc('hintAuthor') : s.byLabel,
      icon: s.isSystemHint
          ? SiyaqIcons.hint
          : s.isMine
          ? SiyaqIcons.profile
          : SiyaqIcons.players,
      color: s.isSystemHint
          ? c.info
          : s.isMine
          ? c.primary
          : c.textMuted,
    );

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  SiyaqScreenHeader(
                    kicker: room.categoryLabel(
                      loc.direction == TextDirection.rtl,
                    ),
                    onBack: () => Navigator.of(context).maybePop(),
                    backLabel: loc('back'),
                    accent: c.success,
                    padding: const EdgeInsets.fromLTRB(
                      SiyaqSpacing.lg,
                      SiyaqSpacing.md,
                      SiyaqSpacing.lg,
                      SiyaqSpacing.sm,
                    ),
                    trailing: SiyaqChip(
                      label: loc(room.language.labelKey),
                      icon: SiyaqIcons.language,
                      semanticLabel:
                          '${loc('gameLanguage')}: ${loc(room.language.labelKey)}',
                    ),
                  ),
                  if (reconnecting)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(
                        SiyaqSpacing.lg,
                        0,
                        SiyaqSpacing.lg,
                        SiyaqSpacing.sm,
                      ),
                      child: SiyaqStatusIndicator(
                        label: loc('reconnecting'),
                        tone: SiyaqTone.warning,
                        pulse: true,
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(
                        SiyaqSpacing.lg,
                        0,
                        SiyaqSpacing.lg,
                        SiyaqSpacing.md,
                      ),
                      children: [
                        SiyaqHintPanel(
                          expanded: _hintsExpanded,
                          onToggle: () =>
                              setState(() => _hintsExpanded = !_hintsExpanded),
                          title: loc('hints'),
                          // The room snapshot carries no remaining-hint budget,
                          // so the panel states what has been revealed instead
                          // of inventing a count.
                          remainingLabel: loc.fill('hintsRevealedN', {
                            'n': '${hintRows.length}',
                          }),
                          toggleSemanticLabel: _hintsExpanded
                              ? loc('hideHints')
                              : loc('showHints'),
                          hints: [
                            for (final h in hintRows)
                              SiyaqHintData(
                                word: h.guess.word,
                                rank: h.guess.rank,
                              ),
                          ],
                          rankLabel: loc('rankLabel'),
                          emptyLabel: loc('noHintsYet'),
                          revealLabel: loc('revealHint'),
                          script: script,
                          accent: c.info,
                          onRequestHint: solved
                              ? null
                              : () => _requestHint(room),
                        ),
                        if (best != null) ...[
                          const SizedBox(height: SiyaqSpacing.md),
                          SiyaqGuessHighlight(
                            label: loc('closest'),
                            guess: data(best),
                            bandLabel: band(data(best)),
                            distanceLabel: loc('distanceLabel'),
                            script: script,
                            emphasised: true,
                          ),
                        ],
                        if (showLatest) ...[
                          const SizedBox(height: SiyaqSpacing.sm),
                          SiyaqGuessHighlight(
                            label: loc('latest'),
                            guess: data(latest),
                            bandLabel: band(data(latest)),
                            distanceLabel: loc('distanceLabel'),
                            script: script,
                            accent: c.info,
                          ),
                        ],
                        const SizedBox(height: SiyaqSpacing.lg),
                        if (playerRows.isEmpty)
                          SiyaqEmptyState(
                            title: loc('noGuessesYet'),
                            body: loc('noGuessesBody'),
                            icon: SiyaqIcons.hint,
                          )
                        else ...[
                          SiyaqText(
                            '${loc('sharedHistory').toUpperCase()} · '
                            '${loc.fill('guessesCount', {'n': '${playerRows.length}'})}',
                            role: SiyaqTextRole.labelSmall,
                            script: SiyaqScript.mono,
                            color: c.textMuted,
                            header: true,
                            maxLines: 2,
                          ),
                          const SizedBox(height: SiyaqSpacing.sm),
                          for (final s in playerRows)
                            Padding(
                              key: ValueKey(s.guess.word),
                              padding: const EdgeInsets.only(
                                bottom: SiyaqSpacing.xs,
                              ),
                              child: SiyaqGuessRow(
                                guess: data(s),
                                bandLabel: band(data(s)),
                                rankLabel: loc('rankLabel'),
                                script: script,
                                isBest: s.guess.word == best?.guess.word,
                                isLatest: s.guess.word == _lastWord,
                                attribution: attribution(s),
                                statusLabel: s.guess.word == best?.guess.word
                                    ? loc('closest')
                                    : null,
                                animateIn: s.guess.word == _lastWord,
                              ),
                            ),
                        ],
                      ],
                    ),
                  ),
                  Padding(
                    padding: EdgeInsets.fromLTRB(
                      SiyaqSpacing.lg,
                      SiyaqSpacing.sm,
                      SiyaqSpacing.lg,
                      MediaQuery.viewInsetsOf(context).bottom > 0
                          ? SiyaqSpacing.md
                          : SiyaqSpacing.xl,
                    ),
                    child: SiyaqGuessComposer(
                      controller: _input,
                      onSubmit: _submit,
                      hintText: loc('enterYourWord'),
                      submitLabel: loc('submitGuess'),
                      fieldSemanticLabel: loc('enterYourWord'),
                      direction: room.language.direction,
                      script: script,
                      submitting: _submitting,
                      enabled: !solved,
                      errorText: _inputError,
                      accent: c.success,
                    ),
                  ),
                ],
              ),
              if (solved) _Winner(room: room, loc: loc),
            ],
          ),
        ),
      ),
    );
  }

  /// Newest entry in the shared timeline. `sharedHistory` is arrival-ordered;
  /// `sortedHistory` is rank-ordered, so the last *arrival* has to come from the
  /// unsorted list.
  SharedGuess? _latest(Room room) {
    for (final s in room.sharedHistory.reversed) {
      if (!s.isSystemHint) return s;
    }
    return null;
  }
}

/// Full-bleed victory overlay. Kept as an overlay rather than a route so the
/// timeline stays visible behind it.
class _Winner extends ConsumerWidget {
  const _Winner({required this.room, required this.loc});

  final Room room;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    return ColoredBox(
      color: c.scrim,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(SiyaqSpacing.xxl),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                SiyaqIconTile(
                  icon: SiyaqIcons.trophy,
                  size: SiyaqIconTileSize.large,
                  accent: c.success,
                ),
                const SizedBox(height: SiyaqSpacing.lg),
                SiyaqText(
                  loc('winner').toUpperCase(),
                  role: SiyaqTextRole.labelSmall,
                  script: SiyaqScript.mono,
                  color: c.success,
                ),
                const SizedBox(height: SiyaqSpacing.xs),
                SiyaqText(
                  room.winner?.label ?? loc('noRankYet'),
                  role: SiyaqTextRole.displaySmall,
                  align: TextAlign.center,
                ),
                if (room.secretWord != null) ...[
                  const SizedBox(height: SiyaqSpacing.md),
                  SiyaqText(
                    loc('theWordLabel'),
                    role: SiyaqTextRole.labelSmall,
                    color: c.textMuted,
                  ),
                  SiyaqText(
                    room.secretWord!,
                    role: SiyaqTextRole.headingMedium,
                    // The secret is game content, so it follows the game
                    // language rather than the app locale.
                    script: room.language.isArabic
                        ? SiyaqScript.arabic
                        : SiyaqScript.latin,
                    align: TextAlign.center,
                  ),
                ],
                const SizedBox(height: SiyaqSpacing.xxl),
                SiyaqButton(
                  label: loc('returnHome'),
                  icon: SiyaqIcons.home,
                  accent: c.success,
                  onPressed: () async {
                    await ref
                        .read(realtimeRoomControllerProvider.notifier)
                        .leave();
                    await ref
                        .read(roomLifecycleControllerProvider.notifier)
                        .leave();
                    if (context.mounted) {
                      Navigator.of(context).popUntil((r) => r.isFirst);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
