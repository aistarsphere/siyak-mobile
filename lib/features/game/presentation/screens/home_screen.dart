import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/network/api_error.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/presentation/controllers/capabilities_controller.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';
import '../../../v2/presentation/screens/multiplayer_home_screen.dart';
import '../../../v2/presentation/screens/weekly_overview_screen.dart';
import '../../../v2/presentation/widgets/gameplay_language_selector.dart';
import '../../../v2/presentation/widgets/mode_card.dart';
import '../../../v2/presentation/widgets/profile_setup_sheet.dart';
import '../../data/models/modes_info.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/providers.dart';
import '../controllers/stats_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/backend_offline_view.dart';
import '../widgets/glow_button.dart';
import '../widgets/pressable.dart';
import '../widgets/selector_chip.dart';
import '../widgets/top_app_bar.dart';
import 'settings_screen.dart';
import 'shell_screen.dart';

/// Selected solo category / difficulty / gameplay language.
final selectedModeProvider = StateProvider<String?>((ref) => null);
final selectedDifficultyProvider = StateProvider<String>((ref) => 'medium');
final soloLanguageProvider = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final soloExpandedProvider = StateProvider<bool>((ref) => true);

const kDifficulties = <String>['easy', 'medium', 'hard'];
String difficultyLabelKey(String d) => switch (d) {
  'easy' => 'diffEasy',
  'hard' => 'diffHard',
  _ => 'diffMedium',
};

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  bool _starting = false;
  bool _promptedName = false;

  @override
  void initState() {
    super.initState();
    // Offer optional display-name setup once, after first-run registration.
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybePromptName());
  }

  void _maybePromptName() {
    if (_promptedName) return;
    final notifier = ref.read(profileControllerProvider.notifier);
    if (notifier.needsNameSetup && mounted) {
      _promptedName = true;
      ProfileSetupSheet.show(context);
    }
  }

  Future<void> _startSolo({bool resume = false}) async {
    if (_starting) return;
    final loc = ref.read(localizationsProvider);
    final lang = ref.read(soloLanguageProvider);
    final modes = ref.read(modesByLanguageProvider(lang.code)).value;
    if (modes == null || modes.playable.isEmpty) return;
    final categoryCode =
        ref.read(selectedModeProvider) ?? modes.playable.first.code;
    final category = modes.playable.firstWhere(
      (c) => c.code == categoryCode,
      orElse: () => modes.playable.first,
    );
    final difficulty = ref.read(selectedDifficultyProvider);
    setState(() => _starting = true);
    try {
      final controller = ref.read(gameControllerProvider.notifier);
      var ok = true;
      if (resume) ok = await controller.resumeSavedGame();
      if (!resume || !ok) {
        await controller.startNewGame(
          language: lang.code,
          category: category.code,
          categoryLabel: category.labelFor(lang.code),
          difficulty: difficulty,
        );
      }
      if (mounted) ref.read(shellTabProvider.notifier).state = 1;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(loc.errorMessage(e))));
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    ref.watch(profileControllerProvider); // ensure first-run registration
    final lang = ref.watch(soloLanguageProvider);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    final stats = ref.watch(statsProvider);
    final activeGame = ref.watch(
      gameControllerProvider.select((s) => s.hasGame && !s.solved),
    );
    final canResume =
        activeGame || ref.read(gameControllerProvider.notifier).hasSavedGame;

    return Column(
      children: [
        SiyaqTopBar(
          title: loc('appTitle'),
          onLanguageTap: () =>
              ref.read(appSettingsProvider.notifier).toggleLang(),
          trailing: Pressable(
            onTap: () => ref.read(shellTabProvider.notifier).state = 2,
            child: const Icon(
              Icons.leaderboard_outlined,
              size: 20,
              color: AppColors.onSurfaceVariant,
            ),
          ),
        ),
        Expanded(
          child: modes.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (e, _) => ApiException.isOffline(e)
                ? BackendOfflineView(
                    onRetry: () =>
                        ref.invalidate(modesByLanguageProvider(lang.code)),
                    onChangeServer: () {
                      ref.read(openDevServerProvider.notifier).state = true;
                      ref.read(shellTabProvider.notifier).state = 2;
                    },
                  )
                : _ErrorRetry(
                    message: loc.errorMessage(e),
                    onRetry: () =>
                        ref.invalidate(modesByLanguageProvider(lang.code)),
                  ),
            data: (info) => _HomeBody(
              info: info,
              startBusy: _starting,
              canResume: canResume,
              onStartSolo: () => _startSolo(),
              onResumeSolo: () => _startSolo(resume: true),
              statsAttempts: stats.totalAttempts,
              statsBest: stats.bestRank,
            ),
          ),
        ),
      ],
    );
  }
}

