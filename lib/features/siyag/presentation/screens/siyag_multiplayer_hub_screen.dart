import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../../../v2/presentation/controllers/social_controller.dart';
import '../siyag_route.dart';
import 'siyag_create_room_screen.dart';
import 'siyag_join_room_screen.dart';
import 'siyag_players_screen.dart';
import 'siyag_ranked_screen.dart';
import 'siyag_room_lobby_screen.dart';
import 'siyag_topbar.dart';

/// Multiplayer hub (missing flow, designed in-grammar): create, join-by-code,
/// or resume an active room.
class SiyagMultiplayerHubScreen extends ConsumerWidget {
  const SiyagMultiplayerHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final active = ref.watch(roomLifecycleControllerProvider).room;
    final pendingInvites =
        ref.watch(incomingInvitationsProvider).asData?.value.length ?? 0;
    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(kicker: 'Multiplayer', kickerColor: SC.emerald),
              const SizedBox(height: 8),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                  children: [
                    Text(
                      'الغرفة المباشرة',
                      style: ST.ar(26, weight: FontWeight.w700, height: 1.1),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'العب نفس الكلمة مع أصدقائك في الوقت الفعلي',
                      style: ST.ar(14, color: SC.textMute),
                    ),
                    const SizedBox(height: 20),
                    _row(
                      icon: Icons.add_circle_outline_rounded,
                      color: SC.emerald,
                      ar: 'إنشاء غرفة',
                      en: 'Create Room',
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagCreateRoomScreen())),
                    ),
                    const SizedBox(height: 12),
                    _row(
                      icon: Icons.login_rounded,
                      color: SC.cyan,
                      ar: 'انضمام برمز',
                      en: 'Join by code',
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagJoinRoomScreen())),
                    ),
                    const SizedBox(height: 12),
                    _row(
                      icon: Icons.military_tech_rounded,
                      color: SC.gold,
                      ar: 'المصنّفة 1v1',
                      en: 'Ranked 1v1 · staked',
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagRankedScreen())),
                    ),
                    const SizedBox(height: 12),
                    _row(
                      icon: Icons.groups_rounded,
                      color: SC.cyan,
                      ar: 'اللاعبون',
                      en: 'Players online · invites',
                      badge: pendingInvites,
                      onTap: () => Navigator.of(
                        context,
                      ).push(siyagRoute(const SiyagPlayersScreen())),
                    ),
                    if (active != null) ...[
                      const SizedBox(height: 12),
                      _row(
                        icon: Icons.meeting_room_outlined,
                        color: SC.coral,
                        ar: 'متابعة الغرفة',
                        en: 'Code ${active.joinCode}',
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

  Widget _row({
    required IconData icon,
    required Color color,
    required String ar,
    required String en,
    required VoidCallback onTap,
    int badge = 0,
  }) => SiyagTap(
    onTap: onTap,
    scale: 0.98,
    child: Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(24),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Icon(icon, size: 20, color: color),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(ar, style: ST.ar(16, weight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(en, style: ST.mono(10, color: SC.textMute)),
              ],
            ),
          ),
          if (badge > 0)
            Container(
              margin: const EdgeInsetsDirectional.only(end: 8),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
              decoration: BoxDecoration(
                color: SC.coral,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '$badge',
                style: ST.mono(11, color: SC.onAccent),
              ),
            ),
          Icon(Icons.chevron_left_rounded, size: 18, color: SC.textFaint),
        ],
      ),
    ),
  );
}
