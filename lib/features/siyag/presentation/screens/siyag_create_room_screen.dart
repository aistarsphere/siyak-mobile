import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/localization/app_localizations.dart';
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
  (ref) => GameplayLanguage.fromCode(ref.watch(appSettingsProvider).lang),
);
final _cat = StateProvider<String?>((ref) => null);
final _hint = StateProvider<HintMode>((ref) => HintMode.standard);
final _max = StateProvider<int>((ref) => 4);

const _playerOptions = [2, 4, 6];

/// Create Game — a guided 5-step setup (language → category → mode → players →
/// summary) wired to the live room repository. Fully localized, direction-aware.
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
    final lang = ref.watch(_lang);
    final modes = ref.watch(modesByLanguageProvider(lang.code));
    final busy = ref.watch(roomLifecycleControllerProvider).busy;
    final isLast = _step == _steps - 1;

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: SC.bg,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyagTopBar(
                kicker: loc('createRoom'),
                kickerColor: SC.emerald,
                onBack: _back,
              ),
              _StepDots(step: _step, total: _steps),
              const SizedBox(height: 8),
              Expanded(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 250),
                  child: KeyedSubtree(
                    key: ValueKey(_step),
                    child: _stepBody(loc, lang, modes),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
                child: isLast
                    ? SiyagPrimaryButton(
                        label: loc('createRoom'),
                        color: SC.emerald,
                        icon: Icons.add_rounded,
                        busy: busy,
                        onTap: () {
                          final info = modes.value;
                          if (info != null) _create(lang, info);
                        },
                      )
                    : SiyagPrimaryButton(
                        label: loc('next'),
                        color: SC.emerald,
                        onTap: _canAdvance(modes) ? _next : null,
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
class _StepDots extends StatelessWidget {
  const _StepDots({required this.step, required this.total});
  final int step;
  final int total;

  @override
  Widget build(BuildContext context) => Row(
    mainAxisAlignment: MainAxisAlignment.center,
    children: [
      for (var i = 0; i < total; i++)
        AnimatedContainer(
          duration: const Duration(milliseconds: 200),
          margin: const EdgeInsets.symmetric(horizontal: 3),
          width: i == step ? 22 : 8,
          height: 8,
          decoration: BoxDecoration(
            color: i <= step ? SC.emerald : SC.line,
            borderRadius: BorderRadius.circular(999),
          ),
        ),
    ],
  );
}

Widget _stepTitle(String t) => Padding(
  padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
  child: Text(t, style: ST.ar(22, weight: FontWeight.w700)),
);

/// A large selectable option card (icon/emoji + title + optional subtitle).
class _OptionCard extends StatelessWidget {
  const _OptionCard({
    required this.title,
    required this.selected,
    required this.color,
    required this.onTap,
    this.leading,
    this.subtitle,
  });
  final String title;
  final bool selected;
  final Color color;
  final VoidCallback onTap;
  final Widget? leading;
  final String? subtitle;

  @override
  Widget build(BuildContext context) => SiyagTap(
    onTap: onTap,
    scale: 0.98,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? color : SC.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Row(
        children: [
          if (leading != null) ...[leading!, const SizedBox(width: 14)],
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: ST.ar(16, weight: FontWeight.w700)),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: ST.ar(12.5, color: SC.textMute, height: 1.35),
                  ),
                ],
              ],
            ),
          ),
          Icon(
            selected
                ? Icons.check_circle_rounded
                : Icons.circle_outlined,
            color: selected ? color : SC.textFaint,
            size: 22,
          ),
        ],
      ),
    ),
  );
}

// ── Step 1: language ──────────────────────────────────────────────────────────
class _LanguageStep extends ConsumerWidget {
  const _LanguageStep({required this.loc, required this.lang});
  final AppLocalizations loc;
  final GameplayLanguage lang;

  @override
  Widget build(BuildContext context, WidgetRef ref) => ListView(
    children: [
      _stepTitle(loc('chooseLanguage')),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Column(
          children: [
            for (final l in GameplayLanguage.values) ...[
              _OptionCard(
                title: l == GameplayLanguage.arabic
                    ? loc('langArabic')
                    : loc('langEnglish'),
                selected: l == lang,
                color: SC.emerald,
                onTap: () {
                  ref.read(_lang.notifier).state = l;
                  ref.read(_cat.notifier).state = null;
                },
              ),
              const SizedBox(height: 12),
            ],
          ],
        ),
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
    loading: () => Center(child: CircularProgressIndicator(color: SC.emerald)),
    error: (e, _) => _CenterState(
      icon: Icons.wifi_off_rounded,
      title: loc('somethingWrong'),
      body: loc('errNetwork'),
    ),
    data: (info) {
      final cats = info.playable as List;
      if (cats.isEmpty) {
        return _CenterState(
          icon: Icons.category_outlined,
          title: loc('emptyGeneric'),
          body: '',
        );
      }
      final sel = ref.watch(_cat) ?? cats.first.code as String;
      return ListView(
        children: [
          _stepTitle(loc('chooseCategory')),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20),
            child: Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                for (final c in cats)
                  _CategoryCard(
                    emoji: _catEmoji(c.code as String),
                    label: c.labelFor(lang.code) as String,
                    selected: c.code == sel,
                    onTap: () => ref.read(_cat.notifier).state = c.code,
                  ),
              ],
            ),
          ),
        ],
      );
    },
  );
}

