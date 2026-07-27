import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_icon_button.dart';
import '../foundation/siyaq_text.dart';

/// Screen header: a mono kicker over a large title, with optional back and
/// trailing actions.
///
/// Covers Figma's `Siyaq/Top App Bar` (`Home` / `Detail`) and replaces
/// `SiyagScreenHeader`, which hardcoded `fromLTRB(24, 48, 24, 16)` and a 30px
/// title (audit §5).
///
/// [onBack] renders a direction-correct back affordance: the glyph declares
/// `matchTextDirection`, so Flutter mirrors it for RTL. The old top bar hardcoded
/// a right-pointing chevron, which pointed the wrong way in LTR.
class SiyaqScreenHeader extends StatelessWidget {
  const SiyaqScreenHeader({
    super.key,
    this.title,
    this.kicker,
    this.onBack,
    this.backLabel,
    this.trailing,
    this.accent,
    this.padding,
  });

  /// Large screen title. Optional: a full-screen flow whose content already
  /// carries the heading (e.g. a hero card) should pass only [kicker], which is
  /// how the pre-migration top bar behaved.
  final String? title;

  /// Small mono label above the title — the section name.
  final String? kicker;

  final VoidCallback? onBack;

  /// Accessible name for the back button. Required in practice when [onBack] is
  /// set, or a screen reader announces an unlabelled button.
  final String? backLabel;

  final Widget? trailing;

  /// Tints the kicker — e.g. a game-mode accent.
  final Color? accent;

  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding:
          padding ??
          const EdgeInsets.fromLTRB(
            SiyaqSpacing.xxl,
            SiyaqSpacing.huge2,
            SiyaqSpacing.xxl,
            SiyaqSpacing.lg,
          ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          if (onBack != null) ...[
            SiyaqIconButton(
              // `arrow_back` declares matchTextDirection, so Flutter mirrors it
              // in RTL automatically. Picking `arrow_forward` for RTL by hand
              // double-flips it and the arrow ends up pointing the wrong way.
              icon: Icons.arrow_back_rounded,
              semanticLabel: backLabel ?? 'Back',
              onPressed: onBack,
            ),
            const SizedBox(width: SiyaqSpacing.sm),
          ],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                if (kicker != null) ...[
                  SiyaqText(
                    kicker!.toUpperCase(),
                    role: SiyaqTextRole.labelSmall,
                    script: SiyaqScript.mono,
                    color: accent ?? c.textMuted,
                  ),
                  if (title != null) const SizedBox(height: SiyaqSpacing.xxs),
                ],
                if (title != null)
                  SiyaqText(title!, role: SiyaqTextRole.displaySmall),
              ],
            ),
          ),
          if (trailing != null) ...[
            const SizedBox(width: SiyaqSpacing.md),
            trailing!,
          ],
        ],
      ),
    );
  }
}
