import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/ranked.dart';
import '../../../v2/presentation/controllers/matchmaking_controller.dart';
import '../../../v2/presentation/controllers/ranked_controller.dart';
import '../../../v2/presentation/controllers/wallet_controller.dart';
import '../siyag_route.dart';
import 'siyag_ranked_match_screen.dart';

/// Ranked 1v1 entry: rating + tiers; joining reserves the entry and searches
/// for an opponent, then routes into the live match (contract §8).
///
/// Built from the Siyaq design system. This migration also fixes three real
/// state bugs the old screen shipped with: loading rendered a **fake 1000
/// rating** (`.value ?? 1000`), stats/tiers fetch errors were **silently
/// swallowed** with no retry, and the matchmaking failure was styled in the
/// brand gold instead of the error role.
class SiyagRankedScreen extends ConsumerWidget {
  const SiyagRankedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final stats = ref.watch(rankedStatsProvider);
    final tiers = ref.watch(rankedTiersProvider);
    final wallet = ref.watch(walletControllerProvider).value;
    final mm = ref.watch(matchmakingControllerProvider);

    // Route into the match once matchmaking succeeds.
    ref.listen(matchmakingControllerProvider, (_, next) {
      if (next.phase == MatchmakingPhase.matched && next.matchId != null) {
        final id = next.matchId!;
        ref.read(matchmakingControllerProvider.notifier).reset();
        Navigator.of(
          context,
        ).push(siyagRoute(SiyagRankedMatchScreen(matchId: id)));
      }
    });

