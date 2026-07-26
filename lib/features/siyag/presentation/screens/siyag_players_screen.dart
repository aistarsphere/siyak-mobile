import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/social.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/social_controller.dart';
import '../siyag_route.dart';
import '../siyag_shell.dart';
import 'siyag_room_lobby_screen.dart';

/// Online players + incoming game invitations (contract §9–10). Account-only —
/// guests get a sign-in prompt. While open, the screen beats presence so the
/// player shows as available to others. Fully localized (AR + EN).
class SiyagPlayersScreen extends ConsumerStatefulWidget {
  const SiyagPlayersScreen({super.key});

  @override
  ConsumerState<SiyagPlayersScreen> createState() => _SiyagPlayersScreenState();
}

class _SiyagPlayersScreenState extends ConsumerState<SiyagPlayersScreen> {
  Timer? _presence;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _beat();
      _presence = Timer.periodic(const Duration(seconds: 20), (_) => _beat());
    });
  }

  @override
  void dispose() {
    _presence?.cancel();
    super.dispose();
  }

  void _beat() => ref
      .read(socialRepositoryProvider)
      .heartbeat(state: PresenceState.onlineAvailable)
      .ignore();

  Future<void> _refresh() async {
    ref.invalidate(playersDirectoryProvider);
    ref.invalidate(incomingInvitationsProvider);
    await Future.wait([
      ref.read(playersDirectoryProvider.future),
      ref.read(incomingInvitationsProvider.future),
    ]);
  }

  void _goSignIn() {
    Navigator.of(context).maybePop();
    ref.read(siyagTabProvider.notifier).state = 2; // Profile tab
  }

  Future<void> _accept(RoomInvitation inv) async {
    if (_acting) return;
    setState(() => _acting = true);
    final loc = ref.read(localizationsProvider);
    try {
      final roomId = await ref
          .read(socialRepositoryProvider)
          .acceptInvitation(inv.invitationId);
      final room = await ref
          .read(roomLifecycleControllerProvider.notifier)
          .openById(roomId);
      if (!mounted) return;
      if (room != null) {
        Navigator.of(context).push(siyagRoute(const SiyagRoomLobbyScreen()));
      } else {
        _snack(loc('errOpenGame'));
      }
    } catch (_) {
      if (mounted) _snack(loc('errAcceptFailed'));
    } finally {
      if (mounted) setState(() => _acting = false);
      ref.invalidate(incomingInvitationsProvider);
    }
  }

  Future<void> _decline(RoomInvitation inv) async {
    try {
      await ref
          .read(socialRepositoryProvider)
          .declineInvitation(inv.invitationId);
    } catch (_) {
      /* best-effort */
    }
    ref.invalidate(incomingInvitationsProvider);
  }

  void _snack(String msg) => ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(msg, style: ST.ar(13)), backgroundColor: SC.surface),
  );

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final signedIn =
        ref.watch(sessionControllerProvider).asData?.value.isSignedIn ?? false;
    final invites =
        ref.watch(incomingInvitationsProvider).asData?.value ??
        const <RoomInvitation>[];
    final dir = ref.watch(playersDirectoryProvider);

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: SC.bg,
        appBar: AppBar(
          backgroundColor: SC.bg,
          elevation: 0,
          title: Text(loc('players'), style: ST.ar(18, weight: FontWeight.w700)),
          centerTitle: true,
          actions: [
            if (signedIn)
              IconButton(
                icon: Icon(Icons.refresh_rounded, color: SC.textDim),
                onPressed: _refresh,
              ),
          ],
        ),
        body: SafeArea(
          child: !signedIn
              ? _signInPrompt(loc)
              : RefreshIndicator(
                  color: SC.gold,
                  backgroundColor: SC.surface,
                  onRefresh: _refresh,
                  child: dir.when(
                    loading: () => _loading(),
                    error: (e, _) => _error(loc),
                    data: (directory) => _list(loc, directory, invites),
                  ),
                ),
        ),
      ),
    );
  }

  Widget _signInPrompt(AppLocalizations loc) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 80),
      Icon(Icons.groups_rounded, size: 48, color: SC.textFaint),
      const SizedBox(height: 16),
      Text(
        loc('guestPlayersTitle'),
        textAlign: TextAlign.center,
        style: ST.ar(17, weight: FontWeight.w700),
      ),
      const SizedBox(height: 8),
      Text(
        loc('guestPlayersBody'),
        textAlign: TextAlign.center,
        style: ST.ar(13, color: SC.textMute, height: 1.5),
      ),
      const SizedBox(height: 20),
      SiyagPrimaryButton(
        label: loc('signIn'),
        icon: Icons.login_rounded,
        onTap: _goSignIn,
      ),
    ],
  );

  Widget _loading() => ListView(
    children: [
      const SizedBox(height: 120),
      Center(child: CircularProgressIndicator(color: SC.gold)),
    ],
  );

  Widget _error(AppLocalizations loc) => ListView(
    padding: const EdgeInsets.all(24),
    children: [
      const SizedBox(height: 100),
      Icon(Icons.wifi_off_rounded, size: 40, color: SC.textFaint),
      const SizedBox(height: 12),
      Text(
        loc('errLoadPlayers'),
        textAlign: TextAlign.center,
        style: ST.ar(15, weight: FontWeight.w600),
      ),
      const SizedBox(height: 6),
      Text(
        loc('errNetwork'),
        textAlign: TextAlign.center,
        style: ST.ar(12, color: SC.textMute),
      ),
      const SizedBox(height: 14),
      Center(child: SiyagPrimaryButton(label: loc('retry'), onTap: _refresh)),
    ],
  );

  Widget _list(
    AppLocalizations loc,
    SocialDirectory directory,
    List<RoomInvitation> invites,
  ) {
    final players = directory.players;
    final pending = invites.where((i) => i.status.isActionable).toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
      children: [
        if (pending.isNotEmpty) ...[
          Kicker(loc('invites')),
          const SizedBox(height: 10),
          for (final inv in pending) ...[
            _InviteCard(
              loc: loc,
              invitation: inv,
              busy: _acting,
              onAccept: () => _accept(inv),
              onDecline: () => _decline(inv),
            ),
            const SizedBox(height: 10),
          ],
          const SizedBox(height: 10),
        ],
        Kicker(loc('onlineNow')),
        const SizedBox(height: 10),
        if (players.isEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 40),
            child: Column(
              children: [
                Icon(
                  Icons.people_outline_rounded,
                  size: 40,
                  color: SC.textFaint,
                ),
                const SizedBox(height: 12),
                Text(
                  loc('noPlayersTitle'),
                  textAlign: TextAlign.center,
                  style: ST.ar(15, weight: FontWeight.w600),
                ),
                const SizedBox(height: 4),
                Text(
                  loc('noPlayersBody'),
                  textAlign: TextAlign.center,
                  style: ST.ar(12.5, color: SC.textMute),
                ),
                const SizedBox(height: 14),
                SiyagPrimaryButton(
                  label: loc('refresh'),
                  fullWidth: false,
                  onTap: _refresh,
                ),
              ],
            ),
          )
        else
          for (final p in players) ...[
            _PlayerRow(loc: loc, player: p),
            const SizedBox(height: 8),
          ],
      ],
    );
  }
}

