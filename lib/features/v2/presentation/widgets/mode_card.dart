import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/pressable.dart';

/// A Home mode entry (Solo / Weekly / Multiplayer) in the Amber Noir language:
/// glass panel, leading glowing icon, title + description, a status line, and
/// a trailing chevron / disabled treatment. Fades/slides in.
class ModeCard extends StatelessWidget {
  const ModeCard({
    super.key,
    required this.icon,
    required this.title,
    required this.description,
    required this.onTap,
    this.status,
    this.statusColor,
    this.enabled = true,
    this.highlight = false,
    this.index = 0,
    this.trailing,
  });

  final IconData icon;
  final String title;
  final String description;
  final VoidCallback? onTap;
  final String? status;
  final Color? statusColor;
  final bool enabled;
  final bool highlight;
  final int index;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    final card = Pressable(
      onTap: enabled ? onTap : null,
      scale: AppMotion.ctaPressScale,
      duration: AppMotion.ctaPressDuration,
      child: Opacity(
        opacity: enabled ? 1 : 0.55,
        child: GlassPanel(
          opacity: highlight ? 0.30 : 0.20,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: highlight
                ? AppColors.primary.withValues(alpha: 0.6)
                : AppColors.surfaceBright.withValues(alpha: 0.5),
          ),
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                  boxShadow: highlight
                      ? [
                          BoxShadow(
                            color: AppColors.amberGlow(0.35),
                            blurRadius: 16,
                          ),
                        ]
                      : const [],
                ),
                child: Icon(icon, color: AppColors.primary, size: 26),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTypography.headlineMobile.copyWith(
                        color: AppColors.onSurface,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      description,
                      style: AppTypography.bodySm.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    if (status != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        status!,
                        style: AppTypography.labelMd.copyWith(
                          color: statusColor ?? AppColors.secondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              trailing ??
                  Icon(
                    Directionality.of(context) == TextDirection.rtl
                        ? Icons.chevron_left
                        : Icons.chevron_right,
                    color: AppColors.onSurfaceVariant,
                  ),
            ],
          ),
        ),
      ),
    );

    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.rowIn + Duration(milliseconds: 60 * index),
      curve: AppMotion.easeOut,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.translate(
          offset: Offset(0, 16 * (1 - t)),
          child: child,
        ),
      ),
      child: card,
    );
  }
}
