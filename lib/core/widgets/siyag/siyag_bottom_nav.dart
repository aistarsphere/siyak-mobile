import 'package:flutter/material.dart';

import '../../design/siyaq_design.dart';

class SiyagNavItem {
  const SiyagNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Bottom navigation: 3 destinations, top hairline, gold active state with a
/// small indicator dot.
///
/// Presentational migration onto the design system only — the 3-tab IA itself
/// is pinned on open product decision **D7** (audit §22) and is deliberately
/// unchanged here. Each destination is a proper semantics node announcing its
/// label and selection.
class SiyagBottomNav extends StatelessWidget {
  const SiyagBottomNav({
    super.key,
    required this.items,
    required this.index,
    required this.onChanged,
  });

  final List<SiyagNavItem> items;
  final int index;
  final ValueChanged<int> onChanged;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: c.background,
        border: Border(top: BorderSide(color: c.border)),
      ),
      padding: EdgeInsets.only(
        top: SiyaqSpacing.sm,
        bottom: SiyaqSpacing.sm + bottomPad,
        left: SiyaqSpacing.sm,
        right: SiyaqSpacing.sm,
      ),
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
    );
  }
}

class _NavButton extends StatelessWidget {
  const _NavButton({
    required this.item,
    required this.active,
    required this.onTap,
  });

  final SiyagNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    // Deeper gold for the active tab — higher contrast in both themes.
    final color = active ? c.primaryStrong : c.textMuted;
    return SiyaqPressable(
      onTap: onTap,
      selected: active,
      semanticLabel: item.label,
      pressScale: 0.9,
      enforceMinTarget: false,
      // Tab switches are navigation, not game actions.
      sound: false,
      builder: (context, state) => Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: SiyaqSpacing.xxl,
          vertical: SiyaqSpacing.xxs,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 6,
              child: AnimatedOpacity(
                duration: context.motion.quick,
                opacity: active ? 1 : 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration: BoxDecoration(
                    color: c.primary,
                    shape: BoxShape.circle,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Icon(item.icon, size: SiyaqIconSize.md, color: color),
            const SizedBox(height: SiyaqSpacing.xxs),
            SiyaqText(
              item.label,
              role: SiyaqTextRole.labelSmall,
              color: color,
              maxLines: 1,
            ),
          ],
        ),
      ),
    );
  }
}
