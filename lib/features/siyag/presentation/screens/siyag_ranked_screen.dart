import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/design/theme/context_tokens.dart';
import '../../../../core/design/theme/legacy_type_bridge.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/ranked.dart';
import '../../../v2/presentation/controllers/matchmaking_controller.dart';
import '../../../v2/presentation/controllers/ranked_controller.dart';
import '../../../v2/presentation/controllers/wallet_controller.dart';
import '../siyag_route.dart';
import 'siyag_ranked_match_screen.dart';

/// Ranked 1v1 entry: rating + tiers; joining reserves the entry and searches
/// for an opponent, then routes into the live match (contract §8).
class SiyagRankedScreen extends ConsumerWidget {
  const SiyagRankedScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final stats = ref.watch(rankedStatsProvider).value;
    final tiers = ref.watch(rankedTiersProvider).value ?? const <RankedTier>[];
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

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: context.colors.background,
        appBar: AppBar(
          backgroundColor: context.colors.background,
          elevation: 0,
          title: Text(
            loc('competitive'),
            style: context.legacyType.ar(18, weight: FontWeight.w700),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              _RatingCard(stats: stats, loc: loc),
              const SizedBox(height: 20),
              Kicker(loc('chooseStake')),
              const SizedBox(height: 10),
              if (tiers.isEmpty)
                Text(
                  loc('noTiers'),
                  style: context.legacyType.ar(
                    13,
                    color: context.colors.textMuted,
                  ),
                )
              else
                for (final t in tiers) ...[
                  _TierRow(
                    tier: t,
                    affordable:
                        wallet == null ||
                        wallet.availableBalance >= t.entryCost,
                    busy: mm.isSearching,
                    loc: loc,
                    onPlay: () => ref
                        .read(matchmakingControllerProvider.notifier)
                        .findMatch(
                          tierId: t.id,
                          language: ref.read(appSettingsProvider).lang,
                        ),
                  ),
                  const SizedBox(height: 10),
                ],
              if (mm.isSearching) ...[
                const SizedBox(height: 8),
                _SearchingCard(
                  loc: loc,
                  onCancel: () =>
                      ref.read(matchmakingControllerProvider.notifier).cancel(),
                ),
              ],
              if (mm.phase == MatchmakingPhase.error) ...[
                const SizedBox(height: 8),
                Text(
                  loc('searchFailed'),
                  style: context.legacyType.ar(
                    12,
                    color: context.colors.primary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _RatingCard extends StatelessWidget {
  const _RatingCard({required this.stats, required this.loc});
  final RankedStats? stats;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.border),
    ),
    child: Row(
      children: [
        Icon(
          Icons.military_tech_rounded,
          size: 34,
          color: context.colors.primary,
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '${stats?.rating ?? 1000}',
              style: context.legacyType.mono(28),
            ),
            Text(
              loc('rating'),
              style: context.legacyType.ar(11, color: context.colors.textMuted),
            ),
          ],
        ),
        const Spacer(),
        Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Text(
              '${stats?.wins ?? 0}${loc('winShort')} · ${stats?.losses ?? 0}${loc('lossShort')}',
              style: context.legacyType.ar(14, weight: FontWeight.w600),
            ),
            Text(
              loc('record'),
              style: context.legacyType.ar(11, color: context.colors.textMuted),
            ),
          ],
        ),
      ],
    ),
  );
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
    final enabled = tier.enabled && affordable && !busy;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: context.colors.border),
      ),
      child: Row(
        children: [
          Icon(
            Icons.monetization_on_rounded,
            size: 22,
            color: context.colors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc.fill('entryPrize', {
                    'e': '${tier.entryCost}',
                    'p': '${tier.payout}',
                  }),
                  style: context.legacyType.ar(15, weight: FontWeight.w600),
                ),
                Text(
                  affordable
                      ? loc('winnerTakesStake')
                      : loc('insufficientBalance'),
                  style: context.legacyType.ar(
                    11,
                    color: affordable
                        ? context.colors.textMuted
                        : context.colors.primary,
                  ),
                ),
              ],
            ),
          ),
          SiyagPrimaryButton(
            label: loc('search'),
            busy: busy,
            onTap: enabled ? onPlay : null,
            fullWidth: false,
          ),
        ],
      ),
    );
  }
}

class _SearchingCard extends StatelessWidget {
  const _SearchingCard({required this.onCancel, required this.loc});
  final VoidCallback onCancel;
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      color: context.colors.surface,
      borderRadius: BorderRadius.circular(20),
      border: Border.all(color: context.colors.primary.withValues(alpha: 0.4)),
    ),
    child: Row(
      children: [
        SizedBox(
          width: 22,
          height: 22,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            color: context.colors.primary,
          ),
        ),
        const SizedBox(width: 14),
        Expanded(
          child: Text(
            loc('searchingOpponent'),
            style: context.legacyType.ar(15, weight: FontWeight.w600),
          ),
        ),
        SiyagTap(
          onTap: onCancel,
          child: Text(
            loc('cancel'),
            style: context.legacyType.ar(13, color: context.colors.primary),
          ),
        ),
      ],
    ),
  );
}
