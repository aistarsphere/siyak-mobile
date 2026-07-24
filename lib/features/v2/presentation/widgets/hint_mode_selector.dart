import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/selector_chip.dart';
import '../../domain/entities/hint_mode.dart';

/// Chooses the hint mode before a session, with a short explanation line for
/// the selected mode (the adaptive explanation, never the raw formula).
class HintModeSelector extends ConsumerWidget {
  const HintModeSelector({
    super.key,
    required this.value,
    required this.onChanged,
    this.adaptiveEnabled = true,
  });

  final HintMode value;
  final ValueChanged<HintMode> onChanged;
  final bool adaptiveEnabled;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final modes = adaptiveEnabled ? HintMode.values : [HintMode.standard];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            for (final m in modes) ...[
              SelectorChip(
                label: loc(m.labelKey),
                selected: m == value,
                accent: ChipAccent.secondary,
                onTap: () => onChanged(m),
              ),
              const SizedBox(width: 8),
            ],
          ],
        ),
        const SizedBox(height: 6),
        Text(
          loc(value.explanationKey),
          style: AppTypography.labelXs.copyWith(
            color: AppColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
