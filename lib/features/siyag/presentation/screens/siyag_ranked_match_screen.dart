import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/sound/feedback_service.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/ranked.dart';
import '../../../v2/domain/repositories/ranked_repository.dart';
import '../../../v2/presentation/controllers/ranked_controller.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../../v2/presentation/controllers/wallet_controller.dart';

/// Live match snapshot until it ends (contract §8). The authoritative REST
/// snapshot is the reconciliation source of truth; the ranked realtime channel
/// (§11) is a best-effort *nudge* that refetches the instant the match changes.
/// A steady safety poll runs underneath, so a dropped/absent socket degrades to
/// the previous poll-only behaviour with no correctness or liveness loss.
final rankedMatchStreamProvider = StreamProvider.autoDispose
    .family<RankedMatch, String>((ref, matchId) {
      final repo = ref.watch(rankedRepositoryProvider);
      final controller = StreamController<RankedMatch>();
      var over = false;
      var inFlight = false;

      Future<void> refetch() async {
        if (over || inFlight || controller.isClosed) return;
        inFlight = true;
        try {
          final m = await repo.getMatch(matchId);
          if (controller.isClosed) return;
          controller.add(m);
          if (m.isOver) {
            over = true;
            ref.invalidate(walletControllerProvider); // settlement/payout
            await controller.close();
          }
        } catch (_) {
          // Transient — the next nudge or safety-poll tick retries.
        } finally {
          inFlight = false;
        }
      }

      // Realtime nudge: refetch immediately on any ranked-channel frame.
      StreamSubscription<void>? nudgeSub;
      unawaited(() async {
        try {
          final iid = await ref.read(installationIdStoreProvider).getOrCreate();
          if (controller.isClosed) return;
          nudgeSub = ref
              .read(rankedRealtimeNudgeProvider)
              .watch(matchId: matchId, installationId: iid)
              .listen((_) => refetch(), onError: (_) {});
        } catch (_) {
          // No socket → the safety poll below keeps the match live.
        }
      }());

      // Safety net: unchanged 2s cadence so behaviour never regresses when the
      // socket is unavailable; the nudge just makes updates feel instant.
      final timer = Timer.periodic(
        const Duration(seconds: 2),
        (_) => refetch(),
      );

      ref.onDispose(() {
        timer.cancel();
        nudgeSub?.cancel();
        if (!controller.isClosed) controller.close();
      });

      refetch(); // initial snapshot
      return controller.stream;
    });

/// Ranked 1v1: turn-based, coin-staked, both players guessing the same secret.
///
/// Built from the Siyaq gameplay components. Two things make it read differently
/// from solo, and both are properties of the mode rather than of the design:
///
/// * **No closeness signal.** A `MatchGuess` carries a rank and nothing else —
///   no proximity, and the snapshot has no vocabulary size to scale a rank into
///   a heat band. Rows therefore render rank-only (`SiyaqGuessData.heat == null`)
///   instead of inventing a band from a guessed denominator.
/// * **Turn gating.** The composer is disabled unless it is the player's turn,
///   which the turn banner above it states in words.
///
/// Matchmaking, turn logic, settlement and rating are untouched.
class SiyagRankedMatchScreen extends ConsumerWidget {
  const SiyagRankedMatchScreen({required this.matchId, super.key});

  final String matchId;

  Future<void> _act(
    WidgetRef ref,
    Future<RankedMatch> Function(RankedRepository) run,
  ) async {
    try {
      await run(ref.read(rankedRepositoryProvider));
    } catch (_) {}
    ref.invalidate(rankedMatchStreamProvider(matchId)); // immediate refresh
  }

