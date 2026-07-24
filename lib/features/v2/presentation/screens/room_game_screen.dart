import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/domain/entities/guess.dart';
import '../../../game/domain/entities/heat.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/confetti_overlay.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../../../game/presentation/widgets/pressable.dart';
import '../../domain/entities/room.dart';
import '../controllers/realtime_room_controller.dart';
import '../controllers/room_controller.dart';
import '../controllers/v2_providers.dart';
import '../widgets/shared_guess_row.dart';
import '../widgets/v2_guess_input.dart';
import '../widgets/v2_scaffold.dart';

/// Shared multiplayer game — live shared history with per-player attribution,
/// friendly shared-duplicate messaging, and a winner state consistent with the
/// solo victory language. Gameplay language is inherited from the room (locked).
class RoomGameScreen extends ConsumerStatefulWidget {
  const RoomGameScreen({super.key});

  @override
  ConsumerState<RoomGameScreen> createState() => _RoomGameScreenState();
}

class _RoomGameScreenState extends ConsumerState<RoomGameScreen> {
  final _input = TextEditingController();
  bool _submitting = false;

  @override
  void dispose() {
    _input.dispose();
    super.dispose();
  }

  Future<void> _submit(String raw) async {
    final loc = ref.read(localizationsProvider);
    final word = raw.trim();
    final room = ref.read(realtimeRoomControllerProvider).room;
    if (word.isEmpty || room == null || _submitting || room.isSolved) return;
    setState(() => _submitting = true);
    try {
      final outcome = await ref
          .read(roomRepositoryProvider)
          .guess(roomId: room.roomId, word: word);
      final ctrl = ref.read(realtimeRoomControllerProvider.notifier);
      if (outcome.unknown) {
        _snack(loc('unknownWord'));
      } else if (outcome.duplicate) {
        // Shared duplicate → friendly message w/ who reached it first, no row.
        final by = outcome.firstByLabel;
        _snack(
          by != null
              ? loc.fill('sharedDuplicateBy', {'name': by})
              : loc('v2ErrDuplicateRoomGuess'),
        );
      } else {
        final me = room.me;
        final g = Guess(
          word: outcome.canonicalWord ?? word,
          rank: outcome.rank ?? 0,
          proximity: outcome.proximity ?? 0,
          tier: Heat.fromLevel(outcome.heatLevel, outcome.proximity ?? 0),
          isSecret: outcome.solved,
        );
        ctrl.addAcceptedGuess(
          SharedGuess(
            guess: g,
            byParticipantId: me?.participantId ?? 'me',
            byLabel: me?.label ?? loc('you'),
            isMine: true,
          ),
        );
        if (outcome.solved) {
          ctrl.markSolved(winner: me, secret: outcome.secretWord);
        }
        _input.clear();
      }
    } finally {
      if (mounted) setState(() => _submitting = false);
    }
  }

  void _snack(String msg) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(content: Text(msg), duration: const Duration(seconds: 2)),
      );
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final conn = ref.watch(realtimeRoomControllerProvider);
    final room = conn.room;
    final arabic = Directionality.of(context) == TextDirection.rtl;

    if (room == null) {
      return V2Scaffold(
        title: loc('modeMultiplayer'),
        child: const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
      );
    }

    final solved = room.isSolved;

    return V2Scaffold(
      title: room.categoryLabel(arabic),
      trailing: solved
          ? null
          : Pressable(
              onTap: () async {
                try {
                  await ref.read(roomRepositoryProvider).hint(
                      roomId: room.roomId, mode: room.hintMode);
                } catch (e) {
                  _snack(loc.errorMessage(e));
                }
              },
              child: const Icon(Icons.lightbulb_outline,
                  size: 20, color: AppColors.secondary),
            ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Reconnecting banner
                if (conn.status == RoomConnStatus.reconnecting ||
                    conn.status == RoomConnStatus.recovering)
                  Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.secondary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      children: [
                        const SizedBox(
                          width: 14,
                          height: 14,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          loc('reconnecting'),
                          style: AppTypography.labelMd.copyWith(
                            color: AppColors.secondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                // Players strip
                GlassPanel(
                  opacity: 0.1,
                  borderRadius: BorderRadius.circular(8),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      const Icon(
                        Icons.groups,
                        size: 16,
                        color: AppColors.secondary,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        '${room.participants.length} · ${loc('players')}',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurface,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${loc('historyTitle')} ${room.sharedHistory.length}',
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (!solved)
                  V2GuessInput(
                    controller: _input,
                    hint: loc('inputHint'),
                    busy: _submitting,
                    enabled: !solved,
                    onSubmit: _submit,
                  ),
                const SizedBox(height: 12),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.only(bottom: 80),
                    children: [
                      for (final s in room.sortedHistory)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 4),
                          child: SharedGuessRow(
                            key: ValueKey(
                              '${s.byParticipantId}:${s.guess.word}',
                            ),
                            shared: s,
                            animateIn:
                                room.sharedHistory.isNotEmpty &&
                                s.guess.word ==
                                    room.sharedHistory.last.guess.word,
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (solved) _WinnerOverlay(room: room, loc: loc),
        ],
      ),
    );
  }
}

class _WinnerOverlay extends ConsumerWidget {
  const _WinnerOverlay({required this.room, required this.loc});

  final Room room;
  final dynamic loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final winner = room.winner;
    return Stack(
      children: [
        const Positioned.fill(child: ConfettiOverlay()),
        Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: GlassPanel(
              opacity: 0.5,
              blur: 24,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primaryContainer.withValues(alpha: 0.4),
              ),
              padding: const EdgeInsets.all(28),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(
                    Icons.workspace_premium,
                    size: 48,
                    color: AppColors.primary,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    loc('winnerTitle'),
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.primary,
                      letterSpacing: 2,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    winner?.label ?? '—',
                    style: AppTypography.displaySm.copyWith(
                      color: AppColors.primary,
                      shadows: AppTypography.amberTextGlow,
                    ),
                  ),
                  if (room.secretWord != null) ...[
                    const SizedBox(height: 12),
                    Text(
                      '${loc('secretWordIs')} ${room.secretWord}',
                      style: AppTypography.bodyLg.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                  ],
                  const SizedBox(height: 24),
                  GlowButton(
                    label: loc('newRoom'),
                    icon: Icons.refresh,
                    onTap: () async {
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
                  const SizedBox(height: 8),
                  GlassButton(
                    label: loc('returnHome'),
                    icon: Icons.home_outlined,
                    onTap: () =>
                        Navigator.of(context).popUntil((r) => r.isFirst),
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
