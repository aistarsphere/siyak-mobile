import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/providers.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/hint_mode.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../siyag_route.dart';
import 'siyag_room_lobby_screen.dart';
import 'siyag_topbar.dart';

final _lang = StateProvider<GameplayLanguage>(
    (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang));
final _cat = StateProvider<String?>((ref) => null);
final _hint = StateProvider<HintMode>((ref) => HintMode.adaptive);
final _max = StateProvider<int>((ref) => 8);

/// Create room (missing flow, in-grammar). Wired to the live room repository.
class SiyagCreateRoomScreen extends ConsumerWidget {
  const SiyagCreateRoomScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final lang = ref.watch(_lang);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    final busy = ref.watch(roomLifecycleControllerProvider).busy;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              const SiyagTopBar(kicker: 'Create Room', kickerColor: SC.emerald),
              Expanded(
                child: modes.when(
                  loading: () => const Center(
                      child: CircularProgressIndicator(color: SC.coral)),
                  error: (e, _) => Center(
                      child: Text('تعذّر التحميل',
                          style: ST.ar(15, color: SC.textMute))),
                  data: (info) {
                    final cats = info.playable;
                    final selCat = ref.watch(_cat) ??
                        (cats.isNotEmpty ? cats.first.code : '');
                    return ListView(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                      children: [
                        _lbl('لغة اللعب'),
                        _wrap([
                          for (final l in GameplayLanguage.values)
                            _chip(l == GameplayLanguage.arabic ? 'العربية' : 'الإنجليزية',
                                l == lang, () {
                              ref.read(_lang.notifier).state = l;
                              ref.read(_cat.notifier).state = null;
                            }, SC.emerald),
                        ]),
                        _lbl('التصنيف'),
                        _wrap([
                          for (final c in cats)
                            _chip(c.labelFor(lang.code), c.code == selCat,
                                () => ref.read(_cat.notifier).state = c.code,
                                SC.emerald),
                        ]),
                        _lbl('نمط التلميح'),
                        _wrap([
                          for (final m in HintMode.values)
                            _chip(m == HintMode.adaptive ? 'تكيّفي' : 'عادي',
                                ref.watch(_hint) == m,
                                () => ref.read(_hint.notifier).state = m, SC.cyan),
                        ]),
                        _lbl('أقصى عدد لاعبين'),
                        _wrap([
                          for (final n in const [2, 4, 6, 8])
                            _chip('$n', ref.watch(_max) == n,
                                () => ref.read(_max.notifier).state = n, SC.coral),
                        ]),
                      ],
                    );
                  },
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: SiyagPrimaryButton(
                  label: 'إنشاء الغرفة',
                  color: SC.emerald,
                  icon: Icons.add_rounded,
                  busy: busy,
                  onTap: () async {
                    final info = modes.value;
                    if (info == null || info.playable.isEmpty) return;
                    final code = ref.read(_cat) ?? info.playable.first.code;
                    final room = await ref
                        .read(roomLifecycleControllerProvider.notifier)
                        .create(
                          language: lang,
                          category: code,
                          hintMode: ref.read(_hint),
                          maxPlayers: ref.read(_max),
                        );
                    if (room != null && context.mounted) {
                      Navigator.of(context).pushReplacement(
                          siyagRoute(const SiyagRoomLobbyScreen()));
                    } else if (context.mounted) {
                      final err =
                          ref.read(roomLifecycleControllerProvider).error;
                      if (err != null) {
                        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                            content: Text(ref
                                .read(localizationsProvider)
                                .errorMessage(err))));
                      }
                    }
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _lbl(String t) => Padding(
        padding: const EdgeInsets.only(top: 4, bottom: 8),
        child: Align(
            alignment: AlignmentDirectional.centerStart,
            child: Text(t, style: ST.ar(13, color: SC.textDim))),
      );

  Widget _wrap(List<Widget> c) => Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: Wrap(spacing: 8, runSpacing: 8, children: c),
      );

  Widget _chip(String label, bool sel, VoidCallback onTap, Color accent) =>
      SiyagTap(
        onTap: onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 160),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
          decoration: BoxDecoration(
            color: sel ? accent : SC.surface,
            borderRadius: BorderRadius.circular(999),
          ),
          child: Text(label, style: ST.ar(13, color: sel ? SC.bg : SC.textMute)),
        ),
      );
}
