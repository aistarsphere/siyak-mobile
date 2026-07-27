import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
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

/// Multiplayer lobby: join code + copy/share, participants with host badge and
/// connection state, host start, leave. Connects the realtime socket on open and
/// enters the live game on `room.started`.
///
/// Built from the Siyaq design system — no screen-local code card, participant
/// row, connection badge or invite tile. Realtime wiring, room actions and
/// navigation are unchanged from the pre-migration implementation.
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

  void _showInviteSheet(String roomId) {
    final loc = ref.read(localizationsProvider);
    SiyaqSheet.show<void>(
      context: context,
      direction: loc.direction,
      builder: (_) => _InvitePlayersSheet(roomId: roomId),
    );
  }

  /// Confirm, then leave the room (realtime + REST) and pop.
  Future<void> _leave() async {
    final loc = ref.read(localizationsProvider);
    final ok = await showSiyaqConfirm(
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

  Future<void> _start(Room room) async {
    try {
      await ref.read(roomRepositoryProvider).start(roomId: room.roomId);
    } catch (e) {
      // State.mounted, not context.mounted: this is a State method and the
      // analyzer (correctly) wants the State guarded.
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ref.read(localizationsProvider).errorMessage(e)),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
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
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: AnimatedSwitcher(
            duration: SiyaqMotion.summaryIn,
            child: room == null
                ? SiyaqLoader(semanticLabel: loc('loading'))
                : _Lobby(
                    room: room,
                    status: conn.status,
                    loc: loc,
                    onLeave: _leave,
                    onStart: () => _start(room),
                    onInvite: () => _showInviteSheet(room.roomId),
                  ),
          ),
        ),
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.room,
    required this.status,
    required this.loc,
    required this.onLeave,
    required this.onStart,
    required this.onInvite,
  });

  final Room room;
  final RoomConnStatus status;
  final AppLocalizations loc;
  final VoidCallback onLeave;
  final VoidCallback onStart;
  final VoidCallback onInvite;

  /// Connection state → label + tone, so the dot and text always agree.
  (String, SiyaqTone, bool) _conn() => switch (status) {
    RoomConnStatus.connected => (loc('connected'), SiyaqTone.success, false),
    RoomConnStatus.reconnecting ||
    RoomConnStatus.recovering => (loc('reconnecting'), SiyaqTone.warning, true),
    _ => (loc('connecting2'), SiyaqTone.info, true),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final (connLabel, connTone, connPulse) = _conn();
    final count = room.maxPlayers != null
        ? '${room.participants.length}/${room.maxPlayers}'
        : '${room.participants.length}';

    return Column(
      children: [
        SiyaqScreenHeader(
          kicker: loc('modeMultiplayer'),
          accent: c.success,
          onBack: onLeave,
          backLabel: loc('leaveRoom'),
          padding: const EdgeInsets.fromLTRB(
            SiyaqSpacing.xl,
            SiyaqSpacing.md,
            SiyaqSpacing.xl,
            SiyaqSpacing.sm,
          ),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xl,
              SiyaqSpacing.sm,
              SiyaqSpacing.xl,
              SiyaqSpacing.xxl,
            ),
            children: [
              SiyaqCodeDisplay(
                code: room.joinCode,
                label: loc('joinCode'),
                accent: c.success,
                copyLabel: loc('copy'),
                shareLabel: loc('share'),
                onCopy: () {
                  Clipboard.setData(ClipboardData(text: room.joinCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(loc('copied')),
                      duration: const Duration(seconds: 1),
                    ),
                  );
                },
                onShare: () => SharePlus.instance.share(
                  ShareParams(
                    text: loc.fill('shareRoomCode', {'code': room.joinCode}),
                  ),
                ),
              ),
              const SizedBox(height: SiyaqSpacing.lg),
              SiyaqStatusIndicator(
                label: connLabel,
                tone: connTone,
                pulse: connPulse,
              ),
              const SizedBox(height: SiyaqSpacing.md),
              SiyaqText(
                '${loc('playersLabel')} ($count)'.toUpperCase(),
                role: SiyaqTextRole.labelSmall,
                script: SiyaqScript.mono,
                color: c.textMuted,
              ),
              const SizedBox(height: SiyaqSpacing.sm),
              for (final p in room.participants) ...[
                SiyaqPlayerRow(
                  name: p.label,
                  isSelf: p.isMe,
                  selfSuffix: p.isMe ? loc('you') : null,
                  presence: p.connected
                      ? SiyaqPresence.online
                      : SiyaqPresence.offline,
                  statusLabel: p.connected
                      ? loc('connected')
                      : loc('presOffline'),
                  roleLabel: p.isHost ? loc('host') : null,
                  accent: p.isHost ? c.primary : c.success,
                ),
                const SizedBox(height: SiyaqSpacing.sm),
              ],
              // A room always has at least the host, so an empty participant
              // list means the roster has not arrived yet.
              if (room.participants.isEmpty)
                SiyaqEmptyState(
                  title: loc('waitingForPlayers'),
                  icon: SiyaqIcons.social,
                ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SiyaqSpacing.xl,
            SiyaqSpacing.sm,
            SiyaqSpacing.xl,
            SiyaqSpacing.xxl,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (room.amHost) ...[
                SiyaqButton(
                  label: loc('startRoom'),
                  icon: SiyaqIcons.play,
                  accent: c.success,
                  fullWidth: true,
                  onPressed: onStart,
                ),
                const SizedBox(height: SiyaqSpacing.smd),
                SiyaqButton(
                  label: loc('invitePlayers'),
                  icon: SiyaqIcons.invite,
                  type: SiyaqButtonType.secondary,
                  fullWidth: true,
                  onPressed: onInvite,
                ),
              ] else
                SiyaqStatusIndicator(
                  label: loc('waitingForHost'),
                  tone: SiyaqTone.info,
                  pulse: true,
                ),
              const SizedBox(height: SiyaqSpacing.smd),
              SiyaqButton(
                label: loc('leaveRoom'),
                icon: SiyaqIcons.leave,
                type: SiyaqButtonType.ghost,
                fullWidth: true,
                onPressed: onLeave,
              ),
            ],
          ),
        ),
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
            content: Text(ref.read(localizationsProvider)('errInviteFailed')),
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
    final c = context.colors;
    final dir = ref.watch(playersDirectoryProvider);
    final players = (dir.asData?.value.players ?? const <SocialPlayer>[])
        .where((p) => p.availableForInvite)
        .toList();

    Widget body() {
      if (dir.isLoading) return SiyaqLoader(semanticLabel: loc('loading'));
      if (dir.hasError) {
        return SiyaqEmptyState.error(
          title: loc('somethingWrong'),
          body: loc.errorMessage(dir.error!),
          actionLabel: loc('retry'),
          onAction: () => ref.invalidate(playersDirectoryProvider),
        );
      }
      if (players.isEmpty) {
        return SiyaqEmptyState(
          title: loc('noPlayersTitle'),
          icon: SiyaqIcons.social,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          for (final p in players) ...[
            SiyaqPlayerRow(
              name: p.displayName.isEmpty ? '—' : p.displayName,
              subtitle: p.publicPlayerId,
              avatarUrl: p.avatarUrl,
              statusLabel: _invited.contains(p.publicPlayerId)
                  ? loc('invited')
                  : null,
              trailing: _invited.contains(p.publicPlayerId)
                  ? SiyaqIcon(
                      SiyaqIcons.checkCircle,
                      semanticLabel: loc('invited'),
                      color: c.success,
                      size: SiyaqIconSize.lg,
                    )
                  : SiyaqButton(
                      label: loc('invite'),
                      type: SiyaqButtonType.secondary,
                      size: SiyaqButtonSize.medium,
                      loading: _sending.contains(p.publicPlayerId),
                      onPressed: () => _invite(p),
                    ),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
          ],
        ],
      );
    }

    return SiyaqSheet(
      title: loc('invitePlayers'),
      body: loc('availableToInvite'),
      child: ConstrainedBox(
        // Bounded so the sheet scrolls rather than growing past the viewport
        // with a long directory.
        constraints: BoxConstraints(
          maxHeight: MediaQuery.sizeOf(context).height * 0.5,
        ),
        child: SingleChildScrollView(child: body()),
      ),
    );
  }
}
