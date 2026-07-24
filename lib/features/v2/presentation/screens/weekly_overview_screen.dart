import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/backend_offline_view.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../../domain/entities/gameplay_language.dart';
import '../../domain/entities/hint_mode.dart';
import '../../domain/entities/weekly.dart';
import '../controllers/capabilities_controller.dart';
import '../controllers/weekly_controller.dart';
import '../widgets/gameplay_language_selector.dart';
import '../widgets/hint_mode_selector.dart';
import '../widgets/v2_scaffold.dart';
import 'leaderboard_screen.dart';
import 'weekly_game_screen.dart';

final _weeklyLangProvider = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final _weeklyHintModeProvider = StateProvider<HintMode>(
  (ref) => HintMode.standard,
);

class WeeklyOverviewScreen extends ConsumerWidget {
  const WeeklyOverviewScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = ref.watch(_weeklyLangProvider);
    final challenge = ref.watch(weeklyChallengeProvider(lang));
    final adaptive =
        ref.watch(capabilitiesProvider).value?.adaptiveHintsEnabled ?? false;

    return V2Scaffold(
      title: loc('weekly'),
      child: challenge.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (e, _) => BackendOfflineView(
          onRetry: () => ref.invalidate(weeklyChallengeProvider(lang)),
        ),
        data: (c) => ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
          children: [
            _WeekHeaderCard(challenge: c, loc: loc),
            const SizedBox(height: 16),
            _sectionLabel(loc('chooseGameLang')),
            const SizedBox(height: 8),
            GameplayLanguageSelector(
              value: lang,
              onChanged: (l) =>
                  ref.read(_weeklyLangProvider.notifier).state = l,
            ),
            const SizedBox(height: 16),
            _sectionLabel(loc('hintMode')),
            const SizedBox(height: 8),
            HintModeSelector(
              value: ref.watch(_weeklyHintModeProvider),
              adaptiveEnabled: adaptive,
              onChanged: (m) =>
                  ref.read(_weeklyHintModeProvider.notifier).state = m,
            ),
            const SizedBox(height: 24),
            GlowButton(
              label: c.state == WeeklyState.active && c.participated
                  ? loc('resumeWeekly')
                  : loc('startWeekly'),
              icon: Icons.play_arrow,
              onTap: () async {
                await ref
                    .read(weeklyRunControllerProvider.notifier)
                    .start(lang, hintMode: ref.read(_weeklyHintModeProvider));
                if (context.mounted) {
                  Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const WeeklyGameScreen()),
                  );
                }
              },
            ),
            const SizedBox(height: 8),
            GlassButton(
              label: loc('leaderboard'),
              icon: Icons.leaderboard,
              onTap: () => Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => LeaderboardScreen(weekId: c.weekId),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _sectionLabel(String t) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Text(
      t,
      style: AppTypography.labelMd.copyWith(
        color: AppColors.onSurface.withValues(alpha: 0.8),
      ),
    ),
  );
}

class _WeekHeaderCard extends StatelessWidget {
  const _WeekHeaderCard({required this.challenge, required this.loc});

  final WeeklyChallenge challenge;
  final dynamic loc;

  String _stateLabel() => switch (challenge.state) {
    WeeklyState.active => loc('inProgress'),
    WeeklyState.completed => loc('completed'),
    WeeklyState.notStarted => loc('notStarted'),
  };

  String _remaining() {
    final d = challenge.timeRemaining;
    if (d == null) return '—';
    if (d.inDays > 0) return '${d.inDays}d ${d.inHours % 24}h';
    return '${d.inHours}h ${d.inMinutes % 60}m';
  }

  @override
  Widget build(BuildContext context) {
    final arabic = Directionality.of(context) == TextDirection.rtl;
    return GlassPanel(
      opacity: 0.2,
      borderRadius: BorderRadius.circular(16),
      border: Border.all(color: AppColors.primary.withValues(alpha: 0.25)),
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.calendar_today,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                '${loc('weeklyThisWeek')} · ${challenge.weekId}',
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            challenge.categoryLabel(arabic),
            style: AppTypography.displaySm.copyWith(
              color: AppColors.primary,
              shadows: AppTypography.amberTextGlow,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _stat(loc('participation'), _stateLabel())),
              Expanded(child: _stat(loc('timeRemaining'), _remaining())),
              if (challenge.placement != null)
                Expanded(
                  child: _stat(loc('yourPlacement'), '#${challenge.placement}'),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _stat(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTypography.labelXs.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
      const SizedBox(height: 2),
      Text(
        value,
        style: AppTypography.headlineMobile.copyWith(
          color: AppColors.onSurface,
        ),
      ),
    ],
  );
}
