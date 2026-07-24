import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/widgets/glass_panel.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../controllers/profile_controller.dart';

/// First-run (or edit) display-name sheet. Optional — the user can skip and
/// keep their fallback short code. Never mentions login or the installation ID.
class ProfileSetupSheet extends ConsumerStatefulWidget {
  const ProfileSetupSheet({super.key});

  static Future<void> show(BuildContext context) => showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const ProfileSetupSheet(),
  );

  @override
  ConsumerState<ProfileSetupSheet> createState() => _ProfileSetupSheetState();
}

class _ProfileSetupSheetState extends ConsumerState<ProfileSetupSheet> {
  late final TextEditingController _controller = TextEditingController(
    text: ref.read(profileControllerProvider).value?.displayName ?? '',
  );
  bool _saving = false;

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final name = _controller.text.trim();
    if (name.isEmpty) {
      Navigator.of(context).pop();
      return;
    }
    setState(() => _saving = true);
    await ref.read(profileControllerProvider.notifier).updateDisplayName(name);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final bottom = MediaQuery.viewInsetsOf(context).bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: bottom),
      child: GlassPanel(
        opacity: 0.6,
        blur: 24,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border(
          top: BorderSide(color: AppColors.primary.withValues(alpha: 0.3)),
        ),
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.4),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
            ),
            Text(
              loc('setNameTitle'),
              style: AppTypography.headlineMobile.copyWith(
                color: AppColors.onSurface,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              loc('setNameBody'),
              style: AppTypography.bodySm.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _controller,
              maxLength: 24,
              style: AppTypography.bodyLg.copyWith(color: AppColors.onSurface),
              decoration: InputDecoration(
                hintText: loc('setNameHint'),
                hintStyle: AppTypography.bodyLg.copyWith(
                  color: AppColors.onSurfaceVariant.withValues(alpha: 0.5),
                ),
                filled: true,
                fillColor: AppColors.surfaceContainerLow.withValues(alpha: 0.8),
                counterStyle: AppTypography.labelXs.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(color: AppColors.outlineVariant),
                ),
                focusedBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(12),
                  borderSide: const BorderSide(
                    color: AppColors.amber,
                    width: 2,
                  ),
                ),
              ),
              onSubmitted: (_) => _save(),
            ),
            const SizedBox(height: 8),
            Text(
              loc('privacyNote'),
              style: AppTypography.labelXs.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: 16),
            GlowButton(
              label: loc('save'),
              icon: Icons.check,
              busy: _saving,
              onTap: _save,
            ),
            const SizedBox(height: 8),
            GlassButton(
              label: loc('skip'),
              onTap: () => Navigator.of(context).pop(),
            ),
          ],
        ),
      ),
    );
  }
}
