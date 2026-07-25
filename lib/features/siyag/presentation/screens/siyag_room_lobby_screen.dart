import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/room.dart';
import '../../../v2/domain/entities/social.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';
import '../../../v2/presentation/controllers/realtime_room_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/social_controller.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import '../siyag_route.dart';
import 'siyag_room_game_screen.dart';
import 'siyag_topbar.dart';

/// Multiplayer lobby (missing flow, in-grammar): join code + copy/share,
/// participants with host badge + connection state, host start, leave.
/// Connects the realtime socket on open; enters the live game on `room.started`.
class SiyagRoomLobbyScreen extends ConsumerStatefulWidget {
  const SiyagRoomLobbyScreen({super.key});

  @override
  ConsumerState<SiyagRoomLobbyScreen> createState() => _S();
}

class _S extends ConsumerState<SiyagRoomLobbyScreen> {
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

  void _showInviteSheet(String roomId) => showModalBottomSheet<void>(
    context: context,
    backgroundColor: SC.bg,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _InvitePlayersSheet(roomId: roomId),
  );

  @override
  Widget build(BuildContext context) {
    final conn = ref.watch(realtimeRoomControllerProvider);
    final room = conn.room ?? ref.watch(roomLifecycleControllerProvider).room;

    ref.listen(realtimeRoomControllerProvider.select((s) => s.room?.state), (
      prev,
      next,
    ) {
      if (next == RoomState.playing && prev != RoomState.playing) {
        Navigator.of(
          context,
        ).pushReplacement(siyagRoute(const SiyagRoomGameScreen()));
      }
    });

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: room == null
                ? Center(child: CircularProgressIndicator(color: SC.coral))
                : Column(
                    children: [
                      SiyagTopBar(
                        kicker: 'Lobby',
                        kickerColor: SC.emerald,
                        onBack: () async {
                          await ref
                              .read(realtimeRoomControllerProvider.notifier)
                              .leave();
                          await ref
                              .read(roomLifecycleControllerProvider.notifier)
                              .leave();
                          if (context.mounted) Navigator.of(context).maybePop();
                        },
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            _CodeCard(room: room),
                            const SizedBox(height: 16),
                            _ConnBadge(status: conn.status),
                            const SizedBox(height: 12),
                            Text(
                              'اللاعبون (${room.participants.length}${room.maxPlayers != null ? '/${room.maxPlayers}' : ''})',
                              style: ST.mono(11, color: SC.textMute),
                            ),
                            const SizedBox(height: 8),
                            for (final p in room.participants)
                              _Participant(p: p),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          children: [
                            if (room.amHost) ...[
                              SiyagPrimaryButton(
                                label: 'ابدأ اللعبة',
                                color: SC.emerald,
                                icon: Icons.play_arrow_rounded,
                                onTap: () async {
                                  try {
                                    await ref
                                        .read(roomRepositoryProvider)
                                        .start(roomId: room.roomId);
                                  } catch (e) {
                                    if (context.mounted) {
                                      ScaffoldMessenger.of(
                                        context,
                                      ).showSnackBar(
                                        SnackBar(
                                          content: Text(
                                            ref
                                                .read(localizationsProvider)
                                                .errorMessage(e),
                                          ),
                                        ),
                                      );
                                    }
                                  }
                                },
                              ),
                              const SizedBox(height: 10),
                              SiyagGhostButton(
                                label: 'دعوة لاعبين',
                                icon: Icons.person_add_alt_1_rounded,
                                onTap: () => _showInviteSheet(room.roomId),
                              ),
                            ] else
                              Text(
                                'بانتظار المضيف لبدء اللعبة',
                                style: ST.ar(14, color: SC.textMute),
                              ),
                            const SizedBox(height: 10),
                            SiyagGhostButton(
                              label: 'مغادرة الغرفة',
                              icon: Icons.logout_rounded,
                              onTap: () async {
                                await ref
                                    .read(
                                      realtimeRoomControllerProvider.notifier,
                                    )
                                    .leave();
                                await ref
                                    .read(
                                      roomLifecycleControllerProvider.notifier,
                                    )
                                    .leave();
                                if (context.mounted) {
                                  Navigator.of(context).maybePop();
                                }
                              },
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
          ),
        ),
      ),
    );
  }
}

class _CodeCard extends StatelessWidget {
  const _CodeCard({required this.room});
  final Room room;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: SC.emerald.withValues(alpha: 0.27)),
      ),
      child: Column(
        children: [
          Kicker('Join Code', color: SC.emerald),
          const SizedBox(height: 8),
          Text(room.joinCode, style: ST.mono(34, letterSpacing: 8)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _act(context, Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: room.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('تم النسخ'),
                    duration: Duration(seconds: 1),
                  ),
                );
              }),
              const SizedBox(width: 12),
              _act(context, Icons.ios_share_rounded, () {
                SharePlus.instance.share(
                  ShareParams(text: 'رمز الغرفة: ${room.joinCode}'),
                );
              }),
            ],
          ),
        ],
      ),
    );
  }

  Widget _act(BuildContext c, IconData icon, VoidCallback onTap) => SiyagTap(
    onTap: onTap,
    child: Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: SC.surfaceHi,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 18, color: SC.emerald),
    ),
  );
}