  /// Confirm before forfeiting — a forfeit counts as a loss and forfeits the stake.
  Future<void> _confirmForfeit(BuildContext context, WidgetRef ref) async {
    final loc = ref.read(localizationsProvider);
    final ok = await showSiyaqConfirm(
      context,
      direction: loc.direction,
      title: loc('confirmForfeitTitle'),
      body: loc('confirmForfeitBody'),
      confirmLabel: loc('leave'),
      cancelLabel: loc('back'),
    );
    if (ok) await _act(ref, (r) => r.forfeit(matchId));
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final match = ref.watch(rankedMatchStreamProvider(matchId)).value;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        resizeToAvoidBottomInset: true,
        body: SafeArea(
          bottom: false,
          child: match == null
              ? SiyaqLoader(semanticLabel: loc('loading'))
              : _Match(
                  loc: loc,
                  match: match,
                  onReady: () => _act(ref, (r) => r.ready(matchId)),
                  onGuess: (w) => _act(
                    ref,
                    (r) => r.guess(matchId, w, language: match.language),
                  ),
                  onForfeit: () => _confirmForfeit(context, ref),
                ),
        ),
      ),
    );
  }
}

class _Match extends ConsumerStatefulWidget {
  const _Match({
    required this.loc,
    required this.match,
    required this.onReady,
    required this.onGuess,
    required this.onForfeit,
  });

  final AppLocalizations loc;
  final RankedMatch match;
  final VoidCallback onReady;
  final ValueChanged<String> onGuess;
  final VoidCallback onForfeit;

  @override
  ConsumerState<_Match> createState() => _MatchState();
}

class _MatchState extends ConsumerState<_Match> {
  final _input = TextEditingController();

  /// Turn number the countdown cue already fired for — once per turn.
  int? _cuedTurn;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  @override
  void didUpdateWidget(_Match old) {
    super.didUpdateWidget(old);
    final feedback = ref.read(feedbackServiceProvider);
    final m = widget.match;

    // Match just ended → one celebration, decided by who won.
    if (m.isOver && !old.match.isOver) {
      feedback.play(
        m.didIWin ? SiyaqSoundEvent.victory : SiyaqSoundEvent.defeat,
      );
    }

    // Turn clock running low on MY turn → a single pip per turn.
    final remaining = m.turnRemainingSeconds;
    if (m.isActive &&
        m.isMyTurn &&
        remaining != null &&
        remaining <= 10 &&
        _cuedTurn != m.turnNumber) {
      _cuedTurn = m.turnNumber;
      feedback.play(SiyaqSoundEvent.countdown);
    }
  }