class _PlayerRow extends StatelessWidget {
  const _PlayerRow({required this.loc, required this.player});
  final AppLocalizations loc;
  final SocialPlayer player;

  @override
  Widget build(BuildContext context) {
    final name = player.displayName.isEmpty ? '—' : player.displayName;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: SC.line),
      ),
      child: Row(
        children: [
          Stack(
            children: [
              SiyagAvatar(
                letter: name.characters.first,
                imageUrl: player.avatarUrl,
                active: player.presence.isOnline,
              ),
              Positioned(
                right: 0,
                bottom: 0,
                child: Container(
                  width: 12,
                  height: 12,
                  decoration: BoxDecoration(
                    color: _presenceColor(player.presence),
                    shape: BoxShape.circle,
                    border: Border.all(color: SC.surface, width: 2),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: ST.ar(15, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  player.publicPlayerId,
                  style: ST.mono(10, color: SC.textFaint),
                ),
              ],
            ),
          ),
          _PresenceChip(loc: loc, presence: player.presence),
        ],
      ),
    );
  }
}

class _PresenceChip extends StatelessWidget {
  const _PresenceChip({required this.loc, required this.presence});
  final AppLocalizations loc;
  final PresenceState presence;

  @override
  Widget build(BuildContext context) {
    final c = _presenceColor(presence);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: c.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        loc(_presenceKey(presence)),
        style: ST.ar(10, weight: FontWeight.w600, color: c),
      ),
    );
  }
}

class _InviteCard extends StatelessWidget {
  const _InviteCard({
    required this.loc,
    required this.invitation,
    required this.busy,
    required this.onAccept,
    required this.onDecline,
  });

  final AppLocalizations loc;
  final RoomInvitation invitation;
  final bool busy;
  final VoidCallback onAccept;
  final VoidCallback onDecline;

  @override
  Widget build(BuildContext context) {
    final host = invitation.host.displayName.isEmpty
        ? invitation.host.publicPlayerId
        : invitation.host.displayName;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: SC.gold.withValues(alpha: 0.4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.mail_outline_rounded, size: 20, color: SC.gold),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  invitation.roomName.isEmpty
                      ? loc('gameInvitation')
                      : invitation.roomName,
                  style: ST.ar(15, weight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            loc.fill('invitedBy', {'name': host}),
            style: ST.ar(12, color: SC.textMute),
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: SiyagPrimaryButton(
                  label: loc('accept'),
                  busy: busy,
                  onTap: busy ? null : onAccept,
                ),
              ),
              const SizedBox(width: 10),
              SiyagTap(
                onTap: busy ? null : onDecline,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 18,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: SC.line),
                  ),
                  child: Text(loc('dismiss'), style: ST.ar(13, color: SC.textDim)),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _presenceColor(PresenceState p) => switch (p) {
  PresenceState.onlineAvailable => SC.emerald,
  PresenceState.onlineAway => SC.warning,
  PresenceState.inLobby => SC.cyan,
  PresenceState.inRoomGame => SC.cyan,
  PresenceState.inRankedMatchmaking => SC.gold,
  PresenceState.inRankedMatch => SC.gold,
  PresenceState.reconnecting => SC.warning,
  PresenceState.offline => SC.textFaint,
};

String _presenceKey(PresenceState p) => switch (p) {
  PresenceState.onlineAvailable => 'presAvailable',
  PresenceState.onlineAway => 'presAway',
  PresenceState.inLobby => 'presInLobby',
  PresenceState.inRoomGame => 'presInGame',
  PresenceState.inRankedMatchmaking => 'presSearching',
  PresenceState.inRankedMatch => 'presInMatch',
  PresenceState.reconnecting => 'presReconnecting',
  PresenceState.offline => 'presOffline',
};