class _ErrorRetry extends ConsumerWidget {
  const _ErrorRetry({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(
              message,
              textAlign: TextAlign.center,
              style: AppTypography.bodySm.copyWith(color: AppColors.error),
            ),
            const SizedBox(height: 16),
            GlowButton(
              label: loc('retry'),
              icon: Icons.refresh,
              onTap: onRetry,
            ),
          ],
        ),
      ),
    );
  }
}

class _HomeBody extends ConsumerWidget {
  const _HomeBody({
    required this.info,
    required this.startBusy,
    required this.canResume,
    required this.onStartSolo,
    required this.onResumeSolo,
    required this.statsAttempts,
    required this.statsBest,
  });

  final ModesInfo info;
  final bool startBusy;
  final bool canResume;
  final VoidCallback onStartSolo;
  final VoidCallback onResumeSolo;
  final int statsAttempts;
  final int statsBest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final caps = ref.watch(capabilitiesProvider);
    final v2 = caps.value;
    final soloExpanded = ref.watch(soloExpandedProvider);
    final profile = ref.watch(profileControllerProvider).value;

    // While capabilities are still loading, keep the V2 cards tappable (the
    // target screen shows its own state); only mark "coming soon" once we know
    // the feature is unavailable.
    final capsLoading = caps.isLoading;
    final weeklyEnabled = capsLoading || (v2?.weeklyEnabled ?? false);
    final multiEnabled = capsLoading || (v2?.multiplayerEnabled ?? false);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      children: [
        const SizedBox(height: 8),
        const Center(child: AppLogo(size: 92)),
        const SizedBox(height: 12),
        Center(
          child: Text(
            loc('appTitle'),
            style: AppTypography.displaySm.copyWith(
              color: AppColors.primary,
              shadows: AppTypography.amberTextGlow,
            ),
          ),
        ),
        if (profile != null) ...[
          const SizedBox(height: 4),
          Center(
            child: Text(
              '${loc('yourCode')}: ${profile.label}',
              style: AppTypography.labelMd.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
        ],
        const SizedBox(height: 20),

        // ── Mode: Solo ───────────────────────────────────────────────
        ModeCard(
          index: 0,
          icon: Icons.person_outline,
          title: loc('modeSolo'),
          description: loc('modeSoloDesc'),
          highlight: soloExpanded,
          status: canResume ? loc('resumeGame') : null,
          trailing: Icon(
            soloExpanded ? Icons.expand_less : Icons.expand_more,
            color: AppColors.onSurfaceVariant,
          ),
          onTap: () =>
              ref.read(soloExpandedProvider.notifier).state = !soloExpanded,
        ),
        AnimatedCrossFade(
          firstChild: const SizedBox(width: double.infinity),
          secondChild: _SoloConfig(
            info: info,
            startBusy: startBusy,
            canResume: canResume,
            onStartSolo: onStartSolo,
            onResumeSolo: onResumeSolo,
          ),
          crossFadeState: soloExpanded
              ? CrossFadeState.showSecond
              : CrossFadeState.showFirst,
          duration: const Duration(milliseconds: 250),
        ),
        const SizedBox(height: 12),

        // ── Mode: Weekly ─────────────────────────────────────────────
        ModeCard(
          index: 1,
          icon: Icons.calendar_today,
          title: loc('modeWeekly'),
          description: loc('modeWeeklyDesc'),
          enabled: weeklyEnabled,
          status: weeklyEnabled ? null : loc('comingSoon'),
          statusColor: AppColors.onSurfaceVariant,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const WeeklyOverviewScreen()),
          ),
        ),
        const SizedBox(height: 12),

        // ── Mode: Multiplayer ────────────────────────────────────────
        ModeCard(
          index: 2,
          icon: Icons.groups_outlined,
          title: loc('modeMultiplayer'),
          description: loc('modeMultiplayerDesc'),
          enabled: multiEnabled,
          status: multiEnabled ? null : loc('comingSoon'),
          statusColor: AppColors.onSurfaceVariant,
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(builder: (_) => const MultiplayerHomeScreen()),
          ),
        ),
        const SizedBox(height: 16),

