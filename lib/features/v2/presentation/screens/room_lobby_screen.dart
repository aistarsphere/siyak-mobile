import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../../../game/presentation/widgets/pressable.dart';
import '../../domain/entities/room.dart';
import '../controllers/profile_controller.dart';
import '../controllers/realtime_room_controller.dart';
import '../controllers/room_controller.dart';
import '../controllers/v2_providers.dart';
import '../widgets/v2_scaffold.dart';
import 'room_game_screen.dart';

/// Pre-game lobby: join code + copy/share, participant list with host badge and
/// connection state, host start button, leave/cancel. Connects realtime on open.
class RoomLobbyScreen extends ConsumerStatefulWidget {
  const RoomLobbyScreen({super.key});

  @override
  ConsumerState<RoomLobbyScreen> createState() => _RoomLobbyScreenState();
}

class _RoomLobbyScreenState extends ConsumerState<RoomLobbyScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final room = ref.read(roomLifecycleControllerProvider).room;
      final id = ref.read(profileControllerProvider).value?.installationId;
      if (room != null && id != null) {
        ref.read(realtimeRoomControllerProvider.notifier).connect(room, id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final conn = ref.watch(realtimeRoomControllerProvider);
    final room = conn.room ?? ref.watch(roomLifecycleControllerProvider).room;

    // Enter the shared game when it starts.
    ref.listen(realtimeRoomControllerProvider.select((s) => s.room?.state), (
      prev,
      next,
    ) {
      if (next == RoomState.playing && prev != RoomState.playing) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const RoomGameScreen()),
        );
      }
    });

    if (room == null) {
      return V2Scaffold(
        title: loc('modeMultiplayer'),
        child: Center(
          child: Text(
            loc('v2ErrRoomExpired'),
            style: AppTypography.bodySm.copyWith(color: AppColors.error),
          ),
        ),
      );
    }

    return V2Scaffold(
      title: loc('modeMultiplayer'),
      onBack: () async {
        await ref.read(realtimeRoomControllerProvider.notifier).leave();
        await ref.read(roomLifecycleControllerProvider.notifier).leave();
        if (context.mounted) Navigator.of(context).maybePop();
      },
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          _JoinCodeCard(room: room, loc: loc),
          const SizedBox(height: 16),
          _ConnBadge(status: conn.status, loc: loc),
          const SizedBox(height: 12),
          Text(
            '${loc('players')} (${room.participants.length}${room.maxPlayers != null ? '/${room.maxPlayers}' : ''})',
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          for (final p in room.participants) _ParticipantTile(p: p, loc: loc),
          const SizedBox(height: 24),
          if (room.amHost)
            GlowButton(
              label: loc('startRoom'),
              icon: Icons.play_arrow,
              onTap: () async {
                // Host starts the game; the `room.started` realtime event then
                // moves everyone (incl. the host) into the shared game.
                try {
                  await ref
                      .read(roomRepositoryProvider)
                      .start(roomId: room.roomId);
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.errorMessage(e))));
                  }
                }
              },
            )
          else
            Text(
              loc('waitingForHost'),
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          const SizedBox(height: 8),
          GlassButton(
            label: loc('leaveRoom'),
            icon: Icons.logout,
            onTap: () async {
              await ref.read(realtimeRoomControllerProvider.notifier).leave();
              await ref.read(roomLifecycleControllerProvider.notifier).leave();
              if (context.mounted) Navigator.of(context).maybePop();
            },
          ),
        ],
      ),
    );
  }
}

class _JoinCodeCard extends StatelessWidget {
  const _JoinCodeCard({required this.room, required this.loc});
  final Room room;
  final dynamic loc;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Text(
            loc('joinCode'),
            style: AppTypography.labelMd.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            room.joinCode,
            style: AppTypography.displayLg.copyWith(
              color: AppColors.primary,
              letterSpacing: 8,
              shadows: AppTypography.amberTextGlow,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _act(context, Icons.copy, loc('copy'), () {
                Clipboard.setData(ClipboardData(text: room.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc('copied')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }),
              const SizedBox(width: 12),
              _act(context, Icons.share, loc('copy'), () {
                SharePlus.instance.share(
                  ShareParams(text: '${loc('joinCode')}: ${room.joinCode}'),
                );
              }, share: true),
            ],
          ),
        ],
      ),
    );
  }

  Widget _act(
    BuildContext c,
    IconData icon,
    String label,
    VoidCallback onTap, {
    bool share = false,
  }) => Pressable(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHighest.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.outline.withValues(alpha: 0.2)),
      ),
      child: Icon(icon, size: 18, color: AppColors.primary),
    ),
  );
}

class _ConnBadge extends StatelessWidget {
  const _ConnBadge({required this.status, required this.loc});
  final RoomConnStatus status;
  final dynamic loc;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RoomConnStatus.connected => (loc('connected'), AppColors.emerald),
      RoomConnStatus.reconnecting => (loc('reconnecting'), AppColors.secondary),
      RoomConnStatus.recovering => (loc('reconnecting'), AppColors.secondary),
      _ => (loc('connecting2'), AppColors.onSurfaceVariant),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: AppTypography.labelMd.copyWith(color: color)),
      ],
    );
  }
}

class _ParticipantTile extends StatelessWidget {
  const _ParticipantTile({required this.p, required this.loc});
  final RoomParticipant p;
  final dynamic loc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: GlassPanel(
        opacity: p.isMe ? 0.3 : 0.15,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: p.isMe
              ? AppColors.primary.withValues(alpha: 0.4)
              : AppColors.surfaceBright.withValues(alpha: 0.3),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        child: Row(
          children: [
            Icon(
              p.connected ? Icons.circle : Icons.circle_outlined,
              size: 10,
              color: p.connected ? AppColors.emerald : AppColors.outline,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                p.isMe ? '${p.label} (${loc('you')})' : p.label,
                style: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurface,
                  fontWeight: p.isMe ? FontWeight.w600 : FontWeight.w400,
                ),
              ),
            ),
            if (p.isHost)
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  loc('host'),
                  style: AppTypography.labelXs.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
