import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'glass_panel.dart';
import 'pressable.dart';

/// Stitch TopAppBar: fixed glass bar (h-16, blur, hairline bottom border),
/// language button · glowing amber brand title · stats action.
class SiyaqTopBar extends StatelessWidget implements PreferredSizeWidget {
  const SiyaqTopBar({
    super.key,
    required this.title,
    this.onLanguageTap,
    this.trailing,
  });

  final String title;
  final VoidCallback? onLanguageTap;
  final Widget? trailing;

  @override
  Size get preferredSize => const Size.fromHeight(64);

  @override
  Widget build(BuildContext context) {
    final topPad = MediaQuery.paddingOf(context).top;
    return GlassPanel(
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
            start: 16, end: 16, top: topPad),
        child: Row(
          children: [
            Pressable(
              onTap: onLanguageTap,
              child: Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                child: const Icon(Icons.language,
                    size: 22, color: AppColors.onSurfaceVariant),
              ),
            ),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                style: AppTypography.displaySm.copyWith(
                  color: AppColors.primary,
                  shadows: AppTypography.amberTextGlow,
                ),
              ),
            ),
            SizedBox(width: 40, height: 40, child: trailing),
          ],
        ),
      ),
    );
  }
}
