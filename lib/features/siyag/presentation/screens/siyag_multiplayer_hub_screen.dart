import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/social_controller.dart';
import '../siyag_route.dart';
import '../siyag_shell.dart';
import 'siyag_create_room_screen.dart';
import 'siyag_join_room_screen.dart';
import 'siyag_players_screen.dart';
import 'siyag_ranked_screen.dart';
import 'siyag_room_lobby_screen.dart';

/// "Play with Friends" hub — the social entry point. Explains the mode, then
/// offers create / join / competitive / online-players, each with a feature
/// colour, a one-line description and a consistent tap target.
///
/// Built from the Siyaq design system — no screen-local cards, icon tiles,
/// badges or text styles. Navigation targets, providers and multiplayer state
/// handling are unchanged from the pre-migration implementation.
class SiyagMultiplayerHubScreen extends ConsumerWidget {
  const SiyagMultiplayerHubScreen({super.key});

  /// Mirrors the Players screen: leave the pushed flow, then select the account
  /// tab where sign-in actually lives.
  void _goSignIn(BuildContext context, WidgetRef ref) {
    Navigator.of(context).maybePop();
    ref.read(siyagTabProvider.notifier).state = 2; // Profile tab
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final active = ref.watch(roomLifecycleControllerProvider).room;
    final invitations = ref.watch(incomingInvitationsProvider);
    final signedIn =
        ref.watch(sessionControllerProvider).asData?.value.isSignedIn ?? false;

    // The count is supplementary: while it loads the badge is simply absent, and
    // a failure never hides the actions behind a full-screen error.
    final pendingInvites = invitations.asData?.value.length ?? 0;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('play'),
                accent: c.success,
                onBack: () => Navigator.of(context).maybePop(),
                backLabel: loc('back'),
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
                    SiyaqText(
                      loc('modeMultiplayer'),
                      role: SiyaqTextRole.displaySmall,
                    ),
                    const SizedBox(height: SiyaqSpacing.xs),
                    SiyaqText(
                      loc('modeMultiplayerDesc'),
                      role: SiyaqTextRole.bodyMedium,
                      color: c.textMuted,
                    ),

                    // ── Guest notice ──────────────────────────────────────────
                    // Informational only: create and join-by-code work without an
                    // account, and the Players screen gates itself. Nothing here
                    // is disabled.
                    if (!signedIn) ...[
                      const SizedBox(height: SiyaqSpacing.xl),
                      SiyaqTintedSurface(
                        tone: SiyaqTone.accent,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            Row(
                              children: [
                                SiyaqIcon.decorative(
                                  SiyaqIcons.playerId,
                                  size: SiyaqIconSize.md,
                                  color: c.primary,
                                ),
                                const SizedBox(width: SiyaqSpacing.sm),
                                Expanded(
                                  child: SiyaqText(
                                    loc('guestPlayersTitle'),
                                    role: SiyaqTextRole.bodyLarge,
                                    color: c.primary,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: SiyaqSpacing.xs),
                            SiyaqText(
                              loc('signInBenefit'),
                              role: SiyaqTextRole.bodySmall,
                              color: c.textMuted,
                            ),
                            const SizedBox(height: SiyaqSpacing.md),
                            SiyaqButton(
                              label: loc('signIn'),
                              icon: SiyaqIcons.signIn,
                              size: SiyaqButtonSize.medium,
                              fullWidth: true,
                              onPressed: () => _goSignIn(context, ref),
                            ),
                          ],
                        ),
                      ),
                    ],

                    // ── Invitations failed to load ────────────────────────────
                    // Surfaced inline with a retry. Pre-migration the error was
                    // swallowed by `.asData?.value.length ?? 0`.
                    if (signedIn && invitations.hasError) ...[
                      const SizedBox(height: SiyaqSpacing.lg),
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
                                loc.errorMessage(invitations.error!),
                                role: SiyaqTextRole.bodySmall,
                                color: c.warning,
                              ),
                            ),
                            const SizedBox(width: SiyaqSpacing.sm),
                            SiyaqButton(
                              label: loc('retry'),
                              type: SiyaqButtonType.secondary,
                              size: SiyaqButtonSize.medium,
                              onPressed: () =>
                                  ref.invalidate(incomingInvitationsProvider),
                            ),
                          ],
                        ),
                      ),
                    ],

                    const SizedBox(height: SiyaqSpacing.xl),

                    // ── Actions ───────────────────────────────────────────────
                    _action(
                      context,
                      icon: SiyaqIcons.addCircle,
                      accent: c.success,
                      title: loc('createRoom'),
                      description: loc('createGameDesc'),
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagCreateRoomScreen())),
                    ),
                    const SizedBox(height: SiyaqSpacing.md),
                    _action(
                      context,
                      icon: SiyaqIcons.signIn,
                      accent: c.success,
                      title: loc('joinRoom'),
                      description: loc('joinGameDesc'),
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagJoinRoomScreen())),
                    ),
                    const SizedBox(height: SiyaqSpacing.md),
                    _action(
                      context,
                      icon: SiyaqIcons.ranked,
                      accent: c.primary,
                      title: loc('competitive'),
                      description: loc('competitiveDesc'),
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagRankedScreen())),
                    ),
                    const SizedBox(height: SiyaqSpacing.md),
                    _action(
                      context,
                      icon: SiyaqIcons.social,
                      accent: c.success,
                      title: loc('players'),
                      description: loc('onlinePlayersDesc'),
                      trailing: SiyaqCountBadge(
                        count: pendingInvites,
                        semanticLabel: '$pendingInvites ${loc('invitations')}',
                      ),
                      // The row is one interactive node, so its own label has to
                      // carry the badge's information — a nested Semantics inside
                      // an interactive row is excluded and would be inaudible.
                      semanticSuffix: pendingInvites > 0
                          ? '$pendingInvites ${loc('invitations')}'
                          : null,
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagPlayersScreen())),
                    ),
                    if (active != null) ...[
                      const SizedBox(height: SiyaqSpacing.md),
                      _action(
                        context,
                        icon: SiyaqIcons.room,
                        accent: c.primary,
                        title: loc('resumeRoom'),
                        description: '${loc('joinCode')}: ${active.joinCode}',
                        onTap: () => Navigator.of(
                          context,
                        ).push(siyagRoute(const SiyagRoomLobbyScreen())),
                      ),
                    ],
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// One hub action, composed from the shared row + icon tile rather than a
  /// screen-local card.
  Widget _action(
    BuildContext context, {
    required IconData icon,
    required Color accent,
    required String title,
    required String description,
    required VoidCallback onTap,
    Widget? trailing,
    String? semanticSuffix,
  }) => SiyaqListRow(
    leading: SiyaqIconTile(
      icon: icon,
      size: SiyaqIconTileSize.medium,
      accent: accent,
      tinted: true,
    ),
    title: title,
    titleRole: SiyaqTextRole.headingSmall,
    subtitle: description,
    trailing: trailing,
    showChevron: true,
    onTap: onTap,
    radius: SiyaqRadius.xxl,
    padding: const EdgeInsets.all(SiyaqSpacing.lg),
    semanticLabel: ['$title. $description', ?semanticSuffix].join(' '),
  );
}
