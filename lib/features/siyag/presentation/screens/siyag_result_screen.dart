import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/theme/context_tokens.dart';
import '../../../../core/design/theme/legacy_type_bridge.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/confetti_overlay.dart';
import '../siyag_shell.dart';

/// Result screen (result.tsx): emerald medal, secret word, 3 stats, actions.
/// Confetti in the coral/cyan/emerald palette. Data is passed in (weekly or
/// practice), keeping the screen independent of any specific controller.
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
    duration: const Duration(milliseconds: 600),
    lowerBound: 0.6,
    upperBound: 1.0,
  )..forward();

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
    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: context.colors.background,
        body: Stack(
          children: [
            SafeArea(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ScaleTransition(
                      scale: CurvedAnimation(
                        parent: _pop,
                        curve: Curves.easeOutBack,
                      ),
                      child: Center(
                        child: Container(
                          width: 80,
                          height: 80,
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: context.colors.success,
                            borderRadius: BorderRadius.circular(24),
                          ),
                          child: const Text(
                            '🎉',
                            style: TextStyle(fontSize: 38),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Kicker(
                        loc('solved'),
                        color: context.colors.success,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        loc('theWordWas'),
                        style: context.legacyType.ar(
                          16,
                          color: context.colors.textMuted,
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Center(
                      child: Text(
                        widget.secretWord,
                        textAlign: TextAlign.center,
                        style: context.legacyType.ar(
                          52,
                          weight: FontWeight.w700,
                          height: 1,
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                    Row(
                      children: [
                        _stat(
                          context,
                          '${widget.attempts}',
                          loc('attemptsLabel'),
                        ),
                        const SizedBox(width: 12),
                        _stat(
                          context,
                          '${widget.hintsUsed}',
                          loc('hintsLabel'),
                        ),
                        const SizedBox(width: 12),
                        _stat(context, _fmt(widget.elapsed), loc('elapsed')),
                      ],
                    ),
                    const SizedBox(height: 40),
                    if (widget.showLeaderboard)
                      SiyagPrimaryButton(
                        label: loc('viewMyRank'),
                        color: context.colors.success,
                        onTap: () {
                          ref.read(siyagTabProvider.notifier).state = 1;
                          Navigator.of(context).popUntil((r) => r.isFirst);
                        },
                      ),
                    if (widget.showLeaderboard) const SizedBox(height: 10),
                    SiyagGhostButton(
                      label: loc('returnHome'),
                      onTap: () =>
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

  Widget _stat(BuildContext context, String v, String l) => Expanded(
    child: Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      decoration: BoxDecoration(
        color: context.colors.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(v, style: context.legacyType.mono(26)),
          const SizedBox(height: 6),
          Text(
            l,
            style: context.legacyType.ar(11, color: context.colors.textMuted),
          ),
        ],
      ),
    ),
  );
}
