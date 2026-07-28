import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/presentation/controllers/capabilities_controller.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';
import '../../../v2/presentation/controllers/wallet_controller.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';
import '../siyag_route.dart';
import '../siyag_shell.dart';
import 'siyag_multiplayer_hub_screen.dart';
import 'siyag_practice_setup_screen.dart';
import 'siyag_weekly_screen.dart';

/// Home launcher: "سياق" wordmark, weekly hero, play modes, secondary
/// launchers. Wired to live V2 profile/capabilities/weekly.
///
/// Built from the Siyaq design system — the last screen off the legacy layer.
/// Navigation targets and provider wiring are unchanged.
class SiyagHomeScreen extends ConsumerWidget {
  const SiyagHomeScreen({super.key});

  String _fmtRemaining(AppLocalizations loc, Duration? d) {
    if (d == null) return '—';
    final day = loc('uDay'), h = loc('uHour'), m = loc('uMin');
    if (d.inDays > 0) return '${d.inDays}$day ${d.inHours % 24}$h';
    return '${d.inHours}$h ${d.inMinutes % 60}$m';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final profile = ref.watch(profileControllerProvider).value;
    final caps = ref.watch(capabilitiesProvider).value;
    final lang = GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang);
    final weekly = ref.watch(weeklyChallengeProvider(lang)).value;
    final wallet = ref.watch(walletControllerProvider).value;
    final name = (profile?.label.isNotEmpty ?? false) ? profile!.label : 'س';

