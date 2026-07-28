import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/providers.dart';
import '../../../v2/domain/entities/gameplay_language.dart';
import '../../../v2/domain/entities/hint_mode.dart';
import '../../../v2/presentation/controllers/room_controller.dart';
import '../siyag_route.dart';
import 'siyag_room_lobby_screen.dart';

final _lang = StateProvider<GameplayLanguage>(
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final _cat = StateProvider<String?>((ref) => null);
final _hint = StateProvider<HintMode>((ref) => HintMode.standard);
final _max = StateProvider<int>((ref) => 4);

const _playerOptions = [2, 4, 6];

/// Create Game — a guided 5-step setup (language → category → mode → players →
/// summary) wired to the live room repository. Fully localized, direction-aware.
///
/// Built from the Siyaq design system: the wizard chrome is [SiyaqStepDots], each
/// single-choice step is a [SiyaqListRow] with a selection indicator, the category
/// grid is [SiyaqSelectTile] (tintable icons in place of the old untintable,
/// screen-reader-invisible emoji) and the summary is a [SiyaqStatGrid].
///
/// The step machine, the create call, provider wiring and navigation are
/// unchanged from the pre-migration implementation.
class SiyagCreateRoomScreen extends ConsumerStatefulWidget {
  const SiyagCreateRoomScreen({super.key});

  @override
  ConsumerState<SiyagCreateRoomScreen> createState() => _WizardState();
}

class _WizardState extends ConsumerState<SiyagCreateRoomScreen> {
  static const _steps = 5;
  int _step = 0;

  void _back() {
    if (_step == 0) {
      Navigator.of(context).maybePop();
    } else {
      setState(() => _step -= 1);
    }
  }

  void _next() => setState(() => _step += 1);

  bool _canAdvance(AsyncValue modes) {
    if (_step == 1) {
      final info = modes.value;
      if (info == null || (info.playable as List).isEmpty) return false;
      return true; // a category is always defaulted to the first
    }
    return true;
  }

  Future<void> _create(GameplayLanguage lang, dynamic info) async {
    final loc = ref.read(localizationsProvider);
    final code = ref.read(_cat) ?? info.playable.first.code;
    final room = await ref
        .read(roomLifecycleControllerProvider.notifier)
        .create(
          language: lang,
          category: code,
          hintMode: ref.read(_hint),
          maxPlayers: ref.read(_max),
        );
    if (!mounted) return;
    if (room != null) {
      Navigator.of(
        context,
      ).pushReplacement(siyagRoute(const SiyagRoomLobbyScreen()));
    } else {
      final err = ref.read(roomLifecycleControllerProvider).error;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            err != null ? loc.errorMessage(err) : loc('somethingWrong'),
          ),
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final lang = ref.watch(_lang);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    final busy = ref.watch(roomLifecycleControllerProvider).busy;
    final isLast = _step == _steps - 1;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('createRoom'),
                accent: c.success,
                onBack: _back,
                backLabel: loc('back'),
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.md,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                ),
              ),
              SiyaqStepDots(
                step: _step,
                total: _steps,
                accent: c.success,
                semanticLabel: loc.fill('stepOf', {
                  'n': '${_step + 1}',
                  'total': '$_steps',
                }),
              ),
              const SizedBox(height: SiyaqSpacing.sm),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion.summaryIn,
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _stepBody(loc, lang, modes),
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
                child: isLast
                    ? SiyaqButton(
                        label: loc('createRoom'),
                        icon: SiyaqIcons.add,
                        accent: c.success,
                        fullWidth: true,
                        loading: busy,
                        onPressed: () {
                          final info = modes.value;
                          if (info != null) _create(lang, info);
                        },
                      )
                    : SiyaqButton(
                        label: loc('next'),
                        accent: c.success,
                        fullWidth: true,
                        onPressed: _canAdvance(modes) ? _next : null,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _stepBody(
    AppLocalizations loc,
    GameplayLanguage lang,
    AsyncValue modes,
  ) {
    switch (_step) {
      case 0:
        return _LanguageStep(loc: loc, lang: lang);
      case 1:
        return _CategoryStep(loc: loc, lang: lang, modes: modes);
      case 2:
        return _ModeStep(loc: loc);
      case 3:
        return _PlayersStep(loc: loc);
      default:
        return _SummaryStep(loc: loc, lang: lang, modes: modes);
    }
  }
}

// ── Step chrome ───────────────────────────────────────────────────────────────

/// Every step opens with its question as a heading, so the step body is
/// self-describing without relying on the dots alone.
class _StepScaffold extends StatelessWidget {
  const _StepScaffold({required this.title, required this.children});

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ListView(
    padding: const EdgeInsets.fromLTRB(
      SiyaqSpacing.xl,
      SiyaqSpacing.sm,
      SiyaqSpacing.xl,
      SiyaqSpacing.lg,
    ),
    children: [
      SiyaqText(title, role: SiyaqTextRole.headingLarge, header: true),
      const SizedBox(height: SiyaqSpacing.lg),
      ...children,
    ],
  );
}

/// One single-choice option. A [SiyaqListRow] with a selection indicator — no
/// screen-local option card, and the row announces itself as selected.
class _Option extends StatelessWidget {
  const _Option({
    required this.title,
    required this.selected,
    required this.accent,
    required this.onTap,
    this.leadingIcon,
    this.subtitle,
  });

  final String title;
  final bool selected;
  final Color accent;
  final VoidCallback onTap;
  final IconData? leadingIcon;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: SiyaqSpacing.md),
    child: SiyaqListRow(
      title: title,
      subtitle: subtitle,
      titleRole: SiyaqTextRole.bodyLarge,
      leadingIcon: leadingIcon,
      leadingColor: accent,
      selected: selected,
      showSelectionIndicator: true,
      selectionAccent: accent,
      radius: SiyaqRadius.xxl,
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      onTap: onTap,
    ),
  );
}

