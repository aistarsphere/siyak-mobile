import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Home hero logo: 128 px rounded-2rem glass card with an amber glow ring
/// (`shadow-[0_0_25px_rgba(255,191,0,0.3)]`), holding the Stitch logo art.
class AppLogo extends StatelessWidget {
  const AppLogo({super.key, this.size = 128});

  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer.withValues(alpha: 0.30),
        borderRadius: BorderRadius.circular(32),
        border: Border.all(
          color: AppColors.surfaceBright.withValues(alpha: 0.40),
        ),
        boxShadow: [
          BoxShadow(color: AppColors.amberGlow(0.3), blurRadius: 25),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(28),
        child: Image.asset(
          'assets/images/logo.png',
          fit: BoxFit.cover,
          errorBuilder: (context, _, _) => const ColoredBox(
            color: AppColors.background,
            child: Icon(Icons.extension, color: AppColors.amber, size: 48),
          ),
        ),
      ),
    );
  }
}