    return Directionality(
      textDirection: loc.direction,
      child: ListView(
        padding: const EdgeInsets.only(bottom: SiyaqSpacing.xxl),
        children: [
          // ── Header ───────────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xxl,
              SiyaqSpacing.xl,
              SiyaqSpacing.xxl,
              SiyaqSpacing.xl,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SiyaqText(
                        loc('tagline').toUpperCase(),
                        role: SiyaqTextRole.labelSmall,
                        script: SiyaqScript.mono,
                        color: c.textMuted,
                      ),
                      const SizedBox(height: SiyaqSpacing.sm),
                      SiyaqText(
                        'سياق',
                        role: SiyaqTextRole.displayLarge,
                        script: SiyaqScript.arabic,
                        header: true,
                      ),
                    ],
                  ),
                ),
                if (wallet != null) ...[
                  SiyaqChip(
                    label: '${wallet.availableBalance}',
                    icon: SiyaqIcons.coins,
                    variant: SiyaqChipVariant.accent,
                    accent: c.primary,
                    numeric: true,
                    semanticLabel:
                        '${loc('coins')}: ${wallet.availableBalance}',
                  ),
                  const SizedBox(width: SiyaqSpacing.md),
                ],
                SiyaqPressable(
                  onTap: () => ref.read(siyagTabProvider.notifier).state = 2,
                  semanticLabel: loc('account'),
                  builder: (context, state) =>
                      SiyaqAvatar(name: name, size: SiyaqAvatarSize.medium),
                ),
              ],
            ),
          ),

          // ── Identity strip ───────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xxl,
              0,
              SiyaqSpacing.xxl,
              SiyaqSpacing.xl,
            ),
            child: SiyaqSurface(
              padding: const EdgeInsets.symmetric(
                horizontal: SiyaqSpacing.lg,
                vertical: SiyaqSpacing.smd,
              ),
              radius: SiyaqRadius.md,
              semanticLabel: profile == null
                  ? loc('unknownPlayer')
                  : '${profile.gamesSolved} ${loc('gamesSolved')}, '
                        '${profile.gamesPlayed} ${loc('gamesPlayed')}',
              child: Row(
                children: [
                  SiyaqIcon.decorative(
                    SiyaqIcons.hot,
                    size: SiyaqIconSize.xs,
                    color: c.primary,
                  ),
                  const SizedBox(width: SiyaqSpacing.sm),
                  Expanded(
                    child: SiyaqText(
                      profile == null
                          ? loc('unknownPlayer')
                          : '${profile.gamesSolved} ${loc('gamesSolved')} · '
                                '${profile.gamesPlayed} ${loc('gamesPlayed')}',
                      role: SiyaqTextRole.bodySmall,
                      color: c.textSecondary,
                      maxLines: 1,
                    ),
                  ),
                  SiyaqText.numeric(
                    profile?.weeklyBestPlacement != null
                        ? '#${profile!.weeklyBestPlacement}'
                        : profile?.shortCode ?? '',
                    role: SiyaqTextRole.labelSmall,
                    color: c.textMuted,
                    maxLines: 1,
                  ),
                ],
              ),
            ),
          ),

          // ── Weekly hero ──────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xxl,
              0,
              SiyaqSpacing.xxl,
              SiyaqSpacing.lg,
            ),
            child: _WeeklyHero(
              loc: loc,
              remaining: _fmtRemaining(loc, weekly?.timeRemaining),
              subtitle: weekly == null
                  ? loc('modeWeekly')
                  : weekly.categoryLabel(loc.isArabic) +
                        (weekly.placement != null
                            ? ' · ${loc('yourPlacement')} #${weekly.placement}'
                            : ''),
              onPlay: () => Navigator.of(
                context,
              ).push(siyagRoute(const SiyagWeeklyScreen())),
            ),
          ),

          // ── Play modes ───────────────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xxl,
              0,
              SiyaqSpacing.xxl,
              SiyaqSpacing.lg,
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: _ModeTile(
                    title: loc('modeSolo'),
                    subtitle: loc('modeSoloDesc'),
                    icon: SiyaqIcons.solo,
                    color: c.info, // blue = solo (design system)
                    onTap: () => Navigator.of(
                      context,
                    ).push(siyagRoute(const SiyagPracticeSetupScreen())),
                  ),
                ),
                const SizedBox(width: SiyaqSpacing.md),
                Expanded(
                  child: _ModeTile(
                    title: loc('modeMultiplayer'),
                    subtitle: loc('modeMultiplayerDesc'),
                    icon: SiyaqIcons.social,
                    color: c.success, // green = social (design system)
                    enabled: caps?.multiplayerEnabled ?? true,
                    onTap: () => Navigator.of(
                      context,
                    ).push(siyagRoute(const SiyagMultiplayerHubScreen())),
                  ),
                ),
              ],
            ),
          ),

          // ── Secondary launchers ──────────────────────────────────────────
          Padding(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xxl,
              0,
              SiyaqSpacing.xxl,
              SiyaqSpacing.sm,
            ),
            child: Column(
              children: [
                SiyaqListRow(
                  title: loc('leaderboard'),
                  subtitle: loc('yourPlacement'),
                  leading: const SiyaqIconTile(
                    icon: SiyaqIcons.leaderboard,
                    size: SiyaqIconTileSize.small,
                  ),
                  showChevron: true,
                  onTap: () => ref.read(siyagTabProvider.notifier).state = 1,
                ),
                const SizedBox(height: SiyaqSpacing.smd),
                SiyaqListRow(
                  title: loc('account'),
                  subtitle: loc('stats'),
                  leading: const SiyaqIconTile(
                    icon: SiyaqIcons.stats,
                    size: SiyaqIconTileSize.small,
                  ),
                  showChevron: true,
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

/// The featured weekly card — elevated surface, gold frame, tokenized glow.
class _WeeklyHero extends StatelessWidget {
  const _WeeklyHero({
    required this.loc,
    required this.remaining,
    required this.subtitle,
    required this.onPlay,
  });

  final AppLocalizations loc;
  final String remaining;
  final String subtitle;
  final VoidCallback onPlay;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SiyaqSurface(
      variant: SiyaqSurfaceVariant.elevated,
      radius: SiyaqRadius.xxxl,
      accent: c.primary,
      selected: true,
      padding: const EdgeInsets.all(SiyaqSpacing.xxl),
      onTap: onPlay,
      semanticLabel:
          '${loc('modeWeekly')}, $subtitle, ${loc('timeRemaining')}: $remaining',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const SiyaqIconTile(icon: SiyaqIcons.ranked, glow: true),
              const Spacer(),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  SiyaqText(
                    loc('timeRemaining').toUpperCase(),
                    role: SiyaqTextRole.labelSmall,
                    script: SiyaqScript.mono,
                    color: c.primary,
                  ),
                  SiyaqText.numeric(
                    remaining,
                    role: SiyaqTextRole.headingSmall,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: SiyaqSpacing.lg),
          SiyaqText(
            loc('modeWeekly'),
            role: SiyaqTextRole.headingLarge,
            header: true,
          ),
          const SizedBox(height: SiyaqSpacing.xxxs),
          SiyaqText(
            subtitle,
            role: SiyaqTextRole.bodyMedium,
            color: c.textMuted,
            maxLines: 2,
          ),
          const SizedBox(height: SiyaqSpacing.xl),
          SiyaqButton(
            label: loc('startWeekly'),
            icon: SiyaqIcons.play,
            fullWidth: true,
            onPressed: onPlay,
          ),
        ],
      ),
    );
  }
}

/// A square play-mode tile: tinted icon, title, description.
class _ModeTile extends StatelessWidget {
  const _ModeTile({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.color,
    required this.onTap,
    this.enabled = true,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final Color color;
  final VoidCallback onTap;
  final bool enabled;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return SiyaqSurface(
      radius: SiyaqRadius.xxxl,
      padding: const EdgeInsets.all(SiyaqSpacing.xl),
      onTap: enabled ? onTap : null,
      disabled: !enabled,
      semanticLabel: '$title, $subtitle',
      constraints: const BoxConstraints(minHeight: 168),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          SiyaqIconTile(
            icon: icon,
            size: SiyaqIconTileSize.small,
            accent: color,
            tinted: true,
          ),
          const SizedBox(height: SiyaqSpacing.xl),
          SiyaqText(
            title,
            role: SiyaqTextRole.bodyLarge,
            weight: FontWeight.w600,
            color: enabled ? c.textPrimary : c.textDisabled,
            maxLines: 2,
          ),
          const SizedBox(height: SiyaqSpacing.xxxs),
          SiyaqText(
            subtitle,
            role: SiyaqTextRole.bodySmall,
            color: c.textMuted,
            maxLines: 2,
          ),
        ],
      ),
    );
  }
}
