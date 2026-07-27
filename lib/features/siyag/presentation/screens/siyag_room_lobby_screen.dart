import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/design/theme/context_tokens.dart';
import '../../../../core/design/theme/legacy_type_bridge.dart';
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
    backgroundColor: context.colors.background,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _InvitePlayersSheet(roomId: roomId),
  );

  /// Confirm, then leave the room (realtime + REST) and pop.
  Future<void> _leave() async {
    final loc = ref.read(localizationsProvider);
    final ok = await showSiyagConfirm(
      context,
      direction: loc.direction,
      title: loc('confirmLeaveTitle'),
      body: loc('confirmLeaveBody'),
      confirmLabel: loc('leave'),
      cancelLabel: loc('stay'),
    );
    if (!ok) return;
    await ref.read(realtimeRoomControllerProvider.notifier).leave();
    await ref.read(roomLifecycleControllerProvider.notifier).leave();
    if (mounted) Navigator.of(context).maybePop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
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
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: room == null
                ? Center(
                    child: CircularProgressIndicator(
                      color: context.colors.primary,
                    ),
                  )
                : Column(
                    children: [
                      SiyagTopBar(
                        kicker: ref.read(localizationsProvider)(
                          'modeMultiplayer',
                        ),
                        kickerColor: context.colors.success,
                        onBack: _leave,
                      ),
                      Expanded(
                        child: ListView(
                          padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                          children: [
                            _CodeCard(room: room, loc: loc),
                            const SizedBox(height: 16),
                            _ConnBadge(loc: loc, status: conn.status),
                            const SizedBox(height: 12),
                            Text(
                              '${loc('playersLabel')} (${room.participants.length}${room.maxPlayers != null ? '/${room.maxPlayers}' : ''})',
                              style: context.legacyType.mono(
                                11,
                                color: context.colors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 8),
                            for (final p in room.participants)
                              _Participant(p: p, loc: loc),
                          ],
                        ),
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        child: Column(
                          children: [
                            if (room.amHost) ...[
                              SiyagPrimaryButton(
                                label: loc('startRoom'),
                                color: context.colors.success,
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
                                label: loc('invitePlayers'),
                                icon: Icons.person_add_alt_1_rounded,
                                onTap: () => _showInviteSheet(room.roomId),
                              ),
                            ] else
                              Text(
                                loc('waitingForHost'),
                                style: context.legacyType.ar(
                                  14,
                                  color: context.colors.textMuted,
                                ),
                              ),
                            const SizedBox(height: 10),
                            SiyagGhostButton(
                              label: ref.read(localizationsProvider)(
                                'leaveRoom',
                              ),
                              icon: Icons.logout_rounded,
                              onTap: _leave,
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
  const _CodeCard({required this.room, required this.loc});
  final Room room;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: context.colors.success.withValues(alpha: 0.27),
        ),
      ),
      child: Column(
        children: [
          Kicker(loc('joinCode'), color: context.colors.success),
          const SizedBox(height: 8),
          Text(
            room.joinCode,
            style: context.legacyType.mono(34, letterSpacing: 8),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _act(context, Icons.copy_rounded, () {
                Clipboard.setData(ClipboardData(text: room.joinCode));
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(loc('copied')),
                    duration: const Duration(seconds: 1),
                  ),
                );
              }),
              const SizedBox(width: 12),
              _act(context, Icons.ios_share_rounded, () {
                SharePlus.instance.share(
                  ShareParams(
                    text: loc.fill('shareRoomCode', {'code': room.joinCode}),
                  ),
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
        color: c.colors.surfaceElevated,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Icon(icon, size: 18, color: c.colors.success),
    ),
  );
}

class _ConnBadge extends StatelessWidget {
  const _ConnBadge({required this.loc, required this.status});
  final AppLocalizations loc;
  final RoomConnStatus status;

  @override
  Widget build(BuildContext context) {
    final (label, color) = switch (status) {
      RoomConnStatus.connected => (loc('connected'), context.colors.success),
      RoomConnStatus.reconnecting || RoomConnStatus.recovering => (
        loc('reconnecting'),
        context.colors.primary,
      ),
      _ => (loc('connecting2'), context.colors.textMuted),
    };
    return Row(
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 8),
        Text(label, style: context.legacyType.ar(13, color: color)),
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
  ConsumerState<_InvitePlayersSheet> createState() =>
      _InvitePlayersSheetState();
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
      await ref
          .read(socialRepositoryProvider)
          .inviteToRoom(
            roomId: widget.roomId,
            targetPublicPlayerId: p.publicPlayerId,
          );
      if (mounted) setState(() => _invited.add(p.publicPlayerId));
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              ref.read(localizationsProvider)('errInviteFailed'),
              style: context.legacyType.ar(13),
            ),
            backgroundColor: context.colors.surface,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _sending.remove(p.publicPlayerId));
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final dir = ref.watch(playersDirectoryProvider);
    final players = (dir.asData?.value.players ?? const <SocialPlayer>[])
        .where((p) => p.availableForInvite)
        .toList();

    return Directionality(
      textDirection: loc.direction,
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
                color: context.colors.border,
                borderRadius: BorderRadius.circular(999),
              ),
            ),
            const SizedBox(height: 14),
            Text(
              loc('invitePlayers'),
              style: context.legacyType.ar(17, weight: FontWeight.w700),
            ),
            const SizedBox(height: 4),
            Text(
              loc('availableToInvite'),
              style: context.legacyType.mono(
                10,
                color: context.colors.textDisabled,
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: dir.isLoading
                  ? Center(
                      child: CircularProgressIndicator(
                        color: context.colors.primary,
                      ),
                    )
                  : players.isEmpty
                  ? Center(
                      child: Text(
                        loc('noPlayersTitle'),
                        style: context.legacyType.ar(
                          14,
                          color: context.colors.textMuted,
                        ),
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
                        final name = p.displayName.isEmpty
                            ? '—'
                            : p.displayName;
                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: context.colors.surface,
                            borderRadius: BorderRadius.circular(16),
                            border: Border.all(color: context.colors.border),
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
                                      style: context.legacyType.ar(
                                        15,
                                        weight: FontWeight.w600,
                                      ),
                                    ),
                                    Text(
                                      p.publicPlayerId,
                                      style: context.legacyType.mono(
                                        10,
                                        color: context.colors.textDisabled,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (invited)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: context.colors.success,
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
                                      color: context.colors.primaryContainer,
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    child: sending
                                        ? SizedBox(
                                            width: 16,
                                            height: 16,
                                            child: CircularProgressIndicator(
                                              strokeWidth: 2,
                                              color: context.colors.primary,
                                            ),
                                          )
                                        : Text(
                                            loc('invite'),
                                            style: context.legacyType.ar(
                                              13,
                                              weight: FontWeight.w600,
                                              color: context.colors.primary,
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
  const _Participant({required this.p, required this.loc});
  final RoomParticipant p;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
        border: p.isMe
            ? Border.all(color: context.colors.success.withValues(alpha: 0.4))
            : Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          SiyagAvatar(
            letter: p.label.characters.first,
            size: 36,
            color: p.isHost ? context.colors.primary : context.colors.success,
            active: true,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              p.isMe ? '${p.label} (${loc('you')})' : p.label,
              style: context.legacyType.ar(15, weight: FontWeight.w500),
            ),
          ),
          Icon(
            p.connected ? Icons.circle : Icons.circle_outlined,
            size: 9,
            color: p.connected
                ? context.colors.success
                : context.colors.textDisabled,
          ),
          if (p.isHost) ...[
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.primaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                loc('host'),
                style: context.legacyType.mono(
                  9,
                  color: context.colors.primary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
