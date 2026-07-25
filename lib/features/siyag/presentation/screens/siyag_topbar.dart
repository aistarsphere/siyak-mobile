import 'package:flutter/material.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';

/// Full-screen top bar (gameplay/weekly/multiplayer top bars): a circular back
/// button (chevron points to the trailing edge in RTL), a centered title or
/// kicker, and a balancing spacer. Live indicator optional.
class SiyagTopBar extends StatelessWidget {
  const SiyagTopBar({
    super.key,
    this.title,
    this.subtitle,
    this.kicker,
    this.kickerColor,
    this.onBack,
    this.trailing,
  });

  final String? title;
  final String? subtitle;
  final String? kicker;
  final Color? kickerColor;
  final VoidCallback? onBack;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
      child: Row(
        children: [
          SiyagTap(
            onTap: onBack ?? () => Navigator.of(context).maybePop(),
            scale: 0.9,
            child: Container(
              width: 36,
              height: 36,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: SC.surface,
                shape: BoxShape.circle,
              ),
              // RTL: back points to the right (chevron_right).
              child: Icon(Icons.chevron_right_rounded,
                  size: 18, color: SC.textDim),
            ),
          ),
          Expanded(
            child: Column(
              children: [
                if (kicker != null)
                  Text(kicker!.toUpperCase(),
                      style: ST.mono(10,
                          color: kickerColor ?? SC.textMute, letterSpacing: 1.8)),
                if (title != null)
                  Text(title!, style: ST.ar(14, weight: FontWeight.w500)),
                if (subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(subtitle!, style: ST.mono(10, color: SC.textMute)),
                ],
              ],
            ),
          ),
          SizedBox(width: 36, height: 36, child: trailing),
        ],
      ),
    );
  }
}
