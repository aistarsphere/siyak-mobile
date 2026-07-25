import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_guess.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/domain/entities/guess.dart';
import '../../../game/domain/entities/heat.dart' as v1heat;
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/room.dart';
import '../../../v2/presentation/controllers/realtime_room_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import 'siyag_topbar.dart';

/// Live shared multiplayer game (missing flow, in-grammar): shared timeline
/// with per-player attribution + system-hint rows, live input, winner overlay,
/// and a reconnecting banner. Wired to the realtime controller.
class SiyagRoomGameScreen extends ConsumerStatefulWidget {
  const SiyagRoomGameScreen({super.key});

  @override
  ConsumerState<SiyagRoomGameScreen> createState() => _S();
}

class _S extends ConsumerState<SiyagRoomGameScreen> {
  final _input = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  double _heat(Guess g) =>
      SiyagHeat.fromRank(g.rank, 22548, solved: g.isSecret);

  Future<void> _submit() async {
    final loc = ref.read(localizationsProvider);
    final word = _input.text.trim();
    final room = ref.read(realtimeRoomControllerProvider).room;
    if (word.isEmpty || room == null || _submitting || room.isSolved) return;
    setState(() => _submitting = true);
    try {
      final res = await ref
          .read(roomRepositoryProvider)
          .guess(roomId: room.roomId, word: word);
      final ctrl = ref.read(realtimeRoomControllerProvider.notifier);
      if (res.unknown) {
        _snack('هذه الكلمة غير موجودة في القاموس');
      } else if (res.duplicate) {
        _snack(
          res.firstByLabel != null
              ? 'خمّنها أولاً: ${res.firstByLabel}'
              : 'خُمّنت هذه الكلمة سابقاً',
        );
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
            byLabel: me?.label ?? 'أنت',
            isMine: true,
          ),
        );
        if (res.solved) ctrl.markSolved(winner: me, secret: res.secretWord);
        _input.clear();
      }
    } catch (e) {
      _snack(loc.errorMessage(e));
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String m) => ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(realtimeRoomControllerProvider);
    final room = conn.room;
    if (room == null) {
      return Scaffold(
        backgroundColor: SC.bg,
        body: Center(child: CircularProgressIndicator(color: SC.coral)),
      );
    }
    final solved = room.isSolved;
    final reconnecting =
        conn.status == RoomConnStatus.reconnecting ||
        conn.status == RoomConnStatus.recovering;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: Stack(
            children: [
              Column(
                children: [
                  SiyagTopBar(
                    title: room.categoryLabel(true),
                    subtitle: '${room.participants.length} PLAYERS',
                    trailing: solved
                        ? null
                        : SiyagTap(
                            onTap: () => ref
                                .read(roomRepositoryProvider)
                                .hint(roomId: room.roomId, mode: room.hintMode),
                            child: Icon(
                              Icons.lightbulb_outline_rounded,
                              size: 20,
                              color: SC.cyan,
                            ),
                          ),
                  ),
                  if (reconnecting)
                    Container(
                      margin: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: SC.coral.withValues(alpha: 0.13),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        children: [
                          SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: SC.coral,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'إعادة الاتصال...',
                            style: ST.ar(13, color: SC.coral),
                          ),
                        ],
                      ),
                    ),
                  if (!solved)
                    Padding(
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 12),
                      child: Container(
                        decoration: BoxDecoration(
                          color: SC.surface,
                          borderRadius: BorderRadius.circular(22),
                          border: Border.all(color: SC.lineStrong),
                        ),
                        padding: const EdgeInsetsDirectional.only(
                          start: 16,
                          end: 8,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: TextField(
                                controller: _input,
                                textDirection: TextDirection.rtl,
                                onSubmitted: (_) => _submit(),
                                style: ST.ar(20),
                                decoration: InputDecoration(
                                  hintText: 'اكتب كلمتك...',
                                  hintStyle: ST.ar(20, color: SC.textFaint),
                                  border: InputBorder.none,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 16,
                                  ),
                                ),
                              ),
                            ),
                            SiyagTap(
                              onTap: _submitting ? null : _submit,
                              scale: 0.88,
                              child: Container(
                                width: 48,
                                height: 48,
                                alignment: Alignment.center,
                                decoration: BoxDecoration(
                                  color: SC.emerald,
                                  borderRadius: BorderRadius.circular(16),
                                ),
                                child: AnimatedSwitcher(
                                  duration: const Duration(milliseconds: 200),
                                  child: _submitting
                                      ? SizedBox(
                                          width: 18,
                                          height: 18,
                                          key: const ValueKey('loader'),
                                          child: CircularProgressIndicator(
                                            strokeWidth: 2.2,
                                            color: SC.onColor(SC.emerald),
                                          ),
                                        )
                                      : Icon(
                                          Icons.send_rounded,
                                          key: const ValueKey('icon'),
                                          size: 18,
                                          color: SC.onColor(SC.emerald),
                                        ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  Expanded(
                    child: ListView(
                      padding: const EdgeInsets.fromLTRB(8, 4, 8, 24),
                      children: [
                        for (final s in room.sortedHistory)
                          _SharedRow(shared: s, heat: _heat(s.guess)),
                      ],
                    ),
                  ),
                ],
              ),
              if (solved) _Winner(room: room),
            ],
          ),
        ),
      ),
    );
  }
}

class _SharedRow extends StatelessWidget {
  const _SharedRow({required this.shared, required this.heat});
  final SharedGuess shared;
  final double heat;

  @override
  Widget build(BuildContext context) {
    final edge = shared.isSystemHint
        ? SC.cyan
        : shared.isMine
        ? SC.coral
        : SC.textDim;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 3),
      child: Row(
        children: [
          Container(width: 3, height: 40, color: edge),
          const SizedBox(width: 10),
          Expanded(
            child: SiyagGuessRow(
              word: shared.guess.word,
              rank: shared.guess.rank,
              heat: heat,
              solved: shared.guess.isSecret,
            ),
          ),
          SizedBox(
            width: 56,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Icon(
                  shared.isSystemHint
                      ? Icons.lightbulb_rounded
                      : (shared.isMine
                            ? Icons.person_rounded
                            : Icons.group_rounded),
                  size: 11,
                  color: edge,
                ),
                const SizedBox(height: 2),
                Text(
                  shared.isSystemHint ? '—' : shared.byLabel,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: ST.mono(9, color: edge),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Winner extends ConsumerWidget {
  const _Winner({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Container(
      color: SC.scrim,
      alignment: Alignment.center,
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 72,
              height: 72,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SC.emerald,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Icon(
                Icons.emoji_events_rounded,
                size: 34,
                color: SC.onColor(SC.emerald),
              ),
            ),
            const SizedBox(height: 16),
            Kicker('Winner', color: SC.emerald),
            const SizedBox(height: 6),
            Text(
              room.winner?.label ?? '—',
              style: ST.ar(28, weight: FontWeight.w700),
            ),
            if (room.secretWord != null) ...[
              const SizedBox(height: 12),
              Text(
                'الكلمة: ${room.secretWord}',
                style: ST.ar(16, color: SC.textDim),
              ),
            ],
            const SizedBox(height: 24),
            SiyagPrimaryButton(
              label: 'العودة للرئيسية',
              color: SC.emerald,
              onTap: () async {
                await ref.read(realtimeRoomControllerProvider.notifier).leave();
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
    );
  }
}
