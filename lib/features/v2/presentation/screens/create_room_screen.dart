import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/providers.dart';
import '../../../game/presentation/widgets/glow_button.dart';
import '../../../game/presentation/widgets/selector_chip.dart';
import '../../domain/entities/gameplay_language.dart';
import '../../domain/entities/hint_mode.dart';
import '../controllers/capabilities_controller.dart';
import '../controllers/room_controller.dart';
import '../widgets/gameplay_language_selector.dart';
import '../widgets/hint_mode_selector.dart';
import '../widgets/v2_scaffold.dart';
import 'room_lobby_screen.dart';

final _createLangProvider = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final _createHintProvider = StateProvider<HintMode>((ref) => HintMode.standard);
final _createCategoryProvider = StateProvider<String?>((ref) => null);
final _createMaxPlayersProvider = StateProvider<int>((ref) => 4);

class CreateRoomScreen extends ConsumerWidget {
  const CreateRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = ref.watch(_createLangProvider);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    final adaptive =
        ref.watch(capabilitiesProvider).value?.adaptiveHintsEnabled ?? false;
    final busy = ref.watch(roomLifecycleControllerProvider).busy;

    return V2Scaffold(
      title: loc('createRoom'),
      child: modes.when(
        loading: () => const Center(
          child: CircularProgressIndicator(color: AppColors.amber),
        ),
        error: (e, _) => Center(
          child: Text(
            loc.errorMessage(e),
            style: AppTypography.bodySm.copyWith(color: AppColors.error),
          ),
        ),
        data: (info) {
          final categories = info.playable;
          final selected =
              ref.watch(_createCategoryProvider) ??
              (categories.isNotEmpty ? categories.first.code : '');
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _label(loc('chooseGameLang')),
              const SizedBox(height: 8),
              GameplayLanguageSelector(
                value: lang,
                onChanged: (l) {
                  ref.read(_createLangProvider.notifier).state = l;
                  ref.read(_createCategoryProvider.notifier).state = null;
                },
              ),
              const SizedBox(height: 16),
              _label(loc('category')),
              const SizedBox(height: 8),
              SizedBox(
                height: 44,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  itemCount: categories.length,
                  separatorBuilder: (_, _) => const SizedBox(width: 8),
                  itemBuilder: (context, i) {
                    final c = categories[i];
                    return SelectorChip(
                      label: c.labelFor(lang.code),
                      selected: c.code == selected,
                      onTap: () =>
                          ref.read(_createCategoryProvider.notifier).state =
                              c.code,
                    );
                  },
                ),
              ),
              const SizedBox(height: 16),
              _label(loc('hintMode')),
              const SizedBox(height: 8),
              HintModeSelector(
                value: ref.watch(_createHintProvider),
                adaptiveEnabled: adaptive,
                onChanged: (m) =>
                    ref.read(_createHintProvider.notifier).state = m,
              ),
              const SizedBox(height: 16),
              _label(loc('maxPlayers')),
              const SizedBox(height: 8),
              Row(
                children: [
                  for (final n in const [2, 4, 6, 8]) ...[
                    SelectorChip(
                      label: '$n',
                      selected: ref.watch(_createMaxPlayersProvider) == n,
                      accent: ChipAccent.secondary,
                      onTap: () =>
                          ref.read(_createMaxPlayersProvider.notifier).state =
                              n,
                    ),
                    const SizedBox(width: 8),
                  ],
                ],
              ),
              const SizedBox(height: 24),
              GlowButton(
                label: loc('createRoom'),
                icon: Icons.add,
                busy: busy,
                onTap: () async {
                  final room = await ref
                      .read(roomLifecycleControllerProvider.notifier)
                      .create(
                        language: lang,
                        category: selected,
                        hintMode: ref.read(_createHintProvider),
                        maxPlayers: ref.read(_createMaxPlayersProvider),
                      );
                  if (room != null && context.mounted) {
                    Navigator.of(context).pushReplacement(
                      MaterialPageRoute(
                        builder: (_) => const RoomLobbyScreen(),
                      ),
                    );
                  } else if (context.mounted) {
                    final err = ref.read(roomLifecycleControllerProvider).error;
                    if (err != null) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(loc.errorMessage(err))),
                      );
                    }
                  }
                },
              ),
            ],
          );
        },
      ),
    );
  }

  Widget _label(String t) => Builder(
    builder: (context) => Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: Text(
        t,
        style: AppTypography.labelMd.copyWith(
          color: AppColors.onSurface.withValues(alpha: 0.8),
        ),
      ),
    ),
  );
}
