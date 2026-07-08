import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Stitch `.atmospheric-light`: a fixed radial amber glow bleeding from the
/// top of every screen —
/// `radial-gradient(circle at 50% -10%, rgba(255,191,0,0.12), transparent 70%)`.
class AtmosphericBackground extends StatelessWidget {
  const AtmosphericBackground({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(color: AppColors.background),
      child: Stack(
        children: [
          Positioned.fill(
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: RadialGradient(
                    center: const Alignment(0, -1.2),
                    radius: 1.4,
                    colors: [
                      AppColors.amberGlow(0.12),
                      AppColors.amberGlow(0.0),
                    ],
                    stops: const [0.0, 0.7],
                  ),
                ),
              ),
            ),
          ),
          child,
        ],
      ),
    );
  }
}
