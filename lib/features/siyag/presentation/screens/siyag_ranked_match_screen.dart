import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
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

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(rankedMatchStreamProvider(matchId));
    final match = async.value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        appBar: AppBar(
          backgroundColor: SC.bg,
          elevation: 0,
          title: Text('المصنّفة', style: ST.ar(18, weight: FontWeight.w700)),
          centerTitle: true,
        ),
        body: SafeArea(
          child: match == null
              ? Center(child: CircularProgressIndicator(color: SC.gold))
              : ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    _Players(match: match),
                    const SizedBox(height: 16),
                    if (match.isOver)
                      _Result(match: match)
                    else if (match.isPreparing)
                      _Preparing(
                        match: match,
                        onReady: () => _act(ref, (r) => r.ready(matchId)),
                      )
                    else
                      _Active(
                        match: match,
                        onGuess: (w) => _act(
                          ref,
                          (r) =>
                              r.guess(matchId, w, language: match.language),
                        ),
                        onForfeit: () => _act(ref, (r) => r.forfeit(matchId)),
                      ),
                  ],
                ),
        ),
      ),
    );
  }
}

class _Players extends StatelessWidget {
  const _Players({required this.match});
  final RankedMatch match;

  @override
  Widget build(BuildContext context) {
    final you = match.you;
    final opp = match.opponent;
    return Row(
      children: [
        Expanded(child: _Chip(p: you, highlight: match.isMyTurn, isYou: true)),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Text('ضد', style: ST.ar(13, color: SC.textMute)),
        ),
        Expanded(
          child: _Chip(
            p: opp,
            highlight: match.isActive && !match.isMyTurn,
            isYou: false,
          ),
        ),
      ],
    );
  }
}

class _Chip extends StatelessWidget {
  const _Chip({required this.p, required this.highlight, required this.isYou});
  final MatchPlayer? p;
  final bool highlight;
  final bool isYou;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: SC.surface,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: highlight ? SC.gold : SC.line, width: highlight ? 2 : 1),
    ),
    child: Column(
      children: [
        SiyagAvatar(
          letter: (p?.label.isNotEmpty ?? false) ? p!.label.characters.first : '?',
          size: 40,
          active: true,
        ),
        const SizedBox(height: 8),
        Text(isYou ? 'أنت' : (p?.label ?? '—'),
            maxLines: 1, overflow: TextOverflow.ellipsis, style: ST.ar(13, weight: FontWeight.w600)),
        Text(
          (p?.ready ?? false) ? 'جاهز' : (p?.connectionState ?? ''),
          style: ST.ar(10, color: (p?.ready ?? false) ? SC.emerald : SC.textMute),
        ),
      ],
    ),
  );
}

class _Preparing extends StatelessWidget {
  const _Preparing({required this.match, required this.onReady});
  final RankedMatch match;
  final VoidCallback onReady;

  @override
  Widget build(BuildContext context) {
    final ready = match.you?.ready ?? false;
    return Column(
      children: [
        Text('استعدّ لبدء المباراة', style: ST.ar(16, weight: FontWeight.w600)),
        const SizedBox(height: 12),
        SiyagPrimaryButton(
          label: ready ? 'بانتظار الخصم…' : 'أنا جاهز',
          icon: ready ? null : Icons.check_rounded,
          onTap: ready ? null : onReady,
        ),
      ],
    );
  }
}

class _Active extends ConsumerStatefulWidget {
  const _Active({required this.match, required this.onGuess, required this.onForfeit});
  final RankedMatch match;
  final void Function(String) onGuess;
  final VoidCallback onForfeit;

  @override
  ConsumerState<_Active> createState() => _ActiveState();
}

class _ActiveState extends ConsumerState<_Active> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _submit() {
    final w = _c.text.trim();
    if (w.isEmpty) return;
    widget.onGuess(w);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    final m = widget.match;
    final myTurn = m.isMyTurn;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 14),
          decoration: BoxDecoration(
            color: myTurn ? SC.gold.withValues(alpha: 0.14) : SC.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(
            myTurn
                ? 'دورك — الوقت ${m.turnRemainingSeconds?.round() ?? '—'}ث'
                : 'دور الخصم',
            textAlign: TextAlign.center,
            style: ST.ar(14, weight: FontWeight.w600,
                color: myTurn ? SC.gold : SC.textMute),
          ),
        ),
        const SizedBox(height: 14),
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: _c,
                enabled: myTurn,
                textAlign: TextAlign.center,
                style: ST.ar(18),
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  hintText: myTurn ? 'خمّن كلمة' : 'انتظر دورك',
                  filled: true,
                  fillColor: SC.surfaceHi,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            SiyagPrimaryButton(
              label: 'أرسل',
              onTap: myTurn ? _submit : null,
              fullWidth: false,
            ),
          ],
        ),
        const SizedBox(height: 16),
        for (final g in m.guesses.reversed.take(20))
          Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                Expanded(
                  child: Text(g.word,
                      style: ST.ar(15,
                          color: g.isYou ? SC.text : SC.textDim,
                          weight: g.isYou ? FontWeight.w600 : FontWeight.w400)),
                ),
                Text(g.rank != null ? '#${g.rank}' : '—', style: ST.mono(13, color: SC.gold)),
              ],
            ),
          ),
        const SizedBox(height: 8),
        SiyagTap(
          onTap: widget.onForfeit,
          child: Center(
            child: Text('انسحاب', style: ST.ar(12, color: SC.coral)),
          ),
        ),
      ],
    );
  }
}

class _Result extends StatelessWidget {
  const _Result({required this.match});
  final RankedMatch match;

  @override
  Widget build(BuildContext context) {
    final won = match.didIWin;
    return Column(
      children: [
        const SizedBox(height: 12),
        Icon(won ? Icons.emoji_events_rounded : Icons.flag_outlined,
            size: 56, color: won ? SC.gold : SC.textMute),
        const SizedBox(height: 12),
        Text(won ? 'فزت!' : 'انتهت المباراة',
            style: ST.ar(22, weight: FontWeight.w700)),
        if (match.secretWord != null) ...[
          const SizedBox(height: 6),
          Text('الكلمة: ${match.secretWord}', style: ST.ar(14, color: SC.textDim)),
        ],
        if (match.ratingDelta != null) ...[
          const SizedBox(height: 4),
          Text('${match.ratingDelta! >= 0 ? '+' : ''}${match.ratingDelta} تقييم',
              style: ST.mono(14, color: won ? SC.emerald : SC.coral)),
        ],
        const SizedBox(height: 20),
        SiyagPrimaryButton(
          label: 'العودة',
          onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
        ),
      ],
    );
  }
}
