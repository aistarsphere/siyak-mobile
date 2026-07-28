import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/game_controller.dart';
import '../../../game/presentation/controllers/providers.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../siyag_route.dart';
import 'siyag_practice_game_screen.dart';

final _practiceLangProvider = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final _practiceCatProvider = StateProvider<String?>((ref) => null);
final _practiceDiffProvider = StateProvider<String>((ref) => 'medium');

/// Whether the start call is in flight — a proper provider instead of the old
/// `var busy` mutated through a StatefulBuilder, which reset on any parent
/// rebuild and could double-fire the start action.
final _practiceStartingProvider = StateProvider<bool>((ref) => false);

/// Solo Practice setup — game language, category and difficulty before an
/// unlimited practice game (V1 fallback preserved).
///
/// Built from the Siyaq design system. The catalogue call, provider wiring and
/// navigation are unchanged from the pre-migration implementation; the error
/// state gained a retry it never had.
class SiyagPracticeSetupScreen extends ConsumerWidget {
  const SiyagPracticeSetupScreen({super.key});

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    final lang = ref.read(_practiceLangProvider);
    final info = ref.read(modesByLanguageProvider(lang.code)).value;
    if (info == null || info.playable.isEmpty) return;
    if (ref.read(_practiceStartingProvider)) return;

    final code = ref.read(_practiceCatProvider) ?? info.playable.first.code;
    final cat = info.playable.firstWhere(
      (c) => c.code == code,
      orElse: () => info.playable.first,
    );
    ref.read(_practiceStartingProvider.notifier).state = true;
    try {
      await ref
          .read(gameControllerProvider.notifier)
          .startNewGame(
            language: lang.code,
            category: cat.code,
            categoryLabel: cat.labelFor(lang.code),
            difficulty: ref.read(_practiceDiffProvider),
          );
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushReplacement(siyagRoute(const SiyagPracticeGameScreen()));
      }
    } finally {
      ref.read(_practiceStartingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final lang = ref.watch(_practiceLangProvider);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    final starting = ref.watch(_practiceStartingProvider);
    final canStart = modes.value?.playable.isNotEmpty ?? false;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('modeSolo'),
                accent: c.info,
                onBack: () => Navigator.of(context).maybePop(),
                backLabel: loc('back'),
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.md,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion.summaryIn,
                  child: modes.when(
                    loading: () => SiyaqLoader(semanticLabel: loc('loading')),
                    error: (e, _) => SiyaqEmptyState.error(
                      title: loc('somethingWrong'),
                      body: loc('errNetwork'),
                      actionLabel: loc('retry'),
                      onAction: () =>
                          ref.invalidate(modesByLanguageProvider(lang.code)),
                    ),
                    data: (info) {
                      final cats = info.playable;
                      if (cats.isEmpty) {
                        return SiyaqEmptyState(
                          title: loc('emptyGeneric'),
                          icon: SiyaqIcons.catGeneral,
                        );
                      }
                      final selCat =
                          ref.watch(_practiceCatProvider) ?? cats.first.code;
                      final selDiff = ref.watch(_practiceDiffProvider);
                      return ListView(
                        padding: const EdgeInsets.fromLTRB(
                          SiyaqSpacing.xl,
                          SiyaqSpacing.sm,
                          SiyaqSpacing.xl,
                          SiyaqSpacing.xxl,
                        ),
                        children: [
                          _Label(loc('chooseGameLang')),
                          const SizedBox(height: SiyaqSpacing.sm),
                          SiyaqSegmentedControl<GameplayLanguage>(
                            value: lang,
                            accent: c.info,
                            onChanged: (l) {
                              ref.read(_practiceLangProvider.notifier).state =
                                  l;
                              ref.read(_practiceCatProvider.notifier).state =
                                  null;
                            },
                            segments: [
                              for (final l in GameplayLanguage.values)
                                SiyaqSegment(
                                  value: l,
                                  label: loc(l.labelKey),
                                  semanticLabel:
                                      '${loc('gameLanguage')}: ${loc(l.labelKey)}',
                                ),
                            ],
                          ),
                          const SizedBox(height: SiyaqSpacing.xl),
                          _Label(loc('category')),
                          const SizedBox(height: SiyaqSpacing.sm),
                          Wrap(
                            spacing: SiyaqSpacing.md,
                            runSpacing: SiyaqSpacing.md,
                            children: [
                              for (final cat in cats)
                                SiyaqSelectTile(
                                  icon: SiyaqIcons.category(cat.code),
                                  label: cat.labelFor(lang.code),
                                  selected: cat.code == selCat,
                                  accent: c.info,
                                  onTap: () =>
                                      ref
                                          .read(_practiceCatProvider.notifier)
                                          .state = cat
                                          .code,
                                ),
                            ],
                          ),
                          const SizedBox(height: SiyaqSpacing.xl),
                          _Label(loc('difficulty')),
                          const SizedBox(height: SiyaqSpacing.sm),
                          SiyaqSegmentedControl<String>(
                            value: selDiff,
                            accent: c.info,
                            onChanged: (d) =>
                                ref.read(_practiceDiffProvider.notifier).state =
                                    d,
                            segments: [
                              SiyaqSegment(
                                value: 'easy',
                                label: loc('diffEasy'),
                              ),
                              SiyaqSegment(
                                value: 'medium',
                                label: loc('diffMedium'),
                              ),
                              SiyaqSegment(
                                value: 'hard',
                                label: loc('diffHard'),
                              ),
                            ],
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.xxl,
                ),
                child: SiyaqButton(
                  label: loc('startGame'),
                  icon: SiyaqIcons.play,
                  accent: c.info,
                  fullWidth: true,
                  loading: starting,
                  onPressed: canStart && !starting
                      ? () => _start(context, ref)
                      : null,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Align(
    alignment: AlignmentDirectional.centerStart,
    child: SiyaqText(
      text,
      role: SiyaqTextRole.bodySmall,
      color: context.colors.textSecondary,
      header: true,
    ),
  );
}
