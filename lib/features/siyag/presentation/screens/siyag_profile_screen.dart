import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/installation_profile.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';

/// Profile (profile.tsx): identity, stats grid, edit-name. Wired to the live
/// anonymous V2 profile. No mock badges — stats are real; the raw id stays
/// hidden (short code / display name only).
class SiyagProfileScreen extends ConsumerWidget {
  const SiyagProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final async = ref.watch(profileControllerProvider);
    final profile = async.value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 40),
          Center(
            child: Column(
              children: [
                SiyagAvatar(
                  letter: (profile?.label.isNotEmpty ?? false)
                      ? profile!.label.characters.first
                      : 'س',
                  size: 80,
                  active: true,
                ),
                const SizedBox(height: 16),
                Text(profile?.label ?? '—',
                    style: ST.ar(22, weight: FontWeight.w600)),
                const SizedBox(height: 6),
                SiyagTap(
                  onTap: profile == null
                      ? null
                      : () => _editName(context, ref, profile),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.edit_rounded, size: 13, color: SC.coral),
                      const SizedBox(width: 6),
                      Text('تعديل الاسم', style: ST.ar(13, color: SC.coral)),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              _stat('${profile?.gamesPlayed ?? 0}', 'ألعاب'),
              const SizedBox(width: 8),
              _stat('${profile?.gamesSolved ?? 0}', 'حلول'),
              const SizedBox(width: 8),
              _stat('${profile?.roomsWon ?? 0}', 'غرف'),
              const SizedBox(width: 8),
              _stat(
                  profile?.weeklyBestPlacement != null
                      ? '#${profile!.weeklyBestPlacement}'
                      : '—',
                  'الأفضل'),
            ],
          ),
          const SizedBox(height: 24),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: SC.surface,
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                Icon(Icons.shield_outlined, size: 16, color: SC.textMute),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'هوية مجهولة على هذا الجهاز فقط — لا حساب ولا معرّف جهاز.',
                    style: ST.ar(12, color: SC.textMute),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 28),
          _AppearanceSelector(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Column(
            children: [
              Text(v, style: ST.mono(20)),
              const SizedBox(height: 6),
              Text(l, style: ST.ar(9, color: SC.textMute)),
            ],
          ),
        ),
      );

  Future<void> _editName(
      BuildContext context, WidgetRef ref, InstallationProfile p) async {
    final controller = TextEditingController(text: p.displayName ?? '');
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Directionality(
        textDirection: TextDirection.rtl,
        child: Padding(
          padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
          child: Container(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            decoration: BoxDecoration(
              color: SC.surface,
              borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
            ),
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
                        color: SC.textFaint,
                        borderRadius: BorderRadius.circular(999)),
                  ),
                ),
                Text('تعديل الاسم',
                    style: ST.ar(18, weight: FontWeight.w600)),
                const SizedBox(height: 12),
                TextField(
                  controller: controller,
                  maxLength: 24,
                  style: ST.ar(18),
                  decoration: InputDecoration(
                    hintText: 'اسمك',
                    hintStyle: ST.ar(18, color: SC.textFaint),
                    filled: true,
                    fillColor: SC.surfaceHi,
                    counterStyle: ST.mono(10, color: SC.textMute),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide(color: SC.coral, width: 2),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                SiyagPrimaryButton(
                  label: 'حفظ',
                  icon: Icons.check_rounded,
                  onTap: () async {
                    final name = controller.text.trim();
                    if (name.isNotEmpty) {
                      await ref
                          .read(profileControllerProvider.notifier)
                          .updateDisplayName(name);
                    }
                    if (ctx.mounted) Navigator.of(ctx).pop();
                  },
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// System / Light / Dark segmented selector. Persists via [AppSettings] and
/// applies immediately (no restart). The selected segment uses the restrained
/// gold accent as a "selected indicator".
class _AppearanceSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    const options = [
      (ThemeMode.system, 'themeSystem', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'themeLight', Icons.light_mode_rounded),
      (ThemeMode.dark, 'themeDark', Icons.dark_mode_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(loc('appearance')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SC.line),
          ),
          child: Row(
            children: [
              for (final (m, key, icon) in options)
                Expanded(
                  child: SiyagTap(
                    onTap: () =>
                        ref.read(appSettingsProvider.notifier).setThemeMode(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: m == mode ? SC.gold : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(icon,
                              size: 15,
                              color: m == mode ? SC.onGold : SC.textMute),
                          const SizedBox(width: 6),
                          Text(loc(key),
                              style: ST.ar(13,
                                  weight: FontWeight.w500,
                                  color: m == mode ? SC.onGold : SC.textDim)),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
