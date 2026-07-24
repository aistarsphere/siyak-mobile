import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/selector_chip.dart';
import '../../domain/entities/gameplay_language.dart';

/// Choose the *gameplay content* language (Arabic/English) before a session.
/// This is separate from the app UI locale and gets locked once the session
/// is created.
class GameplayLanguageSelector extends ConsumerWidget {
  const GameplayLanguageSelector({
    super.key,
    required this.value,
    required this.onChanged,
  });

  final GameplayLanguage value;
  final ValueChanged<GameplayLanguage> onChanged;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    return Row(
      children: [
        for (final lang in GameplayLanguage.values) ...[
          SelectorChip(
            label: loc(lang.labelKey),
            selected: lang == value,
            onTap: () => onChanged(lang),
          ),
          const SizedBox(width: 8),
        ],
      ],
    );
  }
}
