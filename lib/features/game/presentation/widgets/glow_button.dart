import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import 'glass_panel.dart';
import 'pressable.dart';

/// Primary CTA from Stitch: full-width, h-14, amber container, glow shadow
/// `0 0 20px rgba(255,191,0,0.35)`, icon + headline, press scale 0.98.
class GlowButton extends StatelessWidget {
  const GlowButton({
    super.key,
    required this.label,
    this.icon,
    this.onTap,
    this.busy = false,
  });

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;
  final bool busy;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: busy ? null : onTap,
      scale: AppMotion.ctaPressScale,
      duration: AppMotion.ctaPressDuration,
      child: AnimatedOpacity(
        duration: AppMotion.focus,
        opacity: onTap == null && !busy ? 0.5 : 1,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: AppColors.primaryContainer,
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(color: AppColors.amberGlow(0.35), blurRadius: 20),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (busy)
                const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.4,
                    color: AppColors.onPrimaryContainer,
                  ),
                )
              else if (icon != null)
                Icon(icon, color: AppColors.onPrimaryContainer, size: 24),
              if (icon != null || busy) const SizedBox(width: 8),
              Text(
                label,
                style: AppTypography.headlineMobile.copyWith(
                  color: AppColors.onPrimaryContainer,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Secondary CTA: glass surface, outline border, amber text.
class GlassButton extends StatelessWidget {
  const GlassButton({super.key, required this.label, this.icon, this.onTap});

  final String label;
  final IconData? icon;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      scale: AppMotion.ctaPressScale,
      duration: AppMotion.ctaPressDuration,
      child: AnimatedOpacity(
        duration: AppMotion.focus,
        opacity: onTap == null ? 0.5 : 1,
        child: SizedBox(
          height: 56,
          child: GlassPanel(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: AppColors.outline),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (icon != null) ...[
                  Icon(icon, color: AppColors.primary, size: 24),
                  const SizedBox(width: 8),
                ],
                Text(
                  label,
                  style: AppTypography.headlineMobile.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
