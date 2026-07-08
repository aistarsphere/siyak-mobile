import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';
import '../../../../core/theme/app_typography.dart';
import 'pressable.dart';

/// Autocomplete chips row under the input (Stitch gameplay screen):
/// horizontal scroll, `bg-surface-variant/50` pills with hairline border.
/// Chips fade/slide in when the suggestion set changes.
class SuggestionChips extends StatelessWidget {
  const SuggestionChips({
    super.key,
    required this.words,
    required this.onTap,
  });

  final List<String> words;
  final ValueChanged<String> onTap;

  @override
  Widget build(BuildContext context) {
    return AnimatedSwitcher(
      duration: AppMotion.rowIn,
      switchInCurve: AppMotion.easeOut,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween<Offset>(
            begin: const Offset(0, 0.4),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: words.isEmpty
          ? const SizedBox(height: 0, key: ValueKey('empty'))
          : SizedBox(
              key: ValueKey(words.join('|')),
              height: 40,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: words.length,
                separatorBuilder: (_, _) => const SizedBox(width: 8),
                itemBuilder: (context, i) => Pressable(
                  onTap: () => onTap(words[i]),
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 8),
                    decoration: BoxDecoration(
                      color: AppColors.surfaceVariant.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(999),
                      border: Border.all(
                        color: AppColors.onSurface.withValues(alpha: 0.10),
                      ),
                    ),
                    child: Center(
                      child: Text(
                        words[i],
                        style: AppTypography.labelMd
                            .copyWith(color: AppColors.onSurface),
                      ),
                    ),
                  ),
                ),
              ),
            ),
    );
  }
}
