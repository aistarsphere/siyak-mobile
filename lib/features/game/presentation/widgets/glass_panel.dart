import 'dart:ui';

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';

/// Stitch `.glass-panel`: translucent surface + backdrop blur + hairline
/// top border (`rgba(36,31,20,α)` + `blur(12px)` + `border-top white/5%`).
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.opacity = 0.20,
    this.blur = 12,
    this.borderRadius = const BorderRadius.all(Radius.circular(12)),
    this.border,
    this.padding,
    this.color,
  });

  final Widget child;
  final double opacity;
  final double blur;
  final BorderRadius borderRadius;
  final BoxBorder? border;
  final EdgeInsetsGeometry? padding;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: borderRadius,
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: blur, sigmaY: blur),
        child: Container(
          padding: padding,
          decoration: BoxDecoration(
            color: (color ?? AppColors.surfaceContainer)
                .withValues(alpha: opacity),
            borderRadius: borderRadius,
            border: border ??
                Border(
                  top: BorderSide(
                    color: Colors.white.withValues(alpha: 0.05),
                  ),
                ),
          ),
          child: child,
        ),
      ),
    );
  }
}
