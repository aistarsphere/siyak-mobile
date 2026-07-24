import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// Animated heat/progress bar. The large variant (best-guess card) uses the
/// Stitch `gradient-fill` (#F59E0B → #FFBF00) with a moving shimmer overlay;
/// small history rows use a flat tier color.
class HeatBar extends StatefulWidget {
  const HeatBar({
    super.key,
    required this.fraction,
    this.color,
    this.height = 8,
    this.gradient = false,
    this.shimmer = false,
    this.glow = false,
  });

  /// Fill fraction in [0, 1].
  final double fraction;
  final Color? color;
  final double height;
  final bool gradient;
  final bool shimmer;
  final bool glow;

  @override
  State<HeatBar> createState() => _HeatBarState();
}

class _HeatBarState extends State<HeatBar> with SingleTickerProviderStateMixin {
  AnimationController? _shimmer;

  @override
  void initState() {
    super.initState();
    if (widget.shimmer) {
      _shimmer = AnimationController(vsync: this, duration: AppMotion.shimmer)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _shimmer?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(999),
      child: Container(
        height: widget.height,
        color: AppColors.surfaceContainerHigh,
        child: FractionallySizedBox(
          alignment: AlignmentDirectional.centerStart,
          widthFactor: widget.fraction.clamp(0.0, 1.0),
          child: TweenAnimationBuilder<double>(
            // Fill animates in on first build / when the value improves.
            tween: Tween(begin: 0, end: 1),
            duration: AppMotion.barFill,
            curve: AppMotion.easeOut,
            builder: (context, t, child) => FractionallySizedBox(
              alignment: AlignmentDirectional.centerStart,
              widthFactor: t,
              child: child,
            ),
            child: Container(
              decoration: BoxDecoration(
                color: widget.gradient
                    ? null
                    : (widget.color ?? AppColors.amber),
                gradient: widget.gradient ? AppColors.heatGradient : null,
                borderRadius: BorderRadius.circular(999),
                boxShadow: widget.glow
                    ? [
                        BoxShadow(
                          color: AppColors.amberGlow(0.5),
                          blurRadius: 10,
                        ),
                      ]
                    : const [],
              ),
              child: widget.shimmer && _shimmer != null
                  ? AnimatedBuilder(
                      animation: _shimmer!,
                      builder: (context, _) => LayoutBuilder(
                        builder: (context, constraints) {
                          final w = constraints.maxWidth;
                          final x = (_shimmer!.value * 2 - 1) * w * 1.5;
                          return ClipRect(
                            child: Transform.translate(
                              offset: Offset(x, 0),
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  gradient: LinearGradient(
                                    colors: [
                                      Colors.white.withValues(alpha: 0),
                                      Colors.white.withValues(alpha: 0.30),
                                      Colors.white.withValues(alpha: 0),
                                    ],
                                  ),
                                ),
                                child: const SizedBox.expand(),
                              ),
                            ),
                          );
                        },
                      ),
                    )
                  : null,
            ),
          ),
        ),
      ),
    );
  }
}
