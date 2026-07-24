import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import 'glass_panel.dart';
import 'pressable.dart';

class SiyaqNavItem {
  const SiyaqNavItem({
    required this.icon,
    required this.filledIcon,
    required this.label,
  });

  final IconData icon;
  final IconData filledIcon;
  final String label;
}

/// Stitch BottomNavBar: glass, rounded top corners, h-20; active tab in
/// amber with glow + a small glowing indicator pill above the icon.
class SiyaqBottomNav extends StatelessWidget {
  const SiyaqBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<SiyaqNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return GlassPanel(
      opacity: 0.10,
      blur: 24,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
      border: Border(
        top: BorderSide(color: AppColors.onSurface.withValues(alpha: 0.05)),
      ),
      child: SizedBox(
        height: 80 + bottomPad,
        child: Padding(
          padding: EdgeInsets.only(bottom: bottomPad),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              for (var i = 0; i < items.length; i++)
                _NavButton(
                  item: items[i],
                  active: i == index,
                  onTap: () => onChanged(i),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SiyaqNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final color = active ? AppColors.primary : AppColors.onSurfaceVariant;
    return Pressable(
      onTap: onTap,
      scale: 0.90,
      duration: const Duration(milliseconds: 200),
      child: SizedBox(
        width: 72,
        height: 72,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Active indicator: glowing pill at the top edge.
            AnimatedPositioned(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeOut,
              top: active ? 0 : -6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 250),
                opacity: active ? 1 : 0,
                child: Container(
                  width: 32,
                  height: 4,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    borderRadius: const BorderRadius.vertical(
                      bottom: Radius.circular(999),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.amberGlow(0.8),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                DecoratedBox(
                  decoration: active
                      ? BoxDecoration(
                          boxShadow: [
                            BoxShadow(
                              color: AppColors.amberGlow(0.4),
                              blurRadius: 10,
                            ),
                          ],
                        )
                      : const BoxDecoration(),
                  child: Icon(
                    active ? item.filledIcon : item.icon,
                    color: color,
                    size: active ? 28 : 24,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  item.label,
                  style: AppTypography.labelMd.copyWith(
                    color: color,
                    fontWeight: active ? FontWeight.w700 : FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