// ── Step 1: language ──────────────────────────────────────────────────────────
class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({required this.loc, required this.lang});
  final AppLocalizations loc;
  final GameplayLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) => _StepScaffold(
    title: loc('chooseLanguage'),
    children: [
      for (final l in GameplayLanguage.values)
        _Option(
          title: l == GameplayLanguage.arabic
              ? loc('langArabic')
              : loc('langEnglish'),
          selected: l == lang,
          accent: context.colors.success,
          onTap: () {
            ref.read(_lang.notifier).state = l;
            ref.read(_cat.notifier).state = null;
          },
        ),
    ],
  );
}

// ── Step 2: category ──────────────────────────────────────────────────────────
class _CategoryStep extends ConsumerWidget {
  const _CategoryStep({
    required this.loc,
    required this.lang,
    required this.modes,
  });
  final AppLocalizations loc;
  final GameplayLanguage lang;
  final AsyncValue modes;

  @override
  Widget build(BuildContext context, WidgetRef ref) => modes.when(
    loading: () => SiyaqLoader(semanticLabel: loc('loading')),
    error: (e, _) => SiyaqEmptyState.error(
      title: loc('somethingWrong'),
      body: loc('errNetwork'),
      actionLabel: loc('retry'),
      onAction: () => ref.invalidate(modesByLanguageProvider(lang.code)),
    ),
    data: (info) {
      final cats = info.playable as List;
      if (cats.isEmpty) {
        return SiyaqEmptyState(
          title: loc('emptyGeneric'),
          icon: SiyaqIcons.catGeneral,
        );
      }
      final sel = ref.watch(_cat) ?? cats.first.code as String;
      return _StepScaffold(
        title: loc('chooseCategory'),
        children: [
          Wrap(
            spacing: SiyaqSpacing.md,
            runSpacing: SiyaqSpacing.md,
            children: [
              for (final c in cats)
                SiyaqSelectTile(
                  icon: SiyaqIcons.category(c.code as String),
                  label: c.labelFor(lang.code) as String,
                  selected: c.code == sel,
                  accent: context.colors.success,
                  onTap: () => ref.read(_cat.notifier).state = c.code,
                ),
            ],
          ),
        ],
      );
    },
  );
}

// ── Step 3: game mode ─────────────────────────────────────────────────────────
class _ModeStep extends ConsumerWidget {
  const _ModeStep({required this.loc});
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final c = context.colors;
    final hint = ref.watch(_hint);
    return _StepScaffold(
      title: loc('chooseMode'),
      children: [
        _Option(
          title: loc('modeNormal'),
          subtitle: loc('modeNormalDesc'),
          selected: hint == HintMode.standard,
          accent: c.info,
          onTap: () => ref.read(_hint.notifier).state = HintMode.standard,
        ),
        _Option(
          title: loc('modeCompetitive'),
          subtitle: loc('modeCompetitiveDesc'),
          selected: hint == HintMode.adaptive,
          accent: c.primary,
          onTap: () => ref.read(_hint.notifier).state = HintMode.adaptive,
        ),
      ],
    );
  }
}

// ── Step 4: players count ─────────────────────────────────────────────────────
class _PlayersStep extends ConsumerWidget {
  const _PlayersStep({required this.loc});
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final max = ref.watch(_max);
    return _StepScaffold(
      title: loc('choosePlayers'),
      children: [
        for (final n in _playerOptions)
          _Option(
            title: loc.fill('playersCount', {'n': '$n'}),
            selected: max == n,
            accent: context.colors.success,
            leadingIcon: SiyaqIcons.social,
            onTap: () => ref.read(_max.notifier).state = n,
          ),
      ],
    );
  }
}

// ── Step 5: summary ───────────────────────────────────────────────────────────
class _SummaryStep extends ConsumerWidget {
  const _SummaryStep({
    required this.loc,
    required this.lang,
    required this.modes,
  });
  final AppLocalizations loc;
  final GameplayLanguage lang;
  final AsyncValue modes;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final info = modes.value;
    final catCode =
        ref.watch(_cat) ??
        (info != null && (info.playable as List).isNotEmpty
            ? info.playable.first.code as String
            : '');
    String catLabel = catCode;
    if (info != null) {
      for (final c in info.playable as List) {
        if (c.code == catCode) catLabel = c.labelFor(lang.code) as String;
      }
    }
    final hint = ref.watch(_hint);
    final max = ref.watch(_max);

    // A stat grid rather than a card of label/value rows: each choice becomes its
    // own announced cell, and the grid reflows to 2-up at narrow widths and large
    // text scales instead of truncating.
    return _StepScaffold(
      title: loc('summaryTitle'),
      children: [
        SiyaqStatGrid(
          columns: 2,
          minCellWidth: 120,
          gap: SiyaqSpacing.md,
          children: [
            SiyaqStatCard(
              label: loc('languageLabel'),
              value: lang == GameplayLanguage.arabic
                  ? loc('langArabic')
                  : loc('langEnglish'),
              numeric: false,
            ),
            SiyaqStatCard(
              label: loc('category'),
              value: catLabel,
              numeric: false,
              accent: context.colors.success,
            ),
            SiyaqStatCard(
              label: loc('gameModeLabel'),
              value: hint == HintMode.adaptive
                  ? loc('modeCompetitive')
                  : loc('modeNormal'),
              numeric: false,
            ),
            SiyaqStatCard(label: loc('playersLabel'), value: '$max'),
          ],
        ),
      ],
    );
  }
}
