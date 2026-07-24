import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/confetti_overlay.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../controllers/weekly_controller.dart';
import '../widgets/v2_scaffold.dart';
import 'leaderboard_screen.dart';

/// Weekly result: solved state, attempts, hints, elapsed, placement, with a
/// confetti celebration consistent with the solo victory language.
class WeeklyResultScreen extends ConsumerStatefulWidget {
  const WeeklyResultScreen({super.key});

  @override
  ConsumerState<WeeklyResultScreen> createState() => _WeeklyResultScreenState();
}

class _WeeklyResultScreenState extends ConsumerState<WeeklyResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: AppMotion.pulseGlow,
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  String _fmt(Duration? d) {
    if (d == null) return '—';
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }

  void _share() {
    final loc = ref.read(localizationsProvider);
    final run = ref.read(weeklyRunControllerProvider).run;
    if (run == null) return;
    SharePlus.instance.share(
      ShareParams(
        text:
            '${loc('appTitle')} · ${loc('weekly')} 🎯\n'
            '${loc('shareSolvedIn').replaceFirst('{n}', '${run.attempts}')}\n'
            '${loc('placement')}: #${run.placement ?? '-'}',
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final run = ref.watch(weeklyRunControllerProvider).run;
    final secret = run?.secretWord ?? '';

    return V2Scaffold(
      title: loc('weeklyResultTitle'),
      child: Stack(
        children: [
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
            children: [
              Center(
                child: Text(
                  loc('solvedTitle'),
                  style: AppTypography.headlineMobile.copyWith(
                    color: AppColors.onBackground,
                  ),
                ),
              ),
              const SizedBox(height: 20),
              AnimatedBuilder(
                animation: _pulse,
                builder: (context, child) {
                  final t = Curves.easeInOut.transform(_pulse.value);
                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.amberGlow(0.2 + 0.3 * t),
                          blurRadius: 15 + 15 * t,
                        ),
                      ],
                    ),
                    child: child,
                  );
                },
                child: GlassPanel(
                  opacity: 0.4,
                  blur: 24,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: AppColors.primaryContainer.withValues(alpha: 0.3),
                  ),
                  padding: const EdgeInsets.all(28),
                  child: Column(
                    children: [
                      Text(
                        loc('secretWordIs'),
                        style: AppTypography.labelMd.copyWith(
                          color: AppColors.primary.withValues(alpha: 0.8),
                          letterSpacing: 2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        secret,
                        textAlign: TextAlign.center,
                        style: AppTypography.secretWord.copyWith(
                          shadows: [
                            Shadow(
                              color: AppColors.amberGlow(0.6),
                              blurRadius: 15,
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 24),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      '${run?.attempts ?? 0}',
                      loc('attemptsLabel'),
                      Icons.sync,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      '#${run?.placement ?? '-'}',
                      loc('placement'),
                      Icons.emoji_events,
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: _stat(
                      '${run?.hintsUsed ?? 0}',
                      loc('hintsLabel'),
                      Icons.lightbulb_outline,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: _stat(
                      _fmt(run?.elapsed),
                      loc('elapsed'),
                      Icons.timer_outlined,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              GlowButton(
                label: loc('leaderboard'),
                icon: Icons.leaderboard,
                onTap: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) =>
                        LeaderboardScreen(weekId: run?.weekId ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              GlassButton(
                label: loc('shareResult'),
                icon: Icons.share,
                onTap: _share,
              ),
              const SizedBox(height: 8),
              GlassButton(
                label: loc('returnHome'),
                icon: Icons.home_outlined,
                onTap: () => Navigator.of(context).popUntil((r) => r.isFirst),
              ),
            ],
          ),
          const Positioned.fill(child: ConfettiOverlay()),
        ],
      ),
    );
  }

  Widget _stat(
    String value,
    String label,
    IconData icon, {
    Color color = AppColors.onBackground,
  }) => GlassPanel(
    opacity: 0.2,
    borderRadius: BorderRadius.circular(12),
    border: Border.all(color: AppColors.onSurface.withValues(alpha: 0.05)),
    padding: const EdgeInsets.all(16),
    child: Column(
      children: [
        Text(value, style: AppTypography.displaySm.copyWith(color: color)),
        const SizedBox(height: 4),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
            const SizedBox(width: 4),
            Flexible(
              child: Text(
                label,
                overflow: TextOverflow.ellipsis,
                style: AppTypography.labelXs.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ),
          ],
        ),
      ],
    ),
  );
}
