import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/widgets/atmospheric_background.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/pressable.dart';

/// Amber Noir scaffold for pushed V2 screens: atmospheric background + a glass
/// top bar with a directional back button and a glowing amber title.
class V2Scaffold extends StatelessWidget {
  const V2Scaffold({
    super.key,
    required this.title,
    required this.child,
    this.trailing,
    this.onBack,
  });

  final String title;
  final Widget child;
  final Widget? trailing;
  final VoidCallback? onBack;

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    final rtl = Directionality.of(context) == TextDirection.rtl;
    return Scaffold(
      body: AtmosphericBackground(
        child: Column(
          children: [
            GlassPanel(
              opacity: 0.10,
              blur: 24,
              borderRadius: BorderRadius.zero,
              border: Border(
                bottom: BorderSide(
                  color: AppColors.onSurface.withValues(alpha: 0.05),
                ),
              ),
              child: Container(
                height: 64 + topPad,
                padding: EdgeInsetsDirectional.only(
                  start: 8,
                  end: 8,
                  top: topPad,
                ),
                child: Row(
                  children: [
                    Pressable(
                      onTap: onBack ?? () => Navigator.of(context).maybePop(),
                      child: SizedBox(
                        width: 44,
                        height: 44,
                        child: Icon(
                          rtl ? Icons.arrow_forward : Icons.arrow_back,
                          color: AppColors.onSurfaceVariant,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Text(
                        title,
                        textAlign: TextAlign.center,
                        style: AppTypography.headlineMobile.copyWith(
                          color: AppColors.primary,
                          shadows: AppTypography.amberTextGlow,
                        ),
                      ),
                    ),
                    SizedBox(width: 44, height: 44, child: trailing),
                  ],
                ),
              ),
            ),
            Expanded(child: child),
          ],
        ),
      ),
    );
  }
}