  void _submit(String word) {
    widget.onGuess(word);
    _input.clear();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    final c = context.colors;
    final m = widget.match;
    final language = GameplayLanguage.fromCode(m.language);
    final script = language.isArabic ? SiyaqScript.arabic : SiyaqScript.latin;

    // Closest-first, matching every other mode: the ranking is the point, and
    // recency is already answered by the Latest highlight. An unranked guess
    // (the server has not scored it yet) is excluded — it has no place in a
    // ranked list and can never be the best.
    final ranked = [
      for (final g in m.guesses)
        if (g.rank != null) g,
    ]..sort((a, b) => a.rank!.compareTo(b.rank!));
    MatchGuess? best;
    for (final g in ranked) {
      if (best == null || g.rank! < best.rank!) best = g;
    }
    final latest = m.guesses.isNotEmpty ? m.guesses.last : null;
    final showLatest =
        latest != null && best != null && latest.word != best.word;

    SiyaqGuessData data(MatchGuess g) => SiyaqGuessData(
      word: g.word,
      rank: g.rank ?? 0,
      // Deliberately null — see the class doc.
      solved: g.rank == 1,
    );

    SiyaqGuessAttribution author(MatchGuess g) => SiyaqGuessAttribution(
      label: g.isYou ? loc('you') : loc('opponentLabel'),
      icon: g.isYou ? SiyaqIcons.profile : SiyaqIcons.opponent,
      color: g.isYou ? c.primary : c.textMuted,
    );

    return Column(
      children: [
        SiyaqScreenHeader(
          kicker: loc('competitive'),
          accent: c.primary,
          onBack: () => Navigator.of(context).maybePop(),
          backLabel: loc('back'),
          padding: const EdgeInsets.fromLTRB(
            SiyaqSpacing.lg,
            SiyaqSpacing.md,
            SiyaqSpacing.lg,
            SiyaqSpacing.sm,
          ),
          trailing: SiyaqChip(
            label: loc(language.labelKey),
            icon: SiyaqIcons.language,
            semanticLabel: '${loc('gameLanguage')}: ${loc(language.labelKey)}',
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
              _Players(loc: loc, match: m),
              const SizedBox(height: SiyaqSpacing.md),
              if (m.isOver)
                _Result(loc: loc, match: m, script: script)
              else if (m.isPreparing)
                _Preparing(loc: loc, match: m, onReady: widget.onReady)
              else ...[
                _TurnBanner(loc: loc, match: m),
                if (best != null) ...[
                  const SizedBox(height: SiyaqSpacing.md),
                  SiyaqGuessHighlight(
                    label: loc('closest'),
                    guess: data(best),
                    distanceLabel: loc('distanceLabel'),
                    script: script,
                    accent: c.primary,
                    emphasised: true,
                  ),
                ],
                if (showLatest) ...[
                  const SizedBox(height: SiyaqSpacing.sm),
                  SiyaqGuessHighlight(
                    label: loc('latest'),
                    guess: data(latest),
                    distanceLabel: loc('distanceLabel'),
                    script: script,
                    accent: c.info,
                  ),
                ],
                const SizedBox(height: SiyaqSpacing.lg),
                if (m.guesses.isEmpty)
                  SiyaqEmptyState(
                    title: loc('noGuessesYet'),
                    body: loc('noGuessesBody'),
                    icon: SiyaqIcons.hint,
                  )
                else ...[
                  SiyaqText(
                    '${loc('sharedHistory').toUpperCase()} · '
                    '${loc.fill('guessesCount', {'n': '${m.guesses.length}'})}',
                    role: SiyaqTextRole.labelSmall,
                    script: SiyaqScript.mono,
                    color: c.textMuted,
                    header: true,
                    maxLines: 2,
                  ),
                  const SizedBox(height: SiyaqSpacing.sm),
                  for (final g in ranked)
                    Padding(
                      key: ValueKey('${g.word}-${g.turnNumber}'),
                      padding: const EdgeInsets.only(bottom: SiyaqSpacing.xs),
                      child: SiyaqGuessRow(
                        guess: data(g),
                        rankLabel: loc('rankLabel'),
                        script: script,
                        isBest: g.word == best?.word,
                        isLatest: g.word == latest?.word,
                        attribution: author(g),
                        statusLabel: g.word == best?.word
                            ? loc('closest')
                            : null,
                      ),
                    ),
                ],
                const SizedBox(height: SiyaqSpacing.lg),
                SiyaqButton(
                  label: loc('leave'),
                  icon: SiyaqIcons.forfeit,
                  type: SiyaqButtonType.ghost,
                  onPressed: widget.onForfeit,
                ),
              ],
            ],
          ),
        ),
        if (m.isActive)
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
              // The placeholder itself carries the turn gate, so a disabled
              // composer says why it is disabled.
              hintText: m.isMyTurn ? loc('guessAWord') : loc('waitYourTurn'),
              submitLabel: loc('submitGuess'),
              fieldSemanticLabel: loc('guessAWord'),
              direction: language.direction,
              script: script,
              enabled: m.isMyTurn,
              accent: c.primary,
            ),
          ),
      ],
    );
  }
}

// ── Players ───────────────────────────────────────────────────────────────────

/// The two slots, stacked rather than side by side: a pair of narrow columns
/// truncates both display names at large text scales, where full-width rows do
/// not.
class _Players extends StatelessWidget {
  const _Players({required this.loc, required this.match});

