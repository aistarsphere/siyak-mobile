import 'package:flutter/material.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/game_controller.dart';
import 'glass_panel.dart';
import 'pressable.dart';

/// The "unknown word" inline card from Stitch: glass panel with a soft error
/// border and pulse, error icon, «هذه الكلمة غير موجودة في القاموس», then
/// «هل تقصد:» with amber suggestion chips.
class UnknownWordCard extends StatefulWidget {
  const UnknownWordCard({
    super.key,
    required this.state,
    required this.loc,
    required this.onSuggestionTap,
  });

  final UnknownWordState state;
  final AppLocalizations loc;
  final ValueChanged<String> onSuggestionTap;

  @override
  State<UnknownWordCard> createState() => _UnknownWordCardState();
}

class _UnknownWordCardState extends State<UnknownWordCard>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 2),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = widget.loc;
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return GlassPanel(
          opacity: 0.30,
          blur: 24,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: AppColors.error.withValues(alpha: 0.15 + 0.15 * t),
          ),
          padding: const EdgeInsets.all(16),
          child: child!,
        );
      },
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.only(top: 2),
            child:
                Icon(Icons.error_outline, size: 20, color: AppColors.error),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  loc('unknownWord'),
                  style: AppTypography.bodySm
                      .copyWith(color: AppColors.onSurface),
                ),
                const SizedBox(height: 12),
                Text(
                  widget.state.loading || widget.state.suggestions.isNotEmpty
                      ? loc('didYouMean')
                      : loc('errNoSuggestions'),
                  style: AppTypography.labelXs.copyWith(
                    color: AppColors.onSurfaceVariant.withValues(alpha: 0.8),
                  ),
                ),
                const SizedBox(height: 8),
                if (widget.state.loading)
                  const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.error),
                  )
                else
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final w in widget.state.suggestions)
                        Pressable(
                          onTap: () => widget.onSuggestionTap(w),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 16, vertical: 6),
                            decoration: BoxDecoration(
                              color: AppColors.surfaceContainerHighest
                                  .withValues(alpha: 0.6),
                              borderRadius: BorderRadius.circular(999),
                              border: Border.all(
                                color: AppColors.outline
                                    .withValues(alpha: 0.20),
                              ),
                            ),
                            child: Text(
                              w,
                              style: AppTypography.labelMd
                                  .copyWith(color: AppColors.primary),
                            ),
                          ),
                        ),
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
