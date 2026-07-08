import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/modes_info.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/game_controller.dart';
import '../controllers/providers.dart';
import '../controllers/stats_controller.dart';
import '../widgets/app_logo.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glow_button.dart';
import '../widgets/pressable.dart';
import '../widgets/selector_chip.dart';
import '../widgets/top_app_bar.dart';
import 'shell_screen.dart';

/// Selected category code (null → first playable) and difficulty.
/// Difficulty is a client-side concept fed to the backend's hint endpoint;
/// new-game itself takes only language + category.
final selectedModeProvider = StateProvider<String?>((ref) => null);
final selectedDifficultyProvider = StateProvider<String>((ref) => 'medium');

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

  Future<void> _startGame({bool resume = false}) async {
    if (_starting) return;
    final loc = ref.read(localizationsProvider);
    final modes = ref.read(modesProvider).value;
    if (modes == null || modes.playable.isEmpty) return;
    final lang = ref.read(appSettingsProvider).lang;
    final categoryCode = ref.read(selectedModeProvider) ?? modes.playable.first.code;
    final category = modes.playable.firstWhere(
      (c) => c.code == categoryCode,
      orElse: () => modes.playable.first,
    );
    final difficulty = ref.read(selectedDifficultyProvider);
    setState(() => _starting = true);
    try {
      final controller = ref.read(gameControllerProvider.notifier);
      var ok = true;
      if (resume) {
        ok = await controller.resumeSavedGame();
      }
      if (!resume || !ok) {
        await controller.startNewGame(
          language: lang,
          category: category.code,
          categoryLabel: category.labelFor(lang),
          difficulty: difficulty,
        );
      }
      if (mounted) ref.read(shellTabProvider.notifier).state = 1;
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(loc.errorMessage(e))),
        );
      }
    } finally {
      if (mounted) setState(() => _starting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final modes = ref.watch(modesProvider);
    final stats = ref.watch(statsProvider);
    final activeGame = ref.watch(gameControllerProvider
        .select((s) => s.hasGame && !s.solved));
    final canResume = activeGame ||
        ref.read(gameControllerProvider.notifier).hasSavedGame;

    return Column(
      children: [
        SiyaqTopBar(
          title: loc('appTitle'),
          onLanguageTap: () =>
              ref.read(appSettingsProvider.notifier).toggleLang(),
          trailing: Pressable(
            onTap: () => ref.read(shellTabProvider.notifier).state = 2,
            child: const Icon(Icons.leaderboard_outlined,
                size: 20, color: AppColors.onSurfaceVariant),
          ),
        ),
        Expanded(
          child: modes.when(
            loading: () => const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            ),
            error: (e, _) => _ErrorRetry(message: loc.errorMessage(e)),
            data: (info) => _HomeBody(
              info: info,
              startBusy: _starting,
              canResume: canResume,
              onNewGame: () => _startGame(),
              onResume: () => _startGame(resume: true),
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
  const _ErrorRetry({required this.message});

  final String message;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(message,
                textAlign: TextAlign.center,
                style:
                    AppTypography.bodySm.copyWith(color: AppColors.error)),
            const SizedBox(height: 16),
            GlowButton(
              label: loc('retry'),
              icon: Icons.refresh,
              onTap: () => ref.invalidate(modesProvider),
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
    required this.onNewGame,
    required this.onResume,
    required this.statsAttempts,
    required this.statsBest,
  });

  final ModesInfo info;
  final bool startBusy;
  final bool canResume;
  final VoidCallback onNewGame;
  final VoidCallback onResume;
  final int statsAttempts;
  final int statsBest;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
    final categories = info.playable;
    final selectedMode = ref.watch(selectedModeProvider) ??
        (categories.isNotEmpty ? categories.first.code : '');
    final selectedDifficulty = ref.watch(selectedDifficultyProvider);

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
      children: [
        // Hero
        const SizedBox(height: 16),
        const Center(child: AppLogo()),
        const SizedBox(height: 16),
        Center(
          child: Text(
            loc('appTitle'),
            style: AppTypography.displayLg.copyWith(
              color: AppColors.primary,
              shadows: const [
                Shadow(color: Colors.black54, offset: Offset(0, 2), blurRadius: 4),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 260),
            child: Text(
              loc('tagline'),
              textAlign: TextAlign.center,
              style: AppTypography.bodyLg
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ),
        const SizedBox(height: 24),
        // Category selector
        _SelectorSection(
          icon: Icons.category_outlined,
          title: loc('category'),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: categories.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final c = categories[i];
                return SelectorChip(
                  label: c.labelFor(lang),
                  selected: c.code == selectedMode,
                  onTap: () =>
                      ref.read(selectedModeProvider.notifier).state = c.code,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 16),
        // Difficulty selector
        _SelectorSection(
          icon: Icons.speed,
          title: loc('difficulty'),
          child: SizedBox(
            height: 44,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: info.difficulties.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, i) {
                final d = info.difficulties[i];
                return SelectorChip(
                  label: d.label,
                  selected: d.id == selectedDifficulty,
                  accent: ChipAccent.secondary,
                  onTap: () => ref
                      .read(selectedDifficultyProvider.notifier)
                      .state = d.id,
                );
              },
            ),
          ),
        ),
        const SizedBox(height: 24),
        // CTAs
        GlowButton(
          label: loc('newGame'),
          icon: Icons.play_arrow,
          busy: startBusy,
          onTap: onNewGame,
        ),
        const SizedBox(height: 8),
        GlassButton(
          label: loc('resumeGame'),
          icon: Icons.restore,
          onTap: canResume && !startBusy ? onResume : null,
        ),
        const SizedBox(height: 16),
        // Stats mini-bento
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

class _SelectorSection extends StatelessWidget {
  const _SelectorSection({
    required this.icon,
    required this.title,
    required this.child,
  });

  final IconData icon;
  final String title;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4),
          child: Row(
            children: [
              Icon(icon, size: 18, color: AppColors.primary.withValues(alpha: 0.6)),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTypography.labelMd.copyWith(
                  color: AppColors.onSurface.withValues(alpha: 0.8),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

/// Home mini-bento stat card: glass, big number, oversized faded icon in
/// the corner; the "best" variant glows amber.
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
    return GlassPanel(
      opacity: 0.20,
      blur: 24,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: amber
            ? AppColors.primary.withValues(alpha: 0.20)
            : AppColors.surfaceBright.withValues(alpha: 0.50),
      ),
      child: SizedBox(
        height: 88,
        child: Stack(
          children: [
            PositionedDirectional(
              end: -16,
              bottom: -16,
              child: Icon(
                icon,
                size: 72,
                color: (amber ? AppColors.primary : AppColors.onSurfaceVariant)
                    .withValues(alpha: amber ? 0.10 : 0.05),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    label,
                    style: AppTypography.labelXs
                        .copyWith(color: AppColors.onSurfaceVariant),
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
          ],
        ),
      ),
    );
  }
}