class _ConnBadge extends StatelessWidget {
  const _ConnBadge({required this.status});
  final RoomConnStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RoomConnStatus.connected => ('متصل', SC.emerald),
      RoomConnStatus.reconnecting ||
      RoomConnStatus.recovering => ('إعادة الاتصال...', SC.coral),
      _ => ('جارٍ الاتصال', SC.textMute),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: ST.ar(13, color: color)),
      ],
    );
  }
}

/// Host-only picker: available players from the directory; tap to invite one to
/// this room (`POST /rooms/{id}/invitations`).
class _InvitePlayersSheet extends ConsumerStatefulWidget {
  const _InvitePlayersSheet({required this.roomId});
  final String roomId;

  @override
  ConsumerState<_InvitePlayersSheet> createState() => _InvitePlayersSheetState();
}

class _InvitePlayersSheetState extends ConsumerState<_InvitePlayersSheet> {
  final Set<String> _invited = {};
  final Set<String> _sending = {};

  Future<void> _invite(SocialPlayer p) async {
    if (_invited.contains(p.publicPlayerId) ||
        _sending.contains(p.publicPlayerId)) {
      return;
    }
    setState(() => _sending.add(p.publicPlayerId));
    try {
      await ref.read(socialRepositoryProvider).inviteToRoom(
        roomId: widget.roomId,
        targetPublicPlayerId: p.publicPlayerId,
      );
      if (mounted) setState(() => _invited.add(p.publicPlayerId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('تعذّر إرسال الدعوة', style: ST.ar(13)),
            backgroundColor: SC.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(p.publicPlayerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final dir = ref.watch(playersDirectoryProvider);
    final players = (dir.asData?.value.players ?? const <SocialPlayer>[])
        .where((p) => p.availableForInvite)
        .toList();

    return Directionality(
      textDirection: TextDirection.rtl,
      child: DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        maxChildSize: 0.9,
        builder: (_, controller) => Column(
          children: [
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: SC.line,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Text('دعوة لاعبين', style: ST.ar(17, weight: FontWeight.w700)),
            const SizedBox(height: 4),
            Text(
              'المتاحون للدعوة الآن',
              style: ST.mono(10, color: SC.textFaint),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dir.isLoading
                  ? Center(child: CircularProgressIndicator(color: SC.gold))
                  : players.isEmpty
                  ? Center(
                      child: Text(
                        'لا يوجد لاعبون متاحون للدعوة',
                        style: ST.ar(14, color: SC.textMute),
                      ),
                    )
                  : ListView.separated(
                      controller: controller,
                      padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
                      itemCount: players.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final p = players[i];
                        final invited = _invited.contains(p.publicPlayerId);
                        final sending = _sending.contains(p.publicPlayerId);
                        final name = p.displayName.isEmpty ? '—' : p.displayName;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: SC.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: SC.line),
                          ),
                          child: Row(
                            children: [
                              SiyagAvatar(
                                letter: name.characters.first,
                                size: 36,
                                imageUrl: p.avatarUrl,
                                active: true,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      name,
                                      style: ST.ar(15, weight: FontWeight.w600),
                                    ),
                                    Text(
                                      p.publicPlayerId,
                                      style: ST.mono(10, color: SC.textFaint),
                                    ),
                                  ],
                                ),
                              ),
                              if (invited)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: SC.emerald,
                                  size: 24,
                                )
                              else
                                SiyagTap(
                                  onTap: sending ? null : () => _invite(p),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 16,
                                      vertical: 8,
                                    ),
                                    decoration: BoxDecoration(
                                      color: SC.goldContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: sending
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: SC.gold,
                                            ),
                                          )
                                        : Text(
                                            'دعوة',
                                            style: ST.ar(
                                              13,
                                              weight: FontWeight.w600,
                                              color: SC.gold,
                                            ),
                                          ),
                                  ),
                                ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Participant extends StatelessWidget {
  const _Participant({required this.p});
  final RoomParticipant p;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
        border: p.isMe
            ? Border.all(color: SC.emerald.withValues(alpha: 0.4))
            : Border.all(color: SC.line),
      ),
      child: Row(
        children: [
          SiyagAvatar(
            letter: p.label.characters.first,
            size: 36,
            color: p.isHost ? SC.coral : SC.emerald,
            active: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.isMe ? '${p.label} (أنت)' : p.label,
              style: ST.ar(15, weight: FontWeight.w500),
            ),
          ),
          Icon(
            p.connected ? Icons.circle : Icons.circle_outlined,
            size: 9,
            color: p.connected ? SC.emerald : SC.textFaint,
          ),
          if (p.isHost) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SC.coralDim,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('المضيف', style: ST.mono(9, color: SC.coral)),
            ),
          ],
        ],
      ),
    );
  }
}
