import 'package:flutter/material.dart';

import '../../theme/siyag_theme.dart';
import 'siyag_tap.dart';

class SiyagNavItem {
  const SiyagNavItem({required this.icon, required this.label});
  final IconData icon;
  final String label;
}

/// Bottom navigation (App.tsx `BottomNav`): 3 destinations, top hairline,
/// active item coral with a small dot that slides between destinations.
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
    final bottomPad = MediaQuery.paddingOf(context).bottom;
    return Container(
      decoration: BoxDecoration(
        color: SC.bg,
        border: Border(top: BorderSide(color: SC.line)),
      ),
      padding: EdgeInsets.only(top: 8, bottom: 8 + bottomPad, left: 8, right: 8),
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
  const _NavButton(
      {required this.item, required this.active, required this.onTap});

  final SiyagNavItem item;
  final bool active;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    // Active tab uses the gold primary accent; inactive stays soft gray.
    final color = active ? SC.gold : SC.textMute;
    return SiyagTap(
      onTap: onTap,
      scale: 0.9,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 4),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              height: 6,
              child: AnimatedOpacity(
                duration: const Duration(milliseconds: 220),
                opacity: active ? 1 : 0,
                child: Container(
                  width: 6,
                  height: 6,
                  decoration:
                      BoxDecoration(color: SC.gold, shape: BoxShape.circle),
                ),
              ),
            ),
            const SizedBox(height: 2),
            Icon(item.icon, size: 21, color: color),
            const SizedBox(height: 4),
            Text(item.label, style: ST.ar(10, color: color)),
          ],
        ),
      ),
    );
  }
}