class _CategoryCard extends StatelessWidget {
  const _CategoryCard({
    required this.emoji,
    required this.label,
    required this.selected,
    required this.onTap,
  });
  final String emoji;
  final String label;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) => SiyagTap(
    onTap: onTap,
    scale: 0.97,
    child: AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      width: 104,
      height: 104,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: selected ? SC.emerald : SC.line,
          width: selected ? 2 : 1,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(emoji, style: const TextStyle(fontSize: 34)),
          const SizedBox(height: 8),
          Text(
            label,
            textAlign: TextAlign.center,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: ST.ar(13, weight: FontWeight.w600),
          ),
        ],
      ),
    ),
  );
}

// ── Step 3: game mode ─────────────────────────────────────────────────────────
class _ModeStep extends ConsumerWidget {
  const _ModeStep({required this.loc});
  final AppLocalizations loc;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hint = ref.watch(_hint);
    return ListView(
      children: [
        _stepTitle(loc('chooseMode')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              _OptionCard(
                title: loc('modeNormal'),
                subtitle: loc('modeNormalDesc'),
                selected: hint == HintMode.standard,
                color: SC.cyan,
                onTap: () => ref.read(_hint.notifier).state = HintMode.standard,
              ),
              const SizedBox(height: 12),
              _OptionCard(
                title: loc('modeCompetitive'),
                subtitle: loc('modeCompetitiveDesc'),
                selected: hint == HintMode.adaptive,
                color: SC.gold,
                onTap: () => ref.read(_hint.notifier).state = HintMode.adaptive,
              ),
            ],
          ),
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
    return ListView(
      children: [
        _stepTitle(loc('choosePlayers')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Column(
            children: [
              for (final n in _playerOptions) ...[
                _OptionCard(
                  title: loc.fill('playersCount', {'n': '$n'}),
                  selected: max == n,
                  color: SC.emerald,
                  leading: Icon(Icons.groups_rounded, color: SC.emerald),
                  onTap: () => ref.read(_max.notifier).state = n,
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
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
    final catCode = ref.watch(_cat) ??
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

    return ListView(
      children: [
        _stepTitle(loc('summaryTitle')),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: SC.surface,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: SC.line),
            ),
            child: Column(
              children: [
                _row(loc('languageLabel'),
                    lang == GameplayLanguage.arabic
                        ? loc('langArabic')
                        : loc('langEnglish')),
                _row(loc('category'), catLabel),
                _row(
                  loc('gameModeLabel'),
                  hint == HintMode.adaptive
                      ? loc('modeCompetitive')
                      : loc('modeNormal'),
                ),
                _row(loc('playersLabel'), '$max', last: true),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _row(String k, String v, {bool last = false}) => Padding(
    padding: EdgeInsets.only(bottom: last ? 0 : 14),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: ST.ar(13, color: SC.textMute)),
        Text(v, style: ST.ar(16, weight: FontWeight.w700)),
      ],
    ),
  );
}

class _CenterState extends StatelessWidget {
  const _CenterState({
    required this.icon,
    required this.title,
    required this.body,
  });
  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) => Center(
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 44, color: SC.textFaint),
          const SizedBox(height: 14),
          Text(
            title,
            textAlign: TextAlign.center,
            style: ST.ar(16, weight: FontWeight.w600),
          ),
          if (body.isNotEmpty) ...[
            const SizedBox(height: 6),
            Text(
              body,
              textAlign: TextAlign.center,
              style: ST.ar(13, color: SC.textMute),
            ),
          ],
        ],
      ),
    ),
  );
}

String _catEmoji(String code) {
  final c = code.toLowerCase();
  if (c.contains('animal') || c.contains('حيوان')) return '🐾';
  if (c.contains('sport') || c.contains('رياض')) return '⚽';
  if (c.contains('farm') || c.contains('agri') || c.contains('زراع')) {
    return '🌱';
  }
  if (c.contains('tech') || c.contains('تقني')) return '💻';
  if (c.contains('food') || c.contains('طعام')) return '🍽️';
  if (c.contains('geo') || c.contains('جغراف')) return '🗺️';
  if (c.contains('general') || c.contains('عام')) return '🌍';
  return '🎯';
}
