import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/weekly.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';
import '../siyag_route.dart';
import 'siyag_result_screen.dart';
import 'siyag_weekly_game_screen.dart';

/// Weekly challenge overview: hero with countdown, week progress, meta stats and
/// the start/resume action. Wired to the live weekly challenge.
///
/// Built from the Siyaq design system — no screen-local cards, meta tiles, error
/// state or text styles. Providers, navigation and the start/resume contract are
/// unchanged from the pre-migration implementation.
/// Weekly vocabulary language. Seeded from the app language, then the player's
/// choice for the session — the weekly challenge exists in both languages and
/// the UI locale should not decide which one they play.
final weeklyLangProvider = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);

class SiyagWeeklyScreen extends ConsumerWidget {
  const SiyagWeeklyScreen({super.key});

  /// A week, used to express `timeRemaining` as elapsed progress.
  static const _week = Duration(days: 7);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = ref.watch(weeklyLangProvider);
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
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  0,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.md,
                ),
                child: SiyaqSegmentedControl<GameplayLanguage>(
                  value: lang,
                  onChanged: (l) =>
                      ref.read(weeklyLangProvider.notifier).state = l,
                  segments: [
                    for (final l in GameplayLanguage.values)
                      SiyaqSegment(
                        value: l,
                        label: loc(l.labelKey),
                        semanticLabel:
                            '${loc('gameLanguage')}: ${loc(l.labelKey)}',
                      ),
                  ],
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion.summaryIn,
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

  /// Lifecycle of the *challenge itself* — whether this week is still open.
  static String stateLabel(AppLocalizations loc, WeeklyState s) => switch (s) {
    WeeklyState.active => loc('inProgress'),
    WeeklyState.completed => loc('completed'),
    WeeklyState.notStarted => loc('notStarted'),
  };

  /// What **this player** has done with the challenge.
  ///
  /// [WeeklyState] is mapped from the server's challenge `status`, so it reads
  /// "active" for everyone the moment the week opens. Labelling that as the
  /// player's participation told a first-time visitor they were already playing
  /// (device: chip "قيد اللعب" beside a CTA reading "Start challenge").
  ///
  /// Derived from the same two signals the CTA trusts, so the card and the
  /// button can never disagree: a finished run has a placement, an unfinished
  /// one has a locally stored run id. (`WeeklyChallenge.participated` would be
  /// the right source, but the API does not populate it.)
  static String participationLabel(
    AppLocalizations loc, {
    required bool hasPlacement,
    required bool hasActiveRun,
  }) {
    if (hasPlacement) return loc('completed');
    if (hasActiveRun) return loc('inProgress');
    return loc('notStarted');
  }

  /// Fraction of the week **still remaining**, from the server's
  /// `timeRemaining`. Starts at 1.0 and drains to 0.0 as the week expires.
  ///
  /// This used to return the fraction *elapsed* while the bar was labelled
  /// "time remaining", so the meter filled up as the player ran out of time —
  /// the inverse of what it claimed. The fix is the value, not the fill
  /// direction: an expired week must read empty, and an a11y label built from
  /// this number must be able to say "0% remaining" truthfully.
  static double? weekProgress(Duration? remaining) {
    if (remaining == null) return null;
    final left = remaining.inSeconds.clamp(0, _week.inSeconds);
    return left / _week.inSeconds;
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

  /// "6 days, 21 hours, 10 minutes" from the same units the countdown shows.
  String _spokenRemaining(Duration? d) {
    if (d == null) return loc('noRankYet');
    if (d <= Duration.zero) return loc('weeklyExpired');
    return _countdown(d).map((e) => '${int.parse(e.$1)} ${e.$2}').join(', ');
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

    // Attempt count and best rank live on the *run*, not on the weekly
    // overview, so they can only be shown once a run is loaded. The persisted
    // run id is what tells us a run exists at all without starting one.
    final run = ref.watch(weeklyRunControllerProvider).run;
    final hasActiveRun = ref.watch(activeWeeklyRunIdProvider) != null;

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
                        // States the actual time left. "Time remaining: 62%"
                        // tells a screen-reader user nothing they can act on.
                        semanticLabel:
                            '${loc('timeRemaining')}: '
                            '${_spokenRemaining(challenge.timeRemaining)}',
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
                  Builder(
                    builder: (context) {
                      final participation =
                          SiyagWeeklyScreen.participationLabel(
                            loc,
                            hasPlacement: challenge.placement != null,
                            hasActiveRun: hasActiveRun,
                          );
                      return SiyaqStatCard(
                        value: participation,
                        label: loc('participation'),
                        numeric: false,
                        accent: challenge.placement != null ? c.success : null,
                        semanticLabel:
                            '${loc('participation')}: $participation',
                      );
                    },
                  ),
                ],
              ),

              // ── Player progress (only what the run actually carries) ───────
              if (run != null) ...[
                const SizedBox(height: SiyaqSpacing.sm),
                SiyaqStatGrid(
                  columns: 3,
                  minCellWidth: 88,
                  children: [
                    SiyaqStatCard(
                      value: '${run.attempts}',
                      label: loc('guessHistory'),
                      semanticLabel: '${loc('guessHistory')}: ${run.attempts}',
                    ),
                    SiyaqStatCard(
                      value: run.bestGuess != null
                          ? '#${run.bestGuess!.rank}'
                          : null,
                      label: loc('bestRankLabel'),
                      accent: run.bestGuess != null ? c.primary : null,
                      semanticLabel: run.bestGuess != null
                          ? '${loc('bestRankLabel')}: ${run.bestGuess!.rank}'
                          : loc('bestRankLabel'),
                    ),
                    SiyaqStatCard(
                      value: run.bestGuess?.word,
                      label: loc('bestGuess'),
                      numeric: false,
                      // Game content: the guess follows the run's language.
                      semanticLabel:
                          '${loc('bestGuess')}: '
                          '${run.bestGuess?.word ?? loc('noRankYet')}',
                    ),
                  ],
                ),
              ],
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
          child: _PrimaryAction(
            loc: loc,
            completed: completed,
            hasActiveRun: hasActiveRun,
            canViewResult: run != null,
            onStart: () => _start(context, ref),
            onViewResult: run == null
                ? null
                : () => Navigator.of(context).push(
                    siyagRoute(
                      SiyagResultScreen(
                        secretWord: run.secretWord ?? '',
                        attempts: run.attempts,
                        hintsUsed: run.hintsUsed,
                        elapsed: run.elapsed,
                      ),
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}

/// The weekly primary action, which is not always "start".
///
/// Three distinct states the old single button collapsed into one:
/// nothing started yet, a run already in flight, and a finished week. The
/// finished case only offers a result when a run is actually loaded — the weekly
/// *overview* endpoint returns no attempt count, best rank or secret word, so
/// there is nothing to show a returning player whose run is not in memory. That
/// gap is reported rather than papered over with a dead button.
class _PrimaryAction extends StatelessWidget {
  const _PrimaryAction({
    required this.loc,
    required this.completed,
    required this.hasActiveRun,
    required this.canViewResult,
    required this.onStart,
    required this.onViewResult,
  });

  final AppLocalizations loc;
  final bool completed;
  final bool hasActiveRun;
  final bool canViewResult;
  final VoidCallback onStart;
  final VoidCallback? onViewResult;

  @override
  Widget build(BuildContext context) {
    if (completed) {
      // Nothing to open and nothing to replay: the completed banner above
      // already states the outcome, so no action is better than a dead one.
      if (!canViewResult) return const SizedBox.shrink();
      return SiyaqButton(
        label: loc('viewResult'),
        icon: SiyaqIcons.trophy,
        fullWidth: true,
        onPressed: onViewResult,
      );
    }
    return SiyaqButton(
      label: hasActiveRun ? loc('resumeWeekly') : loc('startWeekly'),
      icon: SiyaqIcons.play,
      fullWidth: true,
      onPressed: onStart,
    );
  }
}