  final AppLocalizations loc;
  final RankedMatch match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget row(MatchPlayer? p, {required bool isYou}) {
      final active = isYou ? match.isMyTurn : match.isActive && !match.isMyTurn;
      final ready = p?.ready ?? false;
      return SiyaqPlayerRow(
        name: isYou ? loc('you') : (p?.label ?? loc('opponentLabel')),
        subtitle: ready ? loc('ready') : p?.connectionState,
        isSelf: isYou,
        presence: (p?.connectionState ?? 'connected') == 'connected'
            ? SiyaqPresence.online
            : SiyaqPresence.offline,
        roleLabel: active ? loc('yourTurn') : null,
        roleAccent: c.primary,
        accent: isYou ? c.primary : c.info,
        statusLabel: ready ? loc('ready') : null,
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row(match.you, isYou: true),
        const SizedBox(height: SiyaqSpacing.sm),
        row(match.opponent, isYou: false),
      ],
    );
  }
}

// ── Turn banner ───────────────────────────────────────────────────────────────

class _TurnBanner extends StatelessWidget {
  const _TurnBanner({required this.loc, required this.match});

  final AppLocalizations loc;
  final RankedMatch match;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final mine = match.isMyTurn;
    final seconds = match.turnRemainingSeconds?.round();
    final label = mine
        ? (seconds != null
              ? '${loc('yourTurn')} · $seconds${loc('secShort')}'
              : loc('yourTurn'))
        : loc('opponentTurn');

    return SiyaqSurface(
      variant: mine ? SiyaqSurfaceVariant.accent : SiyaqSurfaceVariant.base,
      accent: c.primary,
      padding: const EdgeInsets.symmetric(
        horizontal: SiyaqSpacing.lg,
        vertical: SiyaqSpacing.smd,
      ),
      child: Center(
        child: SiyaqStatusIndicator(
          label: label,
          tone: mine ? SiyaqTone.accent : SiyaqTone.info,
          pulse: !mine,
        ),
      ),
    );
  }
}

// ── Preparing ─────────────────────────────────────────────────────────────────

class _Preparing extends StatelessWidget {
  const _Preparing({
    required this.loc,
    required this.match,
    required this.onReady,
  });

  final AppLocalizations loc;
  final RankedMatch match;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final ready = match.you?.ready ?? false;
    return SiyaqEmptyState(
      title: loc('getReady'),
      body: ready ? loc('waitingOpponent') : null,
      icon: SiyaqIcons.target,
      actionLabel: ready ? null : loc('imReady'),
      onAction: ready ? null : onReady,
    );
  }
}

// ── Result ────────────────────────────────────────────────────────────────────

class _Result extends StatelessWidget {
  const _Result({required this.loc, required this.match, required this.script});

  final AppLocalizations loc;
  final RankedMatch match;
  final SiyaqScript script;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final won = match.didIWin;
    final delta = match.ratingDelta;

    return Column(
      children: [
        const SizedBox(height: SiyaqSpacing.lg),
        SiyaqIconTile(
          icon: won ? SiyaqIcons.trophy : SiyaqIcons.forfeit,
          size: SiyaqIconTileSize.large,
          accent: won ? c.success : c.textMuted,
        ),
        const SizedBox(height: SiyaqSpacing.md),
        SiyaqText(
          won ? loc('youWon') : loc('matchEnded'),
          role: SiyaqTextRole.headingLarge,
          align: TextAlign.center,
          header: true,
        ),
        if (match.secretWord != null) ...[
          const SizedBox(height: SiyaqSpacing.md),
          SiyaqText(
            loc('theWordLabel'),
            role: SiyaqTextRole.labelSmall,
            color: c.textMuted,
          ),
          SiyaqText(
            match.secretWord!,
            role: SiyaqTextRole.headingMedium,
            // Game content: the secret follows the match language.
            script: script,
            align: TextAlign.center,
          ),
        ],
        if (delta != null) ...[
          const SizedBox(height: SiyaqSpacing.md),
          SiyaqChip(
            label: '${delta >= 0 ? '+' : ''}$delta ${loc('ratingPts')}',
            numeric: true,
            variant: SiyaqChipVariant.accent,
            accent: delta >= 0 ? c.success : c.error,
          ),
        ],
        const SizedBox(height: SiyaqSpacing.xxl),
        SiyaqButton(
          label: loc('back'),
          icon: SiyaqIcons.home,
          fullWidth: true,
          onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }
}
