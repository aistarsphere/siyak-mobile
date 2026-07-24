import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/leaderboard.dart';
import '../../../v2/presentation/controllers/leaderboard_controller.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';

/// Weekly leaderboard (leaderboard.tsx): podium (2·1·3) + ranked list + a
/// pinned "you" row. Wired to the live V2 leaderboard controller.
class SiyagLeaderboardScreen extends ConsumerStatefulWidget {
  const SiyagLeaderboardScreen({super.key});

  @override
  ConsumerState<SiyagLeaderboardScreen> createState() =>
      _SiyagLeaderboardScreenState();
}

class _SiyagLeaderboardScreenState
    extends ConsumerState<SiyagLeaderboardScreen> {
  final _scroll = ScrollController();
  String? _weekId;

  @override
  void initState() {
    super.initState();
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
    final lang = GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang);
    final challenge = ref.watch(weeklyChallengeProvider(lang)).value;
    if (challenge != null && challenge.weekId != _weekId) {
      _weekId = challenge.weekId;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(leaderboardControllerProvider.notifier).load(challenge.weekId);
      });
    }
    final state = ref.watch(leaderboardControllerProvider);

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const SiyagScreenHeader(kicker: 'Weekly Rankings', title: 'المتصدرون'),
          Expanded(
            child: state.entries.isEmpty && state.loading
                ? const Center(
                    child: CircularProgressIndicator(color: SC.coral))
                : ListView(
                    controller: _scroll,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                    children: [
                      if (state.entries.length >= 3)
                        _Podium(top: state.entries.take(3).toList()),
                      const SizedBox(height: 8),
                      for (final e in state.entries.skip(3))
                        _Row(entry: e),
                      if (state.currentPlacement != null &&
                          !state.entries.any((e) => e.isCurrentProfile))
                        Padding(
                          padding: const EdgeInsets.only(top: 12),
                          child: Text('مركزك #${state.currentPlacement}',
                              style: ST.mono(13, color: SC.coral)),
                        ),
                      if (state.loading && state.entries.isNotEmpty)
                        const Padding(
                          padding: EdgeInsets.all(16),
                          child: Center(
                              child: SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                      strokeWidth: 2, color: SC.coral))),
                        ),
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

class _Podium extends StatelessWidget {
  const _Podium({required this.top});
  final List<LeaderboardEntry> top;

  @override
  Widget build(BuildContext context) {
    // order 2·1·3, heights 70·96·56, colors dim·coral·cyan
    final order = [top[1], top[0], top[2]];
    const heights = [70.0, 96.0, 56.0];
    const colors = [SC.textDim, SC.coral, SC.cyan];
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            Expanded(
              child: Column(
                children: [
                  SiyagAvatar(
                    letter: order[i].label.characters.first,
                    size: i == 1 ? 52 : 42,
                    color: colors[i],
                    active: i == 1,
                  ),
                  const SizedBox(height: 8),
                  Text(order[i].label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: ST.ar(12, color: SC.textDim)),
                  const SizedBox(height: 8),
                  TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0, end: heights[i]),
                    duration: Duration(milliseconds: 500 + i * 80),
                    curve: SM.easeOutQuint,
                    builder: (context, h, _) => Container(
                      width: double.infinity,
                      height: h,
                      alignment: Alignment.topCenter,
                      padding: const EdgeInsets.only(top: 8),
                      decoration: BoxDecoration(
                        color: i == 1 ? SC.coralDim : SC.surface,
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(16)),
                        border: Border(
                            top: BorderSide(color: colors[i], width: 2)),
                      ),
                      child: Text('${order[i].placement}',
                          style: ST.mono(22, color: colors[i])),
                    ),
                  ),
                ],
              ),
            ),
            if (i < 2) const SizedBox(width: 12),
          ],
        ],
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({required this.entry});
  final LeaderboardEntry entry;

  @override
  Widget build(BuildContext context) {
    final me = entry.isCurrentProfile;
    return Container(
      margin: EdgeInsets.symmetric(vertical: me ? 6 : 0),
      padding: EdgeInsets.symmetric(horizontal: me ? 16 : 8, vertical: 12),
      decoration: me
          ? BoxDecoration(
              color: SC.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: SC.coral.withValues(alpha: 0.33)),
            )
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: SC.line)),
            ),
      child: Row(
        children: [
          SizedBox(
            width: 24,
            child: Text('${entry.placement}',
                style: ST.mono(13, color: me ? SC.coral : SC.textMute)),
          ),
          const SizedBox(width: 8),
          SiyagAvatar(
              letter: entry.label.characters.first, size: 34, active: me),
          const SizedBox(width: 12),
          Expanded(
            child: Text(entry.label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: ST.ar(15,
                    weight: me ? FontWeight.w500 : FontWeight.w400,
                    color: me ? SC.text : SC.textDim)),
          ),
          if (entry.solved)
            const Padding(
              padding: EdgeInsets.only(left: 8),
              child: Icon(Icons.check_circle, size: 14, color: SC.emerald),
            ),
          _mini('${entry.attempts}', Icons.lightbulb_outline_rounded),
          const SizedBox(width: 10),
          if (entry.elapsed != null)
            _mini(_fmt(entry.elapsed!), Icons.schedule_rounded),
        ],
      ),
    );
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  Widget _mini(String v, IconData icon) => Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(v, style: ST.mono(11, color: SC.textMute)),
          const SizedBox(width: 3),
          Icon(icon, size: 10, color: SC.textMute),
        ],
      );
}