        Row(
          children: [
            Expanded(
              child: _StatCard(
                label: loc('prevAttempts'),
                value: '$statsAttempts',
                icon: Icons.history,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _StatCard(
                label: loc('bestScore'),
                value: statsBest == 0 ? '—' : '#$statsBest',
                icon: Icons.workspace_premium,
                amber: true,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The V1 solo configuration, now nested under the Solo mode card. Gameplay
/// language is chosen here and then locked once the game starts.
class _SoloConfig extends ConsumerWidget {
  const _SoloConfig({
    required this.info,
    required this.startBusy,
    required this.canResume,
    required this.onStartSolo,
    required this.onResumeSolo,
  });

  final ModesInfo info;
  final bool startBusy;
  final bool canResume;
  final VoidCallback onStartSolo;
  final VoidCallback onResumeSolo;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final soloLang = ref.watch(soloLanguageProvider);
    final categories = info.playable;
    final selectedMode =
        ref.watch(selectedModeProvider) ??
        (categories.isNotEmpty ? categories.first.code : '');
    final selectedDifficulty = ref.watch(selectedDifficultyProvider);

    return Padding(
      padding: const EdgeInsets.only(top: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(loc('chooseGameLang'), Icons.translate),
          const SizedBox(height: 8),
          GameplayLanguageSelector(
            value: soloLang,
            onChanged: (l) {
              ref.read(soloLanguageProvider.notifier).state = l;
              ref.read(selectedModeProvider.notifier).state = null;
            },
          ),
          const SizedBox(height: 16),
          _label(loc('category'), Icons.category_outlined),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                return SelectorChip(
                  label: c.labelFor(soloLang.code),
                  selected: c.code == selectedMode,
                  onTap: () =>
                      ref.read(selectedModeProvider.notifier).state = c.code,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          _label(loc('difficulty'), Icons.speed),
          const SizedBox(height: 8),
          SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: kDifficulties.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = kDifficulties[i];
                return SelectorChip(
                  label: loc(difficultyLabelKey(d)),
                  selected: d == selectedDifficulty,
                  accent: ChipAccent.secondary,
                  onTap: () =>
                      ref.read(selectedDifficultyProvider.notifier).state = d,
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          GlowButton(
            label: loc('newGame'),
            icon: Icons.play_arrow,
            busy: startBusy,
            onTap: onStartSolo,
          ),
          const SizedBox(height: 8),
          GlassButton(
            label: loc('resumeGame'),
            icon: Icons.restore,
            onTap: canResume && !startBusy ? onResumeSolo : null,
          ),
        ],
      ),
    );
  }

  Widget _label(String text, IconData icon) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4),
    child: Row(
      children: [
        Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.6)),
        const SizedBox(width: 8),
        Text(
          text,
          style: AppTypography.labelMd.copyWith(
            color: AppColors.onSurface.withValues(alpha: 0.8),
          ),
        ),
      ],
    ),
  );
}

class _StatCard extends StatelessWidget {
  const _StatCard({
    required this.label,
    required this.value,
    required this.icon,
    this.amber = false,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return _GlassStat(label: label, value: value, icon: icon, amber: amber);
  }
}

class _GlassStat extends StatelessWidget {
  const _GlassStat({
    required this.label,
    required this.value,
    required this.icon,
    required this.amber,
  });

  final String label;
  final String value;
  final IconData icon;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: amber
              ? AppColors.primary.withValues(alpha: 0.2)
              : AppColors.surfaceBright.withValues(alpha: 0.5),
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: AppTypography.labelXs.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              value,
              style: AppTypography.displaySm.copyWith(
                color: amber ? AppColors.primary : AppColors.onSurface,
                shadows: amber ? AppTypography.amberTextGlow : null,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
