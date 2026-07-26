import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/game_controller.dart';
import '../../../game/presentation/controllers/providers.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../siyag_route.dart';
import 'siyag_practice_game_screen.dart';
import 'siyag_topbar.dart';

final _practiceLangProvider = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final _practiceCatProvider = StateProvider<String?>((ref) => null);
final _practiceDiffProvider = StateProvider<String>((ref) => 'medium');

/// Solo Practice setup — choose game language + category + difficulty before
/// starting an unlimited V1 practice game (V1 fallback preserved).
class SiyagPracticeSetupScreen extends ConsumerWidget {
  const SiyagPracticeSetupScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = ref.watch(_practiceLangProvider);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    var busy = false;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(kicker: loc('modeSolo'), kickerColor: SC.cyan),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 300),
                  child: modes.when(
                    loading: () => Center(
                      child: CircularProgressIndicator(color: SC.coral),
                    ),
                    error: (e, _) => Center(
                      child: Text(
                        loc('somethingWrong'),
                        style: ST.ar(15, color: SC.textMute),
                      ),
                    ),
                    data: (info) {
                      final cats = info.playable;
                      final selCat =
                          ref.watch(_practiceCatProvider) ??
                          (cats.isNotEmpty ? cats.first.code : '');
                      final selDiff = ref.watch(_practiceDiffProvider);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                        children: [
                          _label(loc('chooseGameLang')),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final l in GameplayLanguage.values) ...[
                                _chip(
                                  l == GameplayLanguage.arabic
                                      ? loc('langArabic')
                                      : loc('langEnglish'),
                                  l == lang,
                                  () {
                                    ref
                                            .read(
                                              _practiceLangProvider.notifier,
                                            )
                                            .state =
                                        l;
                                    ref
                                            .read(_practiceCatProvider.notifier)
                                            .state =
                                        null;
                                  },
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                          const SizedBox(height: 20),
                          _label(loc('category')),
                          const SizedBox(height: 8),
                          Wrap(
                            spacing: 8,
                            runSpacing: 8,
                            children: [
                              for (final c in cats)
                                _chip(
                                  c.labelFor(lang.code),
                                  c.code == selCat,
                                  () =>
                                      ref
                                          .read(_practiceCatProvider.notifier)
                                          .state = c
                                          .code,
                                ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          _label(loc('difficulty')),
                          const SizedBox(height: 8),
                          Row(
                            children: [
                              for (final d in const [
                                'easy',
                                'medium',
                                'hard',
                              ]) ...[
                                _chip(
                                  d == 'easy'
                                      ? loc('diffEasy')
                                      : d == 'hard'
                                      ? loc('diffHard')
                                      : loc('diffMedium'),
                                  d == selDiff,
                                  () =>
                                      ref
                                              .read(
                                                _practiceDiffProvider.notifier,
                                              )
                                              .state =
                                          d,
                                  accent: SC.cyan,
                                ),
                                const SizedBox(width: 8),
                              ],
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: StatefulBuilder(
                  builder: (context, setLocal) {
                    return SiyagPrimaryButton(
                      label: loc('startGame'),
                      color: SC.cyan,
                      icon: Icons.play_arrow_rounded,
                      busy: busy,
                      onTap: () async {
                        final info = modes.value;
                        if (info == null || info.playable.isEmpty) return;
                        final code =
                            ref.read(_practiceCatProvider) ??
                            info.playable.first.code;
                        final cat = info.playable.firstWhere(
                          (c) => c.code == code,
                          orElse: () => info.playable.first,
                        );
                        setLocal(() => busy = true);
                        await ref
                            .read(gameControllerProvider.notifier)
                            .startNewGame(
                              language: lang.code,
                              category: cat.code,
                              categoryLabel: cat.labelFor(lang.code),
                              difficulty: ref.read(_practiceDiffProvider),
                            );
                        if (context.mounted) {
                          Navigator.of(context).pushReplacement(
                            siyagRoute(const SiyagPracticeGameScreen()),
                          );
                        }
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _label(String t) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: Text(t, style: ST.ar(13, color: SC.textDim)),
  );

  Widget _chip(
    String label,
    bool selected,
    VoidCallback onTap, {
    Color? accent,
  }) => SiyagTap(
    onTap: onTap,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      decoration: BoxDecoration(
        color: selected ? (accent ?? SC.coral) : SC.surface,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: ST.ar(
          13,
          color: selected ? SC.onColor(accent ?? SC.coral) : SC.textMute,
        ),
      ),
    ),
  );
}