    void retry() {
      ref.invalidate(rankedStatsProvider);
      ref.invalidate(rankedTiersProvider);
    }

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('competitive'),
                accent: c.primary,
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
                  duration: context.motion.summaryIn,
                  // Loading and error are decided by the *tiers* fetch — a
                  // ranked lobby without tiers has nothing to offer. Stats ride
                  // along and render `—` until they arrive.
                  child: tiers.when(
                    loading: () => SiyaqLoader(semanticLabel: loc('loading')),
                    error: (e, _) => SiyaqEmptyState.error(
                      title: loc('somethingWrong'),
                      body: loc.errorMessage(e),
                      actionLabel: loc('retry'),
                      onAction: retry,
                    ),
                    data: (tierList) => _Lobby(
                      loc: loc,
                      stats: stats.value,
                      tiers: tierList,
                      walletBalance: wallet?.availableBalance,
                      mm: mm,
                      onRetry: retry,
                      onPlay: (tier) => ref
                          .read(matchmakingControllerProvider.notifier)
                          .findMatch(
                            tierId: tier.id,
                            language: ref.read(appSettingsProvider).lang,
                          ),
                      onCancel: () => ref
                          .read(matchmakingControllerProvider.notifier)
                          .cancel(),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Lobby extends StatelessWidget {
  const _Lobby({
    required this.loc,
    required this.stats,
    required this.tiers,
    required this.walletBalance,
    required this.mm,
    required this.onRetry,
    required this.onPlay,
    required this.onCancel,
  });

  final AppLocalizations loc;
  final RankedStats? stats;
  final List<RankedTier> tiers;
  final int? walletBalance;
  final MatchmakingState mm;
  final VoidCallback onRetry;
  final void Function(RankedTier) onPlay;
  final VoidCallback onCancel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        SiyaqSpacing.xl,
        SiyaqSpacing.sm,
        SiyaqSpacing.xl,
        SiyaqSpacing.xxl,
      ),
      children: [
        // ── Rating / record ──────────────────────────────────────────────────
        // Stats may still be in flight — the cards show their placeholder (—)
        // instead of the old fake 1000.
        SiyaqStatGrid(
          columns: 2,
          minCellWidth: 120,
          children: [
            SiyaqStatCard(
              value: stats != null ? '${stats!.rating}' : null,
              label: loc('rating'),
              accent: c.primary,
              semanticLabel: stats != null
                  ? '${loc('rating')}: ${stats!.rating}'
                  : loc('rating'),
            ),
            SiyaqStatCard(
              value: stats != null
                  ? '${stats!.wins}${loc('winShort')} · '
                        '${stats!.losses}${loc('lossShort')}'
                  : null,
              label: loc('record'),
              numeric: false,
              semanticLabel: stats != null
                  ? '${loc('record')}: ${stats!.wins} - ${stats!.losses}'
                  : loc('record'),
            ),
          ],
        ),
        const SizedBox(height: SiyaqSpacing.xl),

        // ── Stakes ───────────────────────────────────────────────────────────
        SiyaqText(
          loc('chooseStake').toUpperCase(),
          role: SiyaqTextRole.labelSmall,
          script: SiyaqScript.mono,
          color: c.textMuted,
          header: true,
        ),
        const SizedBox(height: SiyaqSpacing.sm),
        if (tiers.isEmpty)
          SiyaqEmptyState(
            title: loc('noTiers'),
            icon: SiyaqIcons.coins,
            actionLabel: loc('retry'),
            onAction: onRetry,
          )
        else
          for (final tier in tiers) ...[
            _TierRow(
              tier: tier,
              affordable:
                  walletBalance == null || walletBalance! >= tier.entryCost,
              busy: mm.isSearching,
              loc: loc,
              onPlay: () => onPlay(tier),
            ),
            const SizedBox(height: SiyaqSpacing.smd),
          ],

        // ── Matchmaking states ───────────────────────────────────────────────
        if (mm.isSearching) ...[
          const SizedBox(height: SiyaqSpacing.sm),
          SiyaqSurface(
            accent: c.primary,
            selected: true,
            child: Row(
              children: [
                SiyaqLoader.inline(semanticLabel: loc('searchingOpponent')),
                const SizedBox(width: SiyaqSpacing.md),
                Expanded(
                  child: SiyaqText(
                    loc('searchingOpponent'),
                    role: SiyaqTextRole.bodyMedium,
                    weight: FontWeight.w600,
                  ),
                ),
                SiyaqButton(
                  label: loc('cancel'),
                  type: SiyaqButtonType.ghost,
                  onPressed: onCancel,
                ),
              ],
            ),
          ),
        ],
        if (mm.phase == MatchmakingPhase.error) ...[
          const SizedBox(height: SiyaqSpacing.sm),
          // A failure speaks in the error role, not the brand gold.
          SiyaqTintedSurface(
            tone: SiyaqTone.error,
            child: Row(
              children: [
                SiyaqIcon.decorative(
                  SiyaqIcons.offline,
                  size: SiyaqIconSize.md,
                  color: c.error,
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                Expanded(
                  child: SiyaqText(
                    loc('searchFailed'),
                    role: SiyaqTextRole.bodyMedium,
                    color: c.error,
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

class _TierRow extends StatelessWidget {
  const _TierRow({
    required this.tier,
    required this.affordable,
    required this.busy,
    required this.onPlay,
    required this.loc,
  });

  final RankedTier tier;
  final bool affordable;
  final bool busy;
  final VoidCallback onPlay;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final enabled = tier.enabled && affordable && !busy;
    return SiyaqListRow(
      title: loc.fill('entryPrize', {
        'e': '${tier.entryCost}',
        'p': '${tier.payout}',
      }),
      subtitle: affordable
          ? loc('winnerTakesStake')
          : loc('insufficientBalance'),
      leadingIcon: SiyaqIcons.coins,
      leadingColor: affordable ? c.primary : c.textDisabled,
      tone: affordable ? null : SiyaqTone.warning,
      trailing: SiyaqButton(
        label: loc('search'),
        size: SiyaqButtonSize.medium,
        loading: busy,
        onPressed: enabled ? onPlay : null,
      ),
      semanticLabel:
          '${loc.fill('entryPrize', {'e': '${tier.entryCost}', 'p': '${tier.payout}'})}, '
          '${affordable ? loc('winnerTakesStake') : loc('insufficientBalance')}',
    );
  }
}
