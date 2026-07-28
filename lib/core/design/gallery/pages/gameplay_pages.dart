import 'package:flutter/material.dart';

import '../../components/foundation/siyaq_text.dart';
import '../../components/gameplay/siyaq_guess_composer.dart';
import '../../components/gameplay/siyaq_guess_highlight.dart';
import '../../components/gameplay/siyaq_guess_row.dart';
import '../../components/gameplay/siyaq_hint_panel.dart';
import '../../gameplay/siyaq_heat.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import 'token_pages.dart';

String _t(BuildContext context, String ar, String en) =>
    context.isRtl ? ar : en;

/// Band labels, resolved the way the game screens do it (through the app
/// localization). The gallery has no `AppLocalizations`, so it mirrors the two
/// tables here rather than importing the feature layer.
String _band(BuildContext context, SiyaqHeatBand b) => switch (b) {
  SiyaqHeatBand.solved => _t(context, 'الإجابة', 'Answer'),
  SiyaqHeatBand.blazing => _t(context, 'ملتهب', 'Blazing'),
  SiyaqHeatBand.hot => _t(context, 'حار', 'Hot'),
  SiyaqHeatBand.warm => _t(context, 'دافئ', 'Warm'),
  SiyaqHeatBand.lukewarm => _t(context, 'فاتر', 'Lukewarm'),
  SiyaqHeatBand.cold => _t(context, 'بارد', 'Cold'),
};

/// Gallery coverage for the core gameplay components.
///
/// The axis that matters here is **content script versus UI script**: gameplay
/// words follow the game language, so every sample renders an Arabic word and a
/// Latin word regardless of which way the page itself is running.
class GameplayComponentsPage extends StatefulWidget {
  const GameplayComponentsPage({super.key});

  @override
  State<GameplayComponentsPage> createState() => _GameplayComponentsPageState();
}

class _GameplayComponentsPageState extends State<GameplayComponentsPage> {
  final _empty = TextEditingController();
  final _typed = TextEditingController(text: 'كتاب');
  final _latin = TextEditingController(text: 'library');
  final _rejected = TextEditingController(text: 'zzz');

  bool _hintsOpen = true;

  @override
  void dispose() {
    _empty.dispose();
    _typed.dispose();
    _latin.dispose();
    _rejected.dispose();
    super.dispose();
  }

  static const _hints = [
    SiyaqHintData(word: 'مكتبة', rank: 42),
    SiyaqHintData(word: 'قراءة', rank: 118),
  ];

