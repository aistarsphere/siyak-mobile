import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/weekly.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';
import '../siyag_route.dart';
import 'siyag_weekly_game_screen.dart';

/// Weekly challenge overview: hero with countdown, week progress, meta stats and
/// the start/resume action. Wired to the live weekly challenge.
///
/// Built from the Siyaq design system — no screen-local cards, meta tiles, error
/// state or text styles. Providers, navigation and the start/resume contract are
/// unchanged from the pre-migration implementation.
class SiyagWeeklyScreen extends ConsumerWidget {
  const SiyagWeeklyScreen({super.key});

  /// A week, used to express `timeRemaining` as elapsed progress.
  static const _week = Duration(days: 7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang);
    final async = ref.watch(weeklyChallengeProvider(lang));

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                // Kicker only: the hero card below carries the heading, which is
                // how the pre-migration top bar was composed.
                kicker: loc('modeWeekly'),
                accent: context.colors.primary,
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
                child: AnimatedSwitcher(
                  duration: SiyaqMotion.summaryIn,
                  child: async.when(
                    loading: () => SiyaqLoader(semanticLabel: loc('loading')),
                    error: (e, _) => SiyaqEmptyState.error(
                      title: loc('weeklyLoadError'),
                      body: loc.errorMessage(e),
                      actionLabel: loc('retry'),
                      onAction: () =>
                          ref.invalidate(weeklyChallengeProvider(lang)),
                    ),
                    data: (c) => _Overview(challenge: c, lang: lang, loc: loc),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static String stateLabel(AppLocalizations loc, WeeklyState s) => switch (s) {
    WeeklyState.active => loc('inProgress'),
    WeeklyState.completed => loc('completed'),
    WeeklyState.notStarted => loc('notStarted'),
  };

  /// Fraction of the week already elapsed, from the server's `timeRemaining`.
  /// `null` when the server did not send a remaining duration.
  static double? weekProgress(Duration? remaining) {
    if (remaining == null) return null;
    final left = remaining.inSeconds.clamp(0, _week.inSeconds);
    return 1 - (left / _week.inSeconds);
  }
}

class _Overview extends ConsumerWidget {
  const _Overview({
    required this.challenge,
    required this.lang,
    required this.loc,
  });

  final WeeklyChallenge challenge;
  final GameplayLanguage lang;
  final AppLocalizations loc;

  List<(String, String)> _countdown(Duration? d) {
    final day = loc('uDayFull'), hr = loc('uHourFull'), min = loc('uMinFull');
    if (d == null) return [('--', day), ('--', hr), ('--', min)];
    return [
      (d.inDays.toString().padLeft(2, '0'), day),
      ((d.inHours % 24).toString().padLeft(2, '0'), hr),
      ((d.inMinutes % 60).toString().padLeft(2, '0'), min),
    ];
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    await ref.read(weeklyRunControllerProvider.notifier).start(lang);
    if (context.mounted) {
      Navigator.of(
        context,
      ).pushReplacement(siyagRoute(const SiyagWeeklyGameScreen()));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final completed = challenge.state == WeeklyState.completed;
    final progress = SiyagWeeklyScreen.weekProgress(challenge.timeRemaining);

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(
              SiyaqSpacing.xl,
              SiyaqSpacing.sm,
              SiyaqSpacing.xl,
              SiyaqSpacing.xxl,
            ),
            children: [
              // ── Hero ────────────────────────────────────────────────────────
              SiyaqSurface(
                variant: SiyaqSurfaceVariant.accent,
                radius: SiyaqRadius.xxxl,
                padding: const EdgeInsets.all(SiyaqSpacing.xxl),
                child: Column(
                  children: [
                    // Replaces the old off-canvas blurred circle with a
                    // tokenized glow, so it reads the same in both themes.
                    const SiyaqIconTile(icon: SiyaqIcons.ranked, glow: true),
                    const SizedBox(height: SiyaqSpacing.lg),
                    SiyaqText(
                      loc('modeWeekly'),
                      role: SiyaqTextRole.displaySmall,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: SiyaqSpacing.xs),
                    SiyaqText(
                      loc('modeWeeklyDesc'),
                      role: SiyaqTextRole.bodyMedium,
                      color: c.textMuted,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: SiyaqSpacing.xl),
                    // Countdown reuses the stat card — same shape (figure over
                    // caption), so it needs no separate component.
                    SiyaqStatGrid(
                      columns: 3,
                      minCellWidth: 60,
                      children: [
                        for (final (value, unit) in _countdown(
                          challenge.timeRemaining,
                        ))
                          SiyaqStatCard(
                            value: value,
                            label: unit,
                            semanticLabel: '$value $unit',
                          ),
                      ],
                    ),
                    if (progress != null) ...[
                      const SizedBox(height: SiyaqSpacing.xl),
                      SiyaqProgressBar(
                        value: progress,
                        label: loc('timeRemaining'),
                        semanticLabel: loc('timeRemaining'),
                      ),
                    ],
                  ],
                ),
              ),

              // ── Completed banner ───────────────────────────────────────────
              if (completed) ...[
                const SizedBox(height: SiyaqSpacing.lg),
                SiyaqTintedSurface(
                  tone: SiyaqTone.success,
                  child: Row(
                    children: [
                      SiyaqIcon.decorative(
                        SiyaqIcons.success,
                        size: SiyaqIconSize.md,
                        color: c.success,
                      ),
                      const SizedBox(width: SiyaqSpacing.sm),
                      Expanded(
                        child: SiyaqText(
                          loc('completed'),
                          role: SiyaqTextRole.bodyMedium,
                          color: c.success,
                        ),
                      ),
                    ],
                  ),
                ),
              ],

              // ── Meta stats ─────────────────────────────────────────────────
              const SizedBox(height: SiyaqSpacing.lg),
              SiyaqStatGrid(
                columns: 3,
                minCellWidth: 88,
                children: [
                  SiyaqStatCard(
                    value: challenge.categoryLabel(loc.isArabic),
                    label: loc('category'),
                    numeric: false,
                    semanticLabel:
                        '${loc('category')}: '
                        '${challenge.categoryLabel(loc.isArabic)}',
                  ),
                  SiyaqStatCard(
                    value: challenge.placement != null
                        ? '#${challenge.placement}'
                        : null,
                    label: loc('yourPlacement'),
                    accent: challenge.placement != null ? c.primary : null,
                    semanticLabel: challenge.placement != null
                        ? '${loc('yourPlacement')}: ${challenge.placement}'
                        : loc('yourPlacement'),
                  ),
                  SiyaqStatCard(
                    value: SiyagWeeklyScreen.stateLabel(loc, challenge.state),
                    label: loc('participation'),
                    numeric: false,
                    accent: completed ? c.success : null,
                    semanticLabel:
                        '${loc('participation')}: '
                        '${SiyagWeeklyScreen.stateLabel(loc, challenge.state)}',
                  ),
                ],
              ),
            ],
          ),
        ),

        // ── Primary action (pinned) ──────────────────────────────────────────
        Padding(
          padding: const EdgeInsets.fromLTRB(
            SiyaqSpacing.xl,
            SiyaqSpacing.sm,
            SiyaqSpacing.xl,
            SiyaqSpacing.xxl,
          ),
          child: SiyaqButton(
            label: challenge.participated
                ? loc('resumeWeekly')
                : loc('startWeekly'),
            icon: SiyaqIcons.play,
            fullWidth: true,
            onPressed: () => _start(context, ref),
          ),
        ),
      ],
    );
  }
}
