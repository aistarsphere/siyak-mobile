import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/confetti_overlay.dart';
import '../siyag_shell.dart';

/// Victory screen: medal, the secret word, three stats, actions — under
/// confetti. Data is passed in (weekly or practice), keeping the screen
/// independent of any specific controller.
///
/// Built from the Siyaq design system. The entrance pop runs on
/// `context.motion` and collapses (with the confetti) under reduced motion.
class SiyagResultScreen extends ConsumerStatefulWidget {
  const SiyagResultScreen({
    super.key,
    required this.secretWord,
    required this.attempts,
    required this.hintsUsed,
    this.elapsed,
    this.showLeaderboard = true,
  });

  final String secretWord;
  final int attempts;
  final int hintsUsed;
  final Duration? elapsed;
  final bool showLeaderboard;

  @override
  ConsumerState<SiyagResultScreen> createState() => _SiyagResultScreenState();
}

class _SiyagResultScreenState extends ConsumerState<SiyagResultScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pop = AnimationController(
    vsync: this,
    duration: SiyaqMotion.reward,
    lowerBound: 0.6,
    upperBound: 1.0,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Duration depends on MediaQuery (reduced motion), so it is set here, not
    // in initState. Zero-duration forward() completes in one frame.
    _pop.duration = context.motion.reward;
    if (!_pop.isAnimating && _pop.value == _pop.lowerBound) _pop.forward();
  }

  @override
  void dispose() {
    _pop.dispose();
    super.dispose();
  }

  String _fmt(Duration? d) => d == null
      ? '—'
      : '${d.inMinutes}:${(d.inSeconds % 60).toString().padLeft(2, '0')}';

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: SiyaqSpacing.xxl,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _pop,
                        curve: SiyaqMotion.easeOutQuint,
                      ),
                      child: const Center(
                        child: SiyaqIconTile(
                          icon: SiyaqIcons.trophy,
                          size: SiyaqIconTileSize.large,
                          glow: true,
                        ),
                      ),
                    ),
                    const SizedBox(height: SiyaqSpacing.xl),
                    SiyaqText(
                      loc('solved').toUpperCase(),
                      role: SiyaqTextRole.labelSmall,
                      script: SiyaqScript.mono,
                      color: c.success,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: SiyaqSpacing.sm),
                    SiyaqText(
                      loc('theWordWas'),
                      role: SiyaqTextRole.bodyMedium,
                      color: c.textMuted,
                      align: TextAlign.center,
                    ),
                    const SizedBox(height: SiyaqSpacing.sm),
                    SiyaqText(
                      widget.secretWord,
                      role: SiyaqTextRole.displayLarge,
                      align: TextAlign.center,
                      header: true,
                    ),
                    const SizedBox(height: SiyaqSpacing.xxl),
                    SiyaqStatGrid(
                      columns: 3,
                      minCellWidth: 80,
                      children: [
                        SiyaqStatCard(
                          value: '${widget.attempts}',
                          label: loc('attemptsLabel'),
                          semanticLabel:
                              '${loc('attemptsLabel')}: ${widget.attempts}',
                        ),
                        SiyaqStatCard(
                          value: '${widget.hintsUsed}',
                          label: loc('hintsLabel'),
                          semanticLabel:
                              '${loc('hintsLabel')}: ${widget.hintsUsed}',
                        ),
                        SiyaqStatCard(
                          value: _fmt(widget.elapsed),
                          label: loc('elapsed'),
                          semanticLabel:
                              '${loc('elapsed')}: ${_fmt(widget.elapsed)}',
                        ),
                      ],
                    ),
                    const SizedBox(height: SiyaqSpacing.huge),
                    if (widget.showLeaderboard) ...[
                      SiyaqButton(
                        label: loc('viewMyRank'),
                        icon: SiyaqIcons.leaderboard,
                        accent: c.success,
                        fullWidth: true,
                        onPressed: () {
                          ref.read(siyagTabProvider.notifier).state = 1;
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                      const SizedBox(height: SiyaqSpacing.smd),
                    ],
                    SiyaqButton(
                      label: loc('returnHome'),
                      type: SiyaqButtonType.ghost,
                      fullWidth: true,
                      onPressed: () =>
                          Navigator.of(context).popUntil((r) => r.isFirst),
                    ),
                  ],
                ),
              ),
            ),
            const Positioned.fill(
              child: IgnorePointer(child: ConfettiOverlay()),
            ),
          ],
        ),
      ),
    );
  }
}