  SiyaqGuessData _g(String w, int rank, double heat, {bool solved = false}) =>
      SiyaqGuessData(word: w, rank: rank, heat: heat, solved: solved);

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final rank = _t(context, 'المركز', 'Rank');
    final distance = _t(context, 'المسافة', 'Distance');

    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'HEAT BANDS · label + icon, never colour alone',
          children: [
            for (final b in SiyaqHeatBand.values)
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.xs),
                child: SiyaqGuessRow(
                  guess: _g(
                    _band(context, b),
                    switch (b) {
                      SiyaqHeatBand.solved => 1,
                      SiyaqHeatBand.blazing => 3,
                      SiyaqHeatBand.hot => 40,
                      SiyaqHeatBand.warm => 400,
                      SiyaqHeatBand.lukewarm => 4000,
                      SiyaqHeatBand.cold => 19000,
                    },
                    switch (b) {
                      SiyaqHeatBand.solved => 1.0,
                      SiyaqHeatBand.blazing => 0.92,
                      SiyaqHeatBand.hot => 0.72,
                      SiyaqHeatBand.warm => 0.52,
                      SiyaqHeatBand.lukewarm => 0.32,
                      SiyaqHeatBand.cold => 0.10,
                    },
                    solved: b == SiyaqHeatBand.solved,
                  ),
                  bandLabel: _band(context, b),
                  rankLabel: rank,
                ),
              ),
          ],
        ),
        GallerySection(
          title: 'GUESS ROW · plain / best / latest / solved',
          children: [
            SiyaqGuessRow(
              guess: _g('سيارة', 812, 0.44),
              bandLabel: _band(context, SiyaqHeatBand.lukewarm),
              rankLabel: rank,
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('كتاب', 25, 0.88),
              bandLabel: _band(context, SiyaqHeatBand.blazing),
              rankLabel: rank,
              isBest: true,
              statusLabel: _t(context, 'الأقرب', 'Closest'),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('library', 1204, 0.30),
              bandLabel: _band(context, SiyaqHeatBand.lukewarm),
              rankLabel: rank,
              script: SiyaqScript.latin,
              isLatest: true,
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('مكتبة', 1, 1.0, solved: true),
              bandLabel: _band(context, SiyaqHeatBand.solved),
              rankLabel: rank,
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('كلمة طويلة جداً لا تتسع في السطر الواحد', 9, 0.80),
              bandLabel: _band(context, SiyaqHeatBand.blazing),
              rankLabel: rank,
            ),
          ],
        ),
        GallerySection(
          title: 'HIGHLIGHTS · Closest and Latest are different guesses',
          children: [
            SiyaqGuessHighlight(
              label: _t(context, 'الأقرب', 'Closest'),
              guess: _g('كتاب', 25, 0.88),
              bandLabel: _band(context, SiyaqHeatBand.blazing),
              distanceLabel: distance,
              emphasised: true,
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqGuessHighlight(
              label: _t(context, 'الأخير', 'Latest'),
              guess: _g('سيارة', 812, 0.44),
              bandLabel: _band(context, SiyaqHeatBand.lukewarm),
              distanceLabel: distance,
              accent: c.info,
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqGuessHighlight(
              label: _t(context, 'الأقرب', 'Closest'),
              guess: _g('bookshelf', 1, 1.0, solved: true),
              bandLabel: _band(context, SiyaqHeatBand.solved),
              distanceLabel: distance,
              script: SiyaqScript.latin,
              emphasised: true,
            ),
          ],
        ),
        GallerySection(
          title: 'ATTRIBUTION · shared modes name the author',
          children: [
            SiyaqGuessRow(
              guess: _g('كتاب', 25, 0.88),
              bandLabel: _band(context, SiyaqHeatBand.blazing),
              rankLabel: rank,
              isBest: true,
              attribution: SiyaqGuessAttribution(
                label: _t(context, 'كاظم', 'You'),
                icon: SiyaqIcons.profile,
                color: c.primary,
              ),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('قلم', 340, 0.62),
              bandLabel: _band(context, SiyaqHeatBand.hot),
              rankLabel: rank,
              attribution: SiyaqGuessAttribution(
                label: 'Sara',
                icon: SiyaqIcons.players,
              ),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('مكتبة', 42, 0.84),
              bandLabel: _band(context, SiyaqHeatBand.blazing),
              rankLabel: rank,
              attribution: SiyaqGuessAttribution(
                label: _t(context, 'تلميح', 'Hint'),
                icon: SiyaqIcons.hint,
                color: c.info,
              ),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: _g('Abdulrahman-long-name', 900, 0.44),
              bandLabel: _band(context, SiyaqHeatBand.warm),
              rankLabel: rank,
              script: SiyaqScript.latin,
              attribution: SiyaqGuessAttribution(
                label: 'Abdulrahman Al-Mutairi',
                icon: SiyaqIcons.players,
              ),
            ),
          ],
        ),
        GallerySection(
          title: 'RANK ONLY · a mode with no closeness signal (ranked 1v1)',
          children: [
            SiyaqGuessRow(
              guess: const SiyaqGuessData(word: 'library', rank: 25),
              rankLabel: rank,
              script: SiyaqScript.latin,
              isBest: true,
              attribution: SiyaqGuessAttribution(
                label: _t(context, 'أنت', 'You'),
                icon: SiyaqIcons.profile,
                color: c.primary,
              ),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: const SiyaqGuessData(word: 'shelf', rank: 1204),
              rankLabel: rank,
              script: SiyaqScript.latin,
              attribution: SiyaqGuessAttribution(
                label: _t(context, 'الخصم', 'Opponent'),
                icon: SiyaqIcons.opponent,
              ),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            SiyaqGuessRow(
              guess: const SiyaqGuessData(
                word: 'bookshelf',
                rank: 1,
                solved: true,
              ),
              rankLabel: rank,
              script: SiyaqScript.latin,
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqGuessHighlight(
              label: _t(context, 'الأقرب', 'Closest'),
              guess: const SiyaqGuessData(word: 'library', rank: 25),
              distanceLabel: distance,
              script: SiyaqScript.latin,
              accent: c.primary,
              emphasised: true,
            ),
          ],
        ),
        GallerySection(
          title: 'HINT PANEL · collapsed gives its space back',
          children: [
            SiyaqHintPanel(
              expanded: false,
              onToggle: () {},
              title: _t(context, 'التلميحات', 'Hints'),
              remainingLabel: _t(context, '٢ متبقية', '2 left'),
              toggleSemanticLabel: _t(context, 'إظهار', 'Show hints'),
              hints: _hints,
              rankLabel: rank,
              emptyLabel: _t(context, 'لا تلميحات', 'No hints yet'),
              revealLabel: _t(context, 'اكشف تلميحاً', 'Reveal a hint'),
              onRequestHint: () {},
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqHintPanel(
              expanded: _hintsOpen,
              onToggle: () => setState(() => _hintsOpen = !_hintsOpen),
              title: _t(context, 'التلميحات', 'Hints'),
              remainingLabel: _t(context, '٢ متبقية', '2 left'),
              toggleSemanticLabel: _t(context, 'إخفاء', 'Hide hints'),
              hints: _hints,
              rankLabel: rank,
              emptyLabel: _t(context, 'لا تلميحات', 'No hints yet'),
              revealLabel: _t(context, 'اكشف تلميحاً', 'Reveal a hint'),
              onRequestHint: () {},
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqHintPanel(
              expanded: true,
              onToggle: () {},
              title: _t(context, 'التلميحات', 'Hints'),
              remainingLabel: _t(context, 'لا مزيد', 'No hints left'),
              toggleSemanticLabel: _t(context, 'إخفاء', 'Hide hints'),
              hints: const [],
              rankLabel: rank,
              emptyLabel: _t(context, 'لم تكشف أي تلميح بعد', 'No hints yet'),
              revealLabel: _t(context, 'اكشف تلميحاً', 'Reveal a hint'),
              onRequestHint: null,
            ),
          ],
        ),
        GallerySection(
          title: 'COMPOSER · empty / typed / RTL content / submitting / error',
          children: [
            SiyaqGuessComposer(
              controller: _empty,
              onSubmit: (_) {},
              hintText: _t(context, 'اكتب كلمتك…', 'Type your word…'),
              submitLabel: 'Submit',
              fieldSemanticLabel: 'Guess',
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqGuessComposer(
              controller: _typed,
              onSubmit: (_) {},
              hintText: 'اكتب كلمتك…',
              submitLabel: 'Submit',
              fieldSemanticLabel: 'Guess',
              direction: TextDirection.rtl,
              script: SiyaqScript.arabic,
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqGuessComposer(
              controller: _latin,
              onSubmit: (_) {},
              hintText: 'Type your word…',
              submitLabel: 'Submit',
              fieldSemanticLabel: 'Guess',
              direction: TextDirection.ltr,
              script: SiyaqScript.latin,
              submitting: true,
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqGuessComposer(
              controller: _rejected,
              onSubmit: (_) {},
              hintText: 'Type your word…',
              submitLabel: 'Submit',
              fieldSemanticLabel: 'Guess',
              errorText: _t(
                context,
                'هذه الكلمة ليست في القاموس',
                'This word is not in the dictionary',
              ),
            ),
            const SizedBox(height: SiyaqSpacing.md),
            SiyaqGuessComposer(
              controller: _empty,
              onSubmit: (_) {},
              hintText: _t(context, 'انتهت اللعبة', 'Game over'),
              submitLabel: 'Submit',
              fieldSemanticLabel: 'Guess',
              enabled: false,
            ),
          ],
        ),
        const SizedBox(height: SiyaqSpacing.xxxl),
        SiyaqText(
          _t(
            context,
            'محتوى اللعب يتبع لغة اللعبة، لا لغة الواجهة',
            'Gameplay content follows the game language, not the UI language',
          ),
          role: SiyaqTextRole.bodySmall,
          color: c.textMuted,
        ),
      ],
    );
  }
}
