import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../controllers/app_settings_controller.dart';
import '../widgets/atmospheric_background.dart';
import '../widgets/bottom_nav.dart';
import 'game_screen.dart';
import 'home_screen.dart';
import 'settings_screen.dart';

/// Tab index provider so screens (e.g. Home's "new game") can switch tabs.
final shellTabProvider = StateProvider<int>((ref) => 0);

/// App shell mirroring the Stitch BottomNavBar:
/// الرئيسية (Home) · العب (Play) · الإحصائيات (Stats & settings).
class ShellScreen extends ConsumerWidget {
  const ShellScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(shellTabProvider);
    final loc = ref.watch(localizationsProvider);

    return Scaffold(
      extendBody: true,
      body: AtmosphericBackground(
        child: IndexedStack(
          index: index,
          children: const [
            HomeScreen(),
            GameScreen(),
            SettingsScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SiyaqBottomNav(
        index: index,
        onChanged: (i) => ref.read(shellTabProvider.notifier).state = i,
        items: [
          SiyaqNavItem(
            icon: Icons.home_outlined,
            filledIcon: Icons.home,
            label: loc('home'),
          ),
          SiyaqNavItem(
            icon: Icons.play_circle_outline,
            filledIcon: Icons.play_circle,
            label: loc('play'),
          ),
          SiyaqNavItem(
            icon: Icons.leaderboard_outlined,
            filledIcon: Icons.leaderboard,
            label: loc('stats'),
          ),
        ],
      ),
    );
  }
}
