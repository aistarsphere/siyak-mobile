import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_typography.dart';
import '../controllers/app_settings_controller.dart';
import '../controllers/stats_controller.dart';
import '../widgets/glass_panel.dart';
import '../widgets/pressable.dart';
import '../widgets/selector_chip.dart';
import '../widgets/top_app_bar.dart';

/// الإحصائيات tab: local stats bento (design language of the Home mini-bento)
/// followed by settings — language, sound, haptics, and a developer-only
/// backend URL override.
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  bool _devExpanded = false;
  late final TextEditingController _urlController;

  @override
  void initState() {
    super.initState();
    // Must init eagerly: a lazy `late` field first touched in dispose()
    // would call ref.read on an unmounted widget.
    _urlController = TextEditingController(
        text: ref.read(appSettingsProvider).baseUrlOverride);
  }

  @override
  void dispose() {
    _urlController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final settings = ref.watch(appSettingsProvider);
    final stats = ref.watch(statsProvider);

    return Column(
      children: [
        SiyaqTopBar(
          title: loc('appTitle'),
          onLanguageTap: () =>
              ref.read(appSettingsProvider.notifier).toggleLang(),
        ),
        Expanded(
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 128),
            children: [
              Text(loc('stats'),
                  style: AppTypography.headlineMobile
                      .copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                    child: _MiniStat(
                        label: loc('gamesPlayed'),
                        value: '${stats.gamesPlayed}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniStat(
                        label: loc('gamesSolved'),
                        value: '${stats.gamesSolved}')),
              ]),
              const SizedBox(height: 8),
              Row(children: [
                Expanded(
                    child: _MiniStat(
                        label: loc('prevAttempts'),
                        value: '${stats.totalAttempts}')),
                const SizedBox(width: 8),
                Expanded(
                    child: _MiniStat(
                        label: loc('bestScore'),
                        value: stats.bestRank == 0
                            ? '—'
                            : '#${stats.bestRank}',
                        amber: true)),
              ]),
              const SizedBox(height: 32),
              Text(loc('settings'),
                  style: AppTypography.headlineMobile
                      .copyWith(color: AppColors.onSurface)),
              const SizedBox(height: 12),
              // Language
              _SettingsTile(
                icon: Icons.language,
                title: loc('language'),
                trailing: Row(mainAxisSize: MainAxisSize.min, children: [
                  SelectorChip(
                    label: 'العربية',
                    selected: settings.lang == 'ar',
                    onTap: () => ref
                        .read(appSettingsProvider.notifier)
                        .setLang('ar'),
                  ),
                  const SizedBox(width: 8),
                  SelectorChip(
                    label: 'English',
                    selected: settings.lang == 'en',
                    onTap: () => ref
                        .read(appSettingsProvider.notifier)
                        .setLang('en'),
                  ),
                ]),
              ),
              const SizedBox(height: 8),
              // Sound
              _SettingsTile(
                icon: Icons.volume_up_outlined,
                title: loc('sound'),
                trailing: Switch(
                  value: settings.sound,
                  activeThumbColor: AppColors.onPrimaryContainer,
                  activeTrackColor: AppColors.primaryContainer,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).setSound(v),
                ),
              ),
              const SizedBox(height: 8),
              // Haptics
              _SettingsTile(
                icon: Icons.vibration,
                title: loc('haptics'),
                trailing: Switch(
                  value: settings.haptics,
                  activeThumbColor: AppColors.onPrimaryContainer,
                  activeTrackColor: AppColors.primaryContainer,
                  onChanged: (v) =>
                      ref.read(appSettingsProvider.notifier).setHaptics(v),
                ),
              ),
              const SizedBox(height: 8),
              // Developer: backend URL override
              _SettingsTile(
                icon: Icons.dns_outlined,
                title: loc('devServer'),
                trailing: Icon(
                  _devExpanded ? Icons.expand_less : Icons.expand_more,
                  color: AppColors.onSurfaceVariant,
                ),
                onTap: () => setState(() => _devExpanded = !_devExpanded),
              ),
              if (_devExpanded) ...[
                const SizedBox(height: 8),
                GlassPanel(
                  opacity: 0.20,
                  borderRadius: BorderRadius.circular(12),
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Directionality(
                        textDirection: TextDirection.ltr,
                        child: TextField(
                          controller: _urlController,
                          style: AppTypography.bodySm
                              .copyWith(color: AppColors.onSurface),
                          keyboardType: TextInputType.url,
                          decoration: InputDecoration(
                            hintText: 'https://…',
                            hintStyle: AppTypography.bodySm.copyWith(
                                color: AppColors.onSurfaceVariant
                                    .withValues(alpha: 0.5)),
                            enabledBorder: const UnderlineInputBorder(
                              borderSide: BorderSide(
                                  color: AppColors.outlineVariant),
                            ),
                            focusedBorder: const UnderlineInputBorder(
                              borderSide:
                                  BorderSide(color: AppColors.amber),
                            ),
                          ),
                          onSubmitted: (v) => ref
                              .read(appSettingsProvider.notifier)
                              .setBaseUrlOverride(v),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        loc('devServerHint'),
                        style: AppTypography.labelXs
                            .copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
    required this.label,
    required this.value,
    this.amber = false,
  });

  final String label;
  final String value;
  final bool amber;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      opacity: 0.20,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
        color: amber
            ? AppColors.primary.withValues(alpha: 0.20)
            : AppColors.surfaceBright.withValues(alpha: 0.50),
      ),
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label,
              style: AppTypography.labelXs
                  .copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 4),
          Text(
            value,
            style: AppTypography.displaySm.copyWith(
              color: amber ? AppColors.primary : AppColors.onSurface,
              shadows: amber ? AppTypography.amberTextGlow : null,
            ),
          ),
        ],
      ),
    );
  }
}

class _SettingsTile extends StatelessWidget {
  const _SettingsTile({
    required this.icon,
    required this.title,
    required this.trailing,
    this.onTap,
  });

  final IconData icon;
  final String title;
  final Widget trailing;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final tile = GlassPanel(
      opacity: 0.20,
      borderRadius: BorderRadius.circular(12),
      border: Border.all(
          color: AppColors.surfaceBright.withValues(alpha: 0.50)),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(children: [
        Icon(icon, size: 20, color: AppColors.primary.withValues(alpha: 0.7)),
        const SizedBox(width: 12),
        Expanded(
          child: Text(title,
              style: AppTypography.bodySm
                  .copyWith(color: AppColors.onSurface)),
        ),
        trailing,
      ]),
    );
    return onTap != null ? Pressable(onTap: onTap, child: tile) : tile;
  }
}
