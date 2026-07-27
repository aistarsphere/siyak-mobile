import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/theme/context_tokens.dart';
import '../../../../core/design/theme/legacy_type_bridge.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/social_controller.dart';
import '../siyag_route.dart';
import 'siyag_create_room_screen.dart';
import 'siyag_join_room_screen.dart';
import 'siyag_players_screen.dart';
import 'siyag_ranked_screen.dart';
import 'siyag_room_lobby_screen.dart';
import 'siyag_topbar.dart';

/// "Play with Friends" hub — the social entry point. Explains the mode, then
/// offers create / join / competitive / online-players, each with an icon,
/// a one-line description and a consistent feature colour. Fully localized
/// (AR + EN, direction-aware).
class SiyagMultiplayerHubScreen extends ConsumerWidget {
  const SiyagMultiplayerHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final active = ref.watch(roomLifecycleControllerProvider).room;
    final pendingInvites =
        ref.watch(incomingInvitationsProvider).asData?.value.length ?? 0;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(
                kicker: loc('play'),
                kickerColor: context.colors.success,
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      loc('modeMultiplayer'),
                      style: context.legacyType.ar(
                        26,
                        weight: FontWeight.w700,
                        height: 1.1,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      loc('modeMultiplayerDesc'),
                      style: context.legacyType.ar(
                        14,
                        color: context.colors.textMuted,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 20),
                    _ActionCard(
                      index: 0,
                      icon: Icons.add_circle_outline_rounded,
                      color: context.colors.success,
                      title: loc('createRoom'),
                      description: loc('createGameDesc'),
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagCreateRoomScreen())),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      index: 1,
                      icon: Icons.login_rounded,
                      color: context.colors.success,
                      title: loc('joinRoom'),
                      description: loc('joinGameDesc'),
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagJoinRoomScreen())),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      index: 2,
                      icon: Icons.military_tech_rounded,
                      color: context.colors.primary,
                      title: loc('competitive'),
                      description: loc('competitiveDesc'),
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagRankedScreen())),
                    ),
                    const SizedBox(height: 12),
                    _ActionCard(
                      index: 3,
                      icon: Icons.groups_rounded,
                      color: context.colors.success,
                      title: loc('players'),
                      description: loc('onlinePlayersDesc'),
                      badge: pendingInvites,
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagPlayersScreen())),
                    ),
                    if (active != null) ...[
                      const SizedBox(height: 12),
                      _ActionCard(
                        index: 4,
                        icon: Icons.meeting_room_outlined,
                        color: context.colors.primary,
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
}

/// A single hub action: icon tile + title + description + optional count badge.
class _ActionCard extends StatelessWidget {
  const _ActionCard({
    required this.index,
    required this.icon,
    required this.color,
    required this.title,
    required this.description,
    required this.onTap,
    this.badge = 0,
  });

  final int index;
  final IconData icon;
  final Color color;
  final String title;
  final String description;
  final VoidCallback onTap;
  final int badge;

  @override
  Widget build(BuildContext context) => SiyagTap(
    onTap: onTap,
    scale: 0.98,
    child: Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 46,
            height: 46,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 22, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: context.legacyType.ar(17, weight: FontWeight.w700),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: context.legacyType.ar(
                    12.5,
                    color: context.colors.textMuted,
                    height: 1.35,
                  ),
                ),
              ],
            ),
          ),
          if (badge > 0) ...[
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: context.colors.primary,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$badge',
                style: context.legacyType.mono(
                  11,
                  color: context.colors.onPrimary,
                ),
              ),
            ),
          ],
        ],
      ),
    ),
  );
}
