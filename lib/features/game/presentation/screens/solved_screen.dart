import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../data/models/guess_result.dart';
import '../../domain/entities/heat.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/game_controller.dart';
import '../widgets/atmospheric_background.dart';
import '../widgets/confetti_overlay.dart';
import '../widgets/glass_panel.dart';
import '../widgets/glow_button.dart';
import '../widgets/top_app_bar.dart';

/// Victory screen — faithful to the Stitch "Solved" design: confetti rain,
/// bouncing gold medal, glass gold card with pulse-glow + shine sweep holding
/// the secret word, 3-tile bento (attempts / rank / hints), closest guesses
/// with fill bars, then share + new game. Bottom nav is suppressed by design.
class SolvedScreen extends ConsumerStatefulWidget {
  const SolvedScreen({super.key});

  @override
  ConsumerState<SolvedScreen> createState() => _SolvedScreenState();
}

class _SolvedScreenState extends ConsumerState<SolvedScreen>
    with TickerProviderStateMixin {
  late final AnimationController _bounce = AnimationController(
      vsync: this, duration: AppMotion.bounce)
    ..repeat();
  late final AnimationController _pulse = AnimationController(
      vsync: this, duration: AppMotion.pulseGlow)
    ..repeat(reverse: true);
  late final AnimationController _shine = AnimationController(
      vsync: this, duration: AppMotion.shine)
    ..repeat();
  bool _startingNew = false;

  @override
  void dispose() {
    _bounce.dispose();
    _pulse.dispose();
    _shine.dispose();
    super.dispose();
  }

  Future<void> _newGame() async {
    if (_startingNew) return;
    final state = ref.read(gameControllerProvider);
    final meta = state.meta;
    if (meta == null) return;
    setState(() => _startingNew = true);
    try {
      await ref.read(gameControllerProvider.notifier).startNewGame(
          mode: meta.mode, difficulty: meta.difficulty);
      if (mounted) Navigator.of(context).pop();
    } catch (e) {
      if (mounted) {
        setState(() => _startingNew = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
            content:
                Text(ref.read(localizationsProvider).errorMessage(e))));
      }
    }
  }

  void _share() {
    final loc = ref.read(localizationsProvider);
    final state = ref.read(gameControllerProvider);
    // Never reveal the secret word in the share text.
    SharePlus.instance.share(ShareParams(
      text: loc.shareText(
        attempts: state.attempts,
        bestRank: 1,
        hintsUsed: state.hintsUsed,
        maxHints: AppConfig.maxHints,
      ),
    ));
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(gameControllerProvider);
    final secretGuess = state.guesses.where((g) => g.isSecret).firstOrNull;
    final secretWord = secretGuess?.answerWord ?? '';
    // Closest non-secret guesses, top 3 (as in the design).
    final closest = state.sortedGuesses
        .where((g) => !g.isSecret)
        .take(3)
        .toList();

    return Scaffold(
      body: AtmosphericBackground(
        child: Stack(
          children: [
            Column(
              children: [
                SiyaqTopBar(title: loc('appTitle')),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
                    children: [
                      // Bouncing medal + headline
                      AnimatedBuilder(
                        animation: _bounce,
                        builder: (context, child) {
                          final t = _bounce.value;
                          // CSS `bounce`: dips twice per 2s cycle.
                          final phase = (t * 2) % 1;
                          final dy =
                              -8 * (1 - (2 * phase - 1).abs());
                          return Transform.translate(
                              offset: Offset(0, dy), child: child);
                        },
                        child: Column(children: [
                          Container(
                            width: 64,
                            height: 64,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.primaryContainer
                                  .withValues(alpha: 0.20),
                              border: Border.all(
                                  color: AppColors.primary
                                      .withValues(alpha: 0.30)),
                              boxShadow: [
                                BoxShadow(
                                    color: AppColors.amberGlow(0.4),
                                    blurRadius: 20),
                              ],
                            ),
                            child: const Icon(Icons.workspace_premium,
                                color: AppColors.primary, size: 36),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            loc('solvedTitle'),
                            textAlign: TextAlign.center,
                            style: AppTypography.headlineMobile
                                .copyWith(color: AppColors.onBackground),
                          ),
                        ]),
                      ),
                      const SizedBox(height: 24),
                      // Secret word card with pulse-glow + shine sweep
                      AnimatedBuilder(
                        animation: _pulse,
                        builder: (context, child) {
                          final t =
                              Curves.easeInOut.transform(_pulse.value);
                          return Container(
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(16),
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.amberGlow(
                                      0.2 + 0.3 * t),
                                  blurRadius: 15 + 15 * t,
                                ),
                              ],
                            ),
                            child: child,
                          );
                        },
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(16),
                          // Passthrough so the glass card fills the full
                          // width instead of shrink-wrapping its text.
                          child: Stack(fit: StackFit.passthrough, children: [
                            GlassPanel(
                              opacity: 0.40,
                              blur: 24,
                              borderRadius: BorderRadius.circular(16),
                              border: Border.all(
                                  color: AppColors.primaryContainer
                                      .withValues(alpha: 0.30)),
                              padding: const EdgeInsets.all(32),
                              child: Column(children: [
                                Text(
                                  loc('secretWordIs'),
                                  style: AppTypography.labelMd.copyWith(
                                    color: AppColors.primary
                                        .withValues(alpha: 0.8),
                                    letterSpacing: 2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  secretWord,
                                  textAlign: TextAlign.center,
                                  style:
                                      AppTypography.secretWord.copyWith(
                                    shadows: [
                                      Shadow(
                                          color: AppColors.amberGlow(0.6),
                                          blurRadius: 15),
                                    ],
                                  ),
                                ),
                                const SizedBox(height: 16),
                                // Decorative gradient underline
                                Container(
                                  height: 4,
                                  width: 120,
                                  decoration: BoxDecoration(
                                    borderRadius:
                                        BorderRadius.circular(999),
                                    gradient: LinearGradient(colors: [
                                      AppColors.primaryContainer
                                          .withValues(alpha: 0),
                                      AppColors.primaryContainer
                                          .withValues(alpha: 0.5),
                                      AppColors.primaryContainer
                                          .withValues(alpha: 0),
                                    ]),
                                  ),
                                ),
                              ]),
                            ),
                            // Shine sweep
                            Positioned.fill(
                              child: IgnorePointer(
                                child: AnimatedBuilder(
                                  animation: _shine,
                                  builder: (context, _) {
                                    // CSS: sweeps during first 20% of a 3s loop.
                                    final p =
                                        (_shine.value / 0.2).clamp(0.0, 1.0);
                                    return LayoutBuilder(
                                        builder: (context, c) {
                                      final x = (p * 2.5 - 1.5) * c.maxWidth;
                                      return Transform.translate(
                                        offset: Offset(x, 0),
                                        child: Transform(
                                          transform: Matrix4.skewX(-0.44),
                                          child: Container(
                                            width: c.maxWidth * 0.5,
                                            decoration: BoxDecoration(
                                              gradient: LinearGradient(
                                                colors: [
                                                  Colors.transparent,
                                                  AppColors.primary
                                                      .withValues(
                                                          alpha: 0.10),
                                                  Colors.transparent,
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      );
                                    });
                                  },
                                ),
                              ),
                            ),
                          ]),
                        ),
                      ),
                      const SizedBox(height: 32),
                      // Bento stats
                      Row(children: [
                        Expanded(
                          child: _BentoStat(
                            value: '${state.attempts}',
                            label: loc('attemptsLabel'),
                            icon: Icons.sync,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BentoStat(
                            value: '#1',
                            label: loc('rankLabel'),
                            icon: Icons.emoji_events,
                            color: AppColors.secondary,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: _BentoStat(
                            value: '${state.hintsUsed}',
                            label: loc('hintsLabel'),
                            icon: Icons.lightbulb_outline,
                          ),
                        ),
                      ]),
                      const SizedBox(height: 32),
                      // Closest guesses
                      if (closest.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 8),
                          child: Row(children: [
                            const Icon(Icons.history,
                                size: 16,
                                color: AppColors.onSurfaceVariant),
                            const SizedBox(width: 8),
                            Text(
                              loc('closestGuesses'),
                              style: AppTypography.labelMd.copyWith(
                                  color: AppColors.onSurfaceVariant),
                            ),
                          ]),
                        ),
                        const SizedBox(height: 8),
                        for (final g in closest)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 4),
                            child: _ClosestRow(guess: g, loc: loc),
                          ),
                        const SizedBox(height: 24),
                      ],
                      GlowButton(
                        label: loc('shareResult'),
                        icon: Icons.share,
                        onTap: _share,
                      ),
                      const SizedBox(height: 8),
                      GlassButton(
                        label: loc('playAgain'),
                        icon: Icons.refresh,
                        onTap: _startingNew ? null : _newGame,
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const Positioned.fill(child: ConfettiOverlay()),
          ],
        ),
      ),
    );
  }
}

class _BentoStat extends StatelessWidget {
  const _BentoStat({
    required this.value,
    required this.label,
    required this.icon,
    this.color = AppColors.onBackground,
  });

  final String value;
  final String label;
  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.20,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: AppColors.onSurface.withValues(alpha: 0.05)),
      padding: const EdgeInsets.all(16),
      child: Column(children: [
        Text(value,
            style: AppTypography.displaySm.copyWith(color: color)),
        const SizedBox(height: 4),
        Row(mainAxisAlignment: MainAxisAlignment.center, children: [
          Icon(icon, size: 14, color: AppColors.onSurfaceVariant),
          const SizedBox(width: 4),
          Flexible(
            child: Text(
              label,
              overflow: TextOverflow.ellipsis,
              style: AppTypography.labelXs
                  .copyWith(color: AppColors.onSurfaceVariant),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Closest-guess row from the solved design: fill bar behind the row sized
/// by closeness, an accent edge line, «رقم N» badge and the percent.
class _ClosestRow extends ConsumerWidget {
  const _ClosestRow({required this.guess, required this.loc});

  final GuessResult guess;
  final dynamic loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tier = Heat.tierFor(guess.rank);
    final accent = tier == HeatTier.blazing || tier == HeatTier.warm
        ? AppColors.secondary
        : AppColors.tertiary;
    final fraction = Heat.closeness(guess.rank, guess.totalWords);
    return ClipRRect(
      borderRadius: BorderRadius.circular(8),
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHigh.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
              color: AppColors.surfaceBright.withValues(alpha: 0.30)),
        ),
        child: Stack(children: [
          // Closeness fill
          Positioned.fill(
            child: FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: fraction,
              child: ColoredBox(
                  color: accent.withValues(alpha: 0.08)),
            ),
          ),
          // Accent edge line (start edge)
          PositionedDirectional(
            start: 0,
            top: 0,
            bottom: 0,
            child: Container(width: 4, color: accent),
          ),
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(guess.word,
                    style: AppTypography.bodySm
                        .copyWith(color: AppColors.onSurface)),
                Row(children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: accent.withValues(alpha: 0.10),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      '${loc('rankNo')} ${guess.rank}',
                      style:
                          AppTypography.labelXs.copyWith(color: accent),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    Heat.percentLabel(guess.rank, guess.totalWords),
                    style: AppTypography.labelMd
                        .copyWith(color: AppColors.onSurfaceVariant),
                  ),
                ]),
              ],
            ),
          ),
        ]),
      ),
    );
  }
}
