import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../domain/entities/leaderboard.dart';
import '../controllers/leaderboard_controller.dart';
import '../widgets/v2_scaffold.dart';

/// Paginated weekly leaderboard. Top three get an elegant amber/podium accent;
/// the current profile row is highlighted. Never shows installation IDs.
class LeaderboardScreen extends ConsumerStatefulWidget {
  const LeaderboardScreen({super.key, required this.weekId});

  final String weekId;

  @override
  ConsumerState<LeaderboardScreen> createState() => _LeaderboardScreenState();
}

class _LeaderboardScreenState extends ConsumerState<LeaderboardScreen> {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      ref.read(leaderboardControllerProvider.notifier).load(widget.weekId);
    });
    _scroll.addListener(() {
      if (_scroll.position.pixels > _scroll.position.maxScrollExtent - 300) {
        ref.read(leaderboardControllerProvider.notifier).loadMore();
      }
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(leaderboardControllerProvider);

    return V2Scaffold(
      title: loc('leaderboard'),
      child: state.entries.isEmpty && state.loading
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.amber),
            )
          : ListView.separated(
              controller: _scroll,
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: state.entries.length + (state.hasMore ? 1 : 0),
              separatorBuilder: (_, _) => const SizedBox(height: 6),
              itemBuilder: (context, i) {
                if (i >= state.entries.length) {
                  return const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(
                      child: SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppColors.amber,
                        ),
                      ),
                    ),
                  );
                }
                return _LeaderboardRow(entry: state.entries[i], loc: loc);
              },
            ),
    );
  }
}

class _LeaderboardRow extends StatelessWidget {
  const _LeaderboardRow({required this.entry, required this.loc});

  final LeaderboardEntry entry;
  final dynamic loc;

  Color? _podium() => switch (entry.placement) {
    1 => AppColors.primaryContainer,
    2 => AppColors.onSurfaceVariant,
    3 => AppColors.secondary,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final podium = _podium();
    final highlight = entry.isCurrentProfile;
    return GlassPanel(
      opacity: highlight ? 0.35 : (podium != null ? 0.25 : 0.15),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: highlight
            ? AppColors.primary.withValues(alpha: 0.7)
            : (podium?.withValues(alpha: 0.4) ??
                  AppColors.surfaceBright.withValues(alpha: 0.3)),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          SizedBox(
            width: 36,
            child: podium != null
                ? Icon(Icons.emoji_events, color: podium, size: 22)
                : Text(
                    '#${entry.placement}',
                    textAlign: TextAlign.center,
                    style: AppTypography.labelMd.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              entry.label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.bodyLg.copyWith(
                color: highlight ? AppColors.primary : AppColors.onSurface,
                fontWeight: highlight ? FontWeight.w600 : FontWeight.w400,
              ),
            ),
          ),
          if (entry.solved)
            const Icon(Icons.check_circle, size: 16, color: AppColors.emerald),
          const SizedBox(width: 10),
          _mini('${entry.attempts}', Icons.sync),
          const SizedBox(width: 10),
          _mini('${entry.hintsUsed}', Icons.lightbulb_outline),
        ],
      ),
    );
  }

  Widget _mini(String v, IconData icon) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(icon, size: 13, color: AppColors.onSurfaceVariant),
      const SizedBox(width: 2),
      Text(
        v,
        style: AppTypography.labelXs.copyWith(
          color: AppColors.onSurfaceVariant,
        ),
      ),
    ],
  );
}
