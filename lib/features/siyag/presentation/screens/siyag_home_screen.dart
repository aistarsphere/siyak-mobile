import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/presentation/controllers/capabilities_controller.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';
import '../siyag_route.dart';
import '../siyag_shell.dart';
import 'siyag_multiplayer_hub_screen.dart';
import 'siyag_practice_setup_screen.dart';
import 'siyag_weekly_screen.dart';

/// Home launcher (home.tsx): big "سياق" wordmark, weekly hero, play modes,
/// secondary launchers. RTL. Wired to live V2 profile/capabilities/weekly.
class SiyagHomeScreen extends ConsumerWidget {
  const SiyagHomeScreen({super.key});

  String _fmtRemaining(Duration? d) {
    if (d == null) return '—';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).value;
    final caps = ref.watch(capabilitiesProvider).value;
    final lang = GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang);
    final weekly = ref.watch(weeklyChallengeProvider(lang)).value;
    final letter = (profile?.label.isNotEmpty ?? false)
        ? profile!.label.characters.first
        : 'س';

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.only(bottom: 24),
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 20),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Kicker('Semantic Word Game'),
                      const SizedBox(height: 8),
                      Text(
                        'سياق',
                        style: ST.ar(54, weight: FontWeight.w700, height: 1),
                      ),
                    ],
                  ),
                ),
                SiyagTap(
                  onTap: () => ref.read(siyagTabProvider.notifier).state = 2,
                  child: SiyagAvatar(letter: letter, size: 44, active: true),
                ),
              ],
            ),
          ),

          // Identity strip (real profile: code + games)
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: SC.surface,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                children: [
                  Icon(
                    Icons.local_fire_department_rounded,
                    size: 15,
                    color: SC.coral,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    profile == null
                        ? 'لاعب مجهول'
                        : '${profile.gamesSolved} حلول · ${profile.gamesPlayed} ألعاب',
                    style: ST.ar(13, color: SC.textDim),
                  ),
                  const Spacer(),
                  Text(
                    profile?.weeklyBestPlacement != null
                        ? 'RANK #${profile!.weeklyBestPlacement}'
                        : profile?.shortCode ?? '',
                    style: ST.mono(12, color: SC.textMute),
                  ),
                ],
              ),
            ),
          ),

          // Weekly hero
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: SiyagTap(
              scale: 0.98,
              onTap: () => Navigator.of(
                context,
              ).push(siyagRoute(const SiyagWeeklyScreen())),
              child: _WeeklyHeroCard(
                remaining: _fmtRemaining(weekly?.timeRemaining),
                subtitle: weekly == null
                    ? 'التحدي الأسبوعي'
                    : weekly.categoryLabel(true) +
                          (weekly.placement != null
                              ? ' · مركزك #${weekly.placement}'
                              : ''),
                cta: 'ابدأ التحدي الأسبوعي',
              ),
            ),
          ),

          // Play modes
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
            child: Row(
              children: [
                Expanded(
                  child: _ModeTile(
                    ar: 'تدريب حر',
                    en: 'Solo Practice',
                    icon: Icons.bolt_rounded,
                    color: SC.cyan,
                    onTap: () => Navigator.of(
                      context,
                    ).push(siyagRoute(const SiyagPracticeSetupScreen())),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: _ModeTile(
                    ar: 'العب مع الأصدقاء',
                    en: 'Multiplayer',
                    icon: Icons.groups_rounded,
                    color: SC.emerald,
                    enabled: caps?.multiplayerEnabled ?? true,
                    onTap: () => Navigator.of(
                      context,
                    ).push(siyagRoute(const SiyagMultiplayerHubScreen())),
                  ),
                ),
              ],
            ),
          ),

          // Secondary launchers
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
            child: Column(
              children: [
                _Launcher(
                  label: 'المتصدرون',
                  en: 'Leaderboard',
                  icon: Icons.emoji_events_rounded,
                  onTap: () => ref.read(siyagTabProvider.notifier).state = 1,
                ),
                const SizedBox(height: 10),
                _Launcher(
                  label: 'الإحصائيات والملف',
                  en: 'Statistics · Profile',
                  icon: Icons.insights_rounded,
                  onTap: () => ref.read(siyagTabProvider.notifier).state = 2,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _WeeklyHeroCard extends StatelessWidget {
  const _WeeklyHeroCard({
    required this.remaining,
    required this.subtitle,
    required this.cta,
  });

  final String remaining;
  final String subtitle;
  final String cta;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: Container(
        decoration: BoxDecoration(
          // Elevated surface + stronger gold border → reads as the primary
          // (featured) action without becoming a solid-gold card.
          color: SC.surfaceHi,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(
            color: SC.coral.withValues(alpha: 0.38),
            width: 1.5,
          ),
        ),
        child: Stack(
          children: [
            PositionedDirectional(
              top: -40,
              end: -40,
              child: Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: SC.coral.withValues(alpha: 0.14),
                  boxShadow: [
                    BoxShadow(
                      color: SC.coral.withValues(alpha: 0.14),
                      blurRadius: 60,
                      spreadRadius: 20,
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: SC.coral,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Icon(
                          Icons.emoji_events_rounded,
                          size: 20,
                          color: SC.onGold,
                        ),
                      ),
                      const Spacer(),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.end,
                        children: [
                          Kicker('Ends in', color: SC.coral),
                          Text(remaining, style: ST.mono(18)),
                        ],
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'التحدي الأسبوعي',
                    style: ST.ar(24, weight: FontWeight.w700, height: 1.1),
                  ),
                  const SizedBox(height: 4),
                  Text(subtitle, style: ST.ar(14, color: SC.textMute)),
                  const SizedBox(height: 20),
                  SiyagPrimaryButton(
                    label: cta,
                    icon: Icons.play_arrow_rounded,
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.ar,
    required this.en,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String ar;
  final String en;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    return SiyagTap(
      onTap: enabled ? onTap : null,
      child: Opacity(
        opacity: enabled ? 1 : 0.5,
        child: Container(
          height: 140,
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(24),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Icon(icon, size: 19, color: color),
              ),
              const Spacer(),
              Text(ar, style: ST.ar(16, weight: FontWeight.w600)),
              const SizedBox(height: 4),
              Text(en, style: ST.mono(10, color: SC.textMute)),
            ],
          ),
        ),
      ),
    );
  }
}

class _Launcher extends StatelessWidget {
  const _Launcher({
    required this.label,
    required this.en,
    required this.icon,
    required this.onTap,
  });

  final String label;
  final String en;
  final IconData icon;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return SiyagTap(
      onTap: onTap,
      scale: 0.98,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SC.surfaceHi,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(icon, size: 16, color: SC.textDim),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: ST.ar(15, weight: FontWeight.w500)),
                  Text(en, style: ST.mono(10, color: SC.textMute)),
                ],
              ),
            ),
            Icon(Icons.chevron_left_rounded, size: 18, color: SC.textFaint),
          ],
        ),
      ),
    );
  }
}
