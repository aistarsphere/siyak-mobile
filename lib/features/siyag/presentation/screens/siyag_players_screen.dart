import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
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
/// player shows as available to others.
///
/// Built from the Siyaq design system — the four bespoke state blocks
/// (~100 lines of hand-rolled loading/error/empty/guest UI) are now the shared
/// state components, and an invitations fetch failure is **surfaced inline**
/// instead of silently rendering as "no invitations".
///
/// Presence heartbeat, accept/decline calls and navigation are unchanged.
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

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final signedIn =
        ref.watch(sessionControllerProvider).asData?.value.isSignedIn ?? false;
    final invites = ref.watch(incomingInvitationsProvider);
    final dir = ref.watch(playersDirectoryProvider);

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('players'),
                accent: c.success,
                onBack: () => Navigator.of(context).maybePop(),
                backLabel: loc('back'),
                trailing: signedIn
                    ? SiyaqIconButton(
                        icon: SiyaqIcons.refresh,
                        semanticLabel: loc('refresh'),
                        onPressed: _refresh,
                      )
                    : null,
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.md,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                ),
              ),
              Expanded(
                child: !signedIn
                    ? Center(
                        child: SiyaqEmptyState(
                          title: loc('guestPlayersTitle'),
                          body: loc('guestPlayersBody'),
                          icon: SiyaqIcons.social,
                          actionLabel: loc('signIn'),
                          onAction: _goSignIn,
                        ),
                      )
                    : RefreshIndicator(
                        color: c.primary,
                        backgroundColor: c.surface,
                        onRefresh: _refresh,
                        child: dir.when(
                          loading: () => ListView(
                            children: [
                              const SizedBox(height: SiyaqSpacing.huge * 2),
                              SiyaqLoader(semanticLabel: loc('loading')),
                            ],
                          ),
                          error: (e, _) => ListView(
                            padding: const EdgeInsets.all(SiyaqSpacing.xxl),
                            children: [
                              const SizedBox(height: SiyaqSpacing.huge),
                              SiyaqEmptyState.error(
                                title: loc('errLoadPlayers'),
                                body: loc('errNetwork'),
                                actionLabel: loc('retry'),
                                onAction: _refresh,
                              ),
                            ],
                          ),
                          data: (directory) => _list(loc, directory, invites),
                        ),
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _list(
    AppLocalizations loc,
    SocialDirectory directory,
    AsyncValue<List<RoomInvitation>> invites,
  ) {
    final c = context.colors;
    final players = directory.players;
    final pending = (invites.asData?.value ?? const <RoomInvitation>[])
        .where((i) => i.status.isActionable)
        .toList();

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SiyaqSpacing.xl,
        SiyaqSpacing.sm,
        SiyaqSpacing.xl,
        SiyaqSpacing.xxl,
      ),
      children: [
        // An invitations failure used to render exactly like "no invitations".
        // Someone waiting on an invite deserves to know the difference.
        if (invites.hasError) ...[
          SiyaqTintedSurface(
            tone: SiyaqTone.warning,
            child: Row(
              children: [
                SiyaqIcon.decorative(
                  SiyaqIcons.offline,
                  size: SiyaqIconSize.md,
                  color: c.warning,
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                Expanded(
                  child: SiyaqText(
                    loc('errLoadInvites'),
                    role: SiyaqTextRole.bodySmall,
                    color: c.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SiyaqSpacing.md),
        ],
        if (pending.isNotEmpty) ...[
          SiyaqText(
            loc('invites').toUpperCase(),
            role: SiyaqTextRole.labelSmall,
            script: SiyaqScript.mono,
            color: c.textMuted,
            header: true,
          ),
          const SizedBox(height: SiyaqSpacing.sm),
          for (final inv in pending) ...[
            _InviteCard(
              loc: loc,
              invitation: inv,
              busy: _acting,
              onAccept: () => _accept(inv),
              onDecline: () => _decline(inv),
            ),
            const SizedBox(height: SiyaqSpacing.smd),
          ],
          const SizedBox(height: SiyaqSpacing.sm),
        ],
        SiyaqText(
          loc('onlineNow').toUpperCase(),
          role: SiyaqTextRole.labelSmall,
          script: SiyaqScript.mono,
          color: c.textMuted,
          header: true,
        ),
        const SizedBox(height: SiyaqSpacing.sm),
        if (players.isEmpty)
          SiyaqEmptyState(
            title: loc('noPlayersTitle'),
            body: loc('noPlayersBody'),
            icon: SiyaqIcons.social,
            actionLabel: loc('refresh'),
            onAction: _refresh,
          )
        else
          for (final p in players) ...[
            SiyaqPlayerRow(
              name: p.displayName.isEmpty ? '—' : p.displayName,
              subtitle: p.publicPlayerId,
              avatarUrl: p.avatarUrl,
              presence: p.presence.isOnline
                  ? SiyaqPresence.online
                  : SiyaqPresence.offline,
              statusLabel: loc(_presenceKey(p.presence)),
              trailing: SiyaqChip(
                label: loc(_presenceKey(p.presence)),
                variant: SiyaqChipVariant.accent,
                accent: _presenceColor(context, p.presence),
              ),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
          ],
      ],
    );
  }
}

/// A pending room invitation with accept/dismiss.
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
    final c = context.colors;
    final host = invitation.host.displayName.isEmpty
        ? invitation.host.publicPlayerId
        : invitation.host.displayName;
    final title = invitation.roomName.isEmpty
        ? loc('gameInvitation')
        : invitation.roomName;

    return SiyaqSurface(
      accent: c.primary,
      selected: true,
      semanticLabel: '$title, ${loc.fill('invitedBy', {'name': host})}',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              SiyaqIcon.decorative(
                SiyaqIcons.invite,
                size: SiyaqIconSize.md,
                color: c.primary,
              ),
              const SizedBox(width: SiyaqSpacing.sm),
              Expanded(
                child: SiyaqText(
                  title,
                  role: SiyaqTextRole.bodyLarge,
                  weight: FontWeight.w700,
                  maxLines: 1,
                ),
              ),
            ],
          ),
          const SizedBox(height: SiyaqSpacing.xxxs),
          SiyaqText(
            loc.fill('invitedBy', {'name': host}),
            role: SiyaqTextRole.bodySmall,
            color: c.textMuted,
          ),
          const SizedBox(height: SiyaqSpacing.md),
          Row(
            children: [
              Expanded(
                child: SiyaqButton(
                  label: loc('accept'),
                  size: SiyaqButtonSize.medium,
                  loading: busy,
                  onPressed: busy ? null : onAccept,
                ),
              ),
              const SizedBox(width: SiyaqSpacing.smd),
              SiyaqButton(
                label: loc('dismiss'),
                type: SiyaqButtonType.secondary,
                size: SiyaqButtonSize.medium,
                onPressed: busy ? null : onDecline,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

Color _presenceColor(BuildContext context, PresenceState p) => switch (p) {
  PresenceState.onlineAvailable => context.colors.success,
  PresenceState.onlineAway => context.colors.warning,
  PresenceState.inLobby => context.colors.info,
  PresenceState.inRoomGame => context.colors.info,
  PresenceState.inRankedMatchmaking => context.colors.primary,
  PresenceState.inRankedMatch => context.colors.primary,
  PresenceState.reconnecting => context.colors.warning,
  PresenceState.offline => context.colors.textDisabled,
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
