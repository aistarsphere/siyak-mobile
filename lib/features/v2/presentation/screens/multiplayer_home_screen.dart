import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../controllers/room_controller.dart';
import '../widgets/mode_card.dart';
import '../widgets/v2_scaffold.dart';
import 'create_room_screen.dart';
import 'join_room_screen.dart';
import 'room_lobby_screen.dart';

/// Multiplayer hub: create a room, join with a code, or resume an active room.
class MultiplayerHomeScreen extends ConsumerWidget {
  const MultiplayerHomeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final activeRoom = ref.watch(roomLifecycleControllerProvider).room;

    return V2Scaffold(
      title: loc('modeMultiplayer'),
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
        children: [
          ModeCard(
            index: 0,
            icon: Icons.add_circle_outline,
            title: loc('createRoom'),
            description: loc('modeMultiplayerDesc'),
            highlight: true,
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const CreateRoomScreen())),
          ),
          const SizedBox(height: 12),
          ModeCard(
            index: 1,
            icon: Icons.login,
            title: loc('joinRoom'),
            description: loc('enterJoinCode'),
            onTap: () => Navigator.of(
              context,
            ).push(MaterialPageRoute(builder: (_) => const JoinRoomScreen())),
          ),
          if (activeRoom != null) ...[
            const SizedBox(height: 12),
            ModeCard(
              index: 2,
              icon: Icons.meeting_room_outlined,
              title: loc('resumeRoom'),
              description: '${loc('joinCode')}: ${activeRoom.joinCode}',
              status: loc('connected'),
              statusColor: AppColors.emerald,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const RoomLobbyScreen()),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
