import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/theme/siyag_theme.dart';
import '../../../core/widgets/siyag/siyag_bottom_nav.dart';
import 'screens/siyag_home_screen.dart';
import 'screens/siyag_leaderboard_screen.dart';
import 'screens/siyag_profile_screen.dart';

/// Bottom-nav tab index (home / leaderboard / profile).
final siyagTabProvider = StateProvider<int>((ref) => 0);

/// App shell — three destinations with the sliding coral dot; full-screen
/// flows (gameplay, weekly, multiplayer, result) are pushed as routes and hide
/// the nav, per App.tsx.
class SiyagShell extends ConsumerWidget {
  const SiyagShell({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final index = ref.watch(siyagTabProvider);
    // Depend on Theme so a light/dark switch rebuilds the shell; re-key the
    // stack by brightness so the visible tab repaints immediately (the custom
    // SC-token screens don't otherwise subscribe to Theme changes).
    final brightness = Theme.of(context).brightness;
    return Scaffold(
      backgroundColor: SC.bg,
      body: SafeArea(
        bottom: false,
        child: IndexedStack(
          key: ValueKey(brightness),
          index: index,
          children: const [
            SiyagHomeScreen(),
            SiyagLeaderboardScreen(),
            SiyagProfileScreen(),
          ],
        ),
      ),
      bottomNavigationBar: SiyagBottomNav(
        index: index,
        onChanged: (i) => ref.read(siyagTabProvider.notifier).state = i,
        items: const [
          SiyagNavItem(icon: Icons.home_rounded, label: 'الرئيسية'),
          SiyagNavItem(icon: Icons.emoji_events_rounded, label: 'الترتيب'),
          SiyagNavItem(icon: Icons.person_rounded, label: 'حسابي'),
        ],
      ),
    );
  }
}
