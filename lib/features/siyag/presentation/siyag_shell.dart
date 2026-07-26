import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../core/theme/siyag_theme.dart';
import '../../../core/widgets/siyag/siyag_bottom_nav.dart';
import '../../auth/presentation/controllers/session_controller.dart';
import '../../game/presentation/controllers/app_settings_controller.dart';
import 'screens/siyag_home_screen.dart';
import 'screens/siyag_leaderboard_screen.dart';
import 'screens/siyag_profile_screen.dart';

/// Bottom-nav tab index (home / leaderboard / profile).
final siyagTabProvider = StateProvider<int>((ref) => 0);

/// App shell — three destinations with the sliding coral dot; full-screen
/// flows (gameplay, weekly, multiplayer, result) are pushed as routes and hide
/// the nav, per App.tsx.
class SiyagShell extends ConsumerStatefulWidget {
  const SiyagShell({super.key});

  @override
  ConsumerState<SiyagShell> createState() => _SiyagShellState();
}

class _SiyagShellState extends ConsumerState<SiyagShell> {
  @override
  Widget build(BuildContext context) {
    final index = ref.watch(siyagTabProvider);
    final loc = ref.watch(localizationsProvider);
    // Bootstrap account session on launch (cold-start restore). The result is
    // consumed on the Profile tab; watching here also primes the bearer token
    // for the API client before any authenticated call.
    ref.watch(sessionControllerProvider);
    // Depend on Theme so a light/dark switch rebuilds the shell; re-key the
    // stack by brightness so the visible tab repaints immediately (the custom
    // SC-token screens don't otherwise subscribe to Theme changes).
    final brightness = Theme.of(context).brightness;
    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
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
          items: [
            SiyagNavItem(icon: Icons.home_rounded, label: loc('home')),
            SiyagNavItem(
              icon: Icons.emoji_events_rounded,
              label: loc('leaderboard'),
            ),
            SiyagNavItem(icon: Icons.person_rounded, label: loc('account')),
          ],
        ),
      ),
    );
  }
}
