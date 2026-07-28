import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/leaderboard.dart';
import '../../../v2/presentation/controllers/leaderboard_controller.dart';
import '../../../v2/presentation/controllers/weekly_controller.dart';

/// Weekly leaderboard: podium (2·1·3) + ranked list + a pinned "you" row.
/// Wired to the live V2 leaderboard controller.
///
/// Built from the Siyaq design system — no screen-local rows, podium or text
/// styles. Data flow, pagination and providers are unchanged from the
/// pre-migration implementation.
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
    final loc = ref.watch(localizationsProvider);

    return Directionality(
      textDirection: loc.direction,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SiyaqScreenHeader(
            kicker: loc('leaderboard'),
            title: loc('placement'),
          ),
          Expanded(
            child: AnimatedSwitcher(
              duration: context.motion.summaryIn,
              child: _body(context, state, loc),
            ),
          ),
        ],
      ),
    );
  }

  Widget _body(
    BuildContext context,
    LeaderboardState state,
    AppLocalizations loc,
  ) {
    if (state.entries.isEmpty) {
      // First load, failure and zero-data are now distinct states. Before the
      // migration all three rendered an empty list — the error carried by the
      // controller was never surfaced at all.
      if (state.loading) {
        return SiyaqLoader(semanticLabel: loc('loading'));
      }
      if (state.error != null) {
        return SiyaqEmptyState.error(
          title: loc('weeklyLoadError'),
          body: loc.errorMessage(state.error!),
          actionLabel: loc('retry'),
          onAction: _weekId == null
              ? null
              : () => ref
                    .read(leaderboardControllerProvider.notifier)
                    .load(_weekId!),
        );
      }
      return SiyaqEmptyState(
        title: loc('emptyGeneric'),
        icon: SiyaqIcons.leaderboard,
      );
    }

    final rest = state.entries.skip(3).toList();
    final showOwnPlacement =
        state.currentPlacement != null &&
        !state.entries.any((e) => e.isCurrentProfile);

    return ListView(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(
        SiyaqSpacing.lg,
        0,
        SiyaqSpacing.lg,
        SiyaqSpacing.xxl,
      ),
      children: [
        if (state.entries.length >= 3)
          SiyaqPodium(
            places: [
              for (final e in state.entries.take(3))
                SiyaqPodiumPlace(placement: e.placement, label: e.label),
            ],
          ),
        const SizedBox(height: SiyaqSpacing.sm),
        for (final e in rest) _row(context, e, loc),
        if (showOwnPlacement)
          Padding(
            padding: const EdgeInsets.only(top: SiyaqSpacing.md),
            child: Align(
              alignment: AlignmentDirectional.centerStart,
              child: SiyaqChip(
                label: '${loc('yourPlacement')} #${state.currentPlacement}',
                variant: SiyaqChipVariant.accent,
              ),
            ),
          ),
        if (state.loading) SiyaqLoader.inline(semanticLabel: loc('loading')),
      ],
    );
  }

  Widget _row(
    BuildContext context,
    LeaderboardEntry entry,
    AppLocalizations loc,
  ) => SiyaqLeaderboardRow(
    placement: entry.placement,
    label: entry.label,
    isSelf: entry.isCurrentProfile,
    solved: entry.solved,
    solvedLabel: loc('solved'),
    trailing: [
      SiyaqMetaStat(
        value: '${entry.attempts}',
        icon: SiyaqIcons.attempts,
        semanticLabel: _spoken(loc, 'attempts', '${entry.attempts}'),
      ),
      if (entry.elapsed != null)
        SiyaqMetaStat(
          value: _fmt(entry.elapsed!),
          icon: SiyaqIcons.timer,
          semanticLabel: _spoken(loc, 'elapsed', _fmt(entry.elapsed!)),
        ),
    ],
  );

  /// `"<label>: <value>"` for a screen reader.
  ///
  /// Some copy already carries trailing punctuation (`attempts` is `"Guesses:"`),
  /// so it is stripped first — otherwise the label reads "Guesses:: 25".
  static String _spoken(AppLocalizations loc, String key, String value) {
    final base = loc(key).trim();
    final label = base.endsWith(':')
        ? base.substring(0, base.length - 1)
        : base;
    return '$label: $value';
  }

  static String _fmt(Duration d) =>
      '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';
}
