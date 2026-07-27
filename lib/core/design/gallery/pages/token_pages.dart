import 'package:flutter/material.dart';

import '../../a11y/siyaq_a11y.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_colors.dart';
import '../../tokens/siyaq_elevation.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';

double _contrast(Color a, Color b) {
  final la = a.computeLuminance(), lb = b.computeLuminance();
  final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
  return (hi + 0.05) / (lo + 0.05);
}

/// ── Section scaffolding ─────────────────────────────────────────────────────

class GallerySection extends StatelessWidget {
  const GallerySection({
    super.key,
    required this.title,
    required this.children,
  });

  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Padding(
        padding: const EdgeInsets.only(
          top: SiyaqSpacing.xl,
          bottom: SiyaqSpacing.sm,
        ),
        child: Text(
          title,
          style: context.type.role(
            SiyaqTextRole.labelSmall,
            script: SiyaqScript.mono,
            color: context.colors.primary,
            letterSpacing: 1.6,
          ),
        ),
      ),
      ...children,
    ],
  );
}

/// A token row: swatch, name, resolved value, and (for text pairs) contrast.
class _TokenRow extends StatelessWidget {
  const _TokenRow({
    required this.name,
    required this.color,
    this.against,
    this.isText = false,
  });

  final String name;
  final Color color;

  /// Background to measure contrast against, when [isText].
  final Color? against;
  final bool isText;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final hex =
        '#${(color.toARGB32() & 0xFFFFFF).toRadixString(16).padLeft(6, '0').toUpperCase()}';
    final alpha = color.a;
    double? ratio;
    if (isText && against != null) ratio = _contrast(color, against!);

    return Padding(
      padding: const EdgeInsets.only(bottom: SiyaqSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 28,
            height: 28,
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(SiyaqRadius.md),
              border: Border.all(color: c.border),
            ),
          ),
          const SizedBox(width: SiyaqSpacing.md),
          // A Wrap rather than a Row: the value and the contrast pill reflow onto
          // their own line at large text scales / narrow viewports instead of
          // overflowing. The gallery must survive the very cases it validates.
          Expanded(
            child: Wrap(
              spacing: SiyaqSpacing.sm,
              runSpacing: SiyaqSpacing.xxxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  name,
                  style: context.type.role(
                    SiyaqTextRole.bodySmall,
                    script: SiyaqScript.latin,
                    color: c.textPrimary,
                  ),
                ),
                // Hex is a Latin token, not prose: force LTR so RTL bidi does
                // not reorder it to "F7F5F0#".
                Directionality(
                  textDirection: TextDirection.ltr,
                  child: Text(
                    alpha < 1 ? '$hex ${(alpha * 100).round()}%' : hex,
                    style: context.type.numeric(
                      SiyaqTextRole.labelSmall,
                      color: c.textMuted,
                    ),
                  ),
                ),
                if (ratio != null) _ContrastPill(ratio: ratio),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// WCAG verdict for a measured pair — the accessibility overlay in miniature.
class _ContrastPill extends StatelessWidget {
  const _ContrastPill({required this.ratio});

  final double ratio;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final pass = ratio >= 4.5;
    final large = ratio >= 3.0;
    final tint = pass
        ? c.success
        : large
        ? c.warning
        : c.error;
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: SiyaqSpacing.xs,
        vertical: 1,
      ),
      decoration: BoxDecoration(
        color: tint.withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(SiyaqRadius.full),
        border: Border.all(color: tint.withValues(alpha: 0.4)),
      ),
      child: Text(
        '${ratio.toStringAsFixed(2)}  ${pass
            ? 'AA'
            : large
            ? 'AA-lg'
            : 'FAIL'}',
        style: context.type.numeric(SiyaqTextRole.labelSmall, color: tint),
      ),
    );
  }
}

/// ── Colour tokens ───────────────────────────────────────────────────────────

class ColorTokensPage extends StatelessWidget {
  const ColorTokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'SURFACES',
          children: [
            _TokenRow(name: 'background', color: c.background),
            _TokenRow(name: 'surface', color: c.surface),
            _TokenRow(name: 'surfaceElevated', color: c.surfaceElevated),
            _TokenRow(name: 'surfaceStrong', color: c.surfaceStrong),
            _TokenRow(name: 'surfaceDisabled', color: c.surfaceDisabled),
          ],
        ),
        GallerySection(
          title: 'TEXT  (contrast vs background)',
          children: [
            _TokenRow(
              name: 'textPrimary',
              color: c.textPrimary,
              against: c.background,
              isText: true,
            ),
            _TokenRow(
              name: 'textSecondary',
              color: c.textSecondary,
              against: c.background,
              isText: true,
            ),
            _TokenRow(
              name: 'textMuted',
              color: c.textMuted,
              against: c.background,
              isText: true,
            ),
            _TokenRow(
              name: 'textDisabled',
              color: c.textDisabled,
              against: c.background,
              isText: true,
            ),
            _TokenRow(
              name: 'textInverse',
              color: c.textInverse,
              against: c.textPrimary,
              isText: true,
            ),
          ],
        ),
        GallerySection(
          title: 'BORDERS',
          children: [
            _TokenRow(name: 'border', color: c.border),
            _TokenRow(name: 'borderStrong', color: c.borderStrong),
            _TokenRow(name: 'borderFocus', color: c.borderFocus),
            _TokenRow(name: 'divider', color: c.divider),
          ],
        ),
        GallerySection(
          title: 'ACTIONS  (foreground contrast on its own fill)',
          children: [
            _TokenRow(name: 'primary', color: c.primary),
            _TokenRow(name: 'primaryStrong', color: c.primaryStrong),
            _TokenRow(name: 'primaryContainer', color: c.primaryContainer),
            _TokenRow(
              name: 'onAction  · on primary',
              color: c.onAction,
              against: c.primary,
              isText: true,
            ),
            _TokenRow(name: 'actionSecondary', color: c.actionSecondary),
            _TokenRow(
              name: 'onActionSecondary  · on secondary',
              color: c.onActionSecondary,
              against: c.actionSecondary,
              isText: true,
            ),
            _TokenRow(name: 'actionDestructive', color: c.actionDestructive),
            _TokenRow(
              name: 'onActionDestructive  · on destructive',
              color: c.onActionDestructive,
              against: c.actionDestructive,
              isText: true,
            ),
          ],
        ),
        GallerySection(
          title: 'STATUS',
          children: [
            _TokenRow(
              name: 'success',
              color: c.success,
              against: c.background,
              isText: true,
            ),
            _TokenRow(name: 'successSubtle', color: c.successSubtle),
            _TokenRow(
              name: 'warning',
              color: c.warning,
              against: c.background,
              isText: true,
            ),
            _TokenRow(name: 'warningSubtle', color: c.warningSubtle),
            _TokenRow(
              name: 'error',
              color: c.error,
              against: c.background,
              isText: true,
            ),
            _TokenRow(name: 'errorSubtle', color: c.errorSubtle),
            _TokenRow(
              name: 'info',
              color: c.info,
              against: c.background,
              isText: true,
            ),
            _TokenRow(name: 'infoSubtle', color: c.infoSubtle),
          ],
        ),
        GallerySection(
          title: 'GAME MODES  (kept distinct from status)',
          children: [
            _TokenRow(name: 'gameSolo', color: c.gameSolo),
            _TokenRow(name: 'gameWeekly', color: c.gameWeekly),
            _TokenRow(name: 'gameMultiplayer', color: c.gameMultiplayer),
            _TokenRow(name: 'gameRanked', color: c.gameRanked),
            _TokenRow(name: 'gamePractice', color: c.gamePractice),
          ],
        ),
        GallerySection(
          title: 'DISTANCE RAMP  · indicators only, not text',
          children: [
            _TokenRow(
              name: 'distanceVeryFar',
              color: SiyaqColors.distanceVeryFar,
              against: c.surface,
              isText: true,
            ),
            _TokenRow(
              name: 'distanceFar',
              color: SiyaqColors.distanceFar,
              against: c.surface,
              isText: true,
            ),
            _TokenRow(
              name: 'distanceCloser',
              color: SiyaqColors.distanceCloser,
              against: c.surface,
              isText: true,
            ),
            _TokenRow(
              name: 'distanceClose',
              color: SiyaqColors.distanceClose,
              against: c.surface,
              isText: true,
            ),
            _TokenRow(
              name: 'distanceVeryClose',
              color: SiyaqColors.distanceVeryClose,
              against: c.surface,
              isText: true,
            ),
            _TokenRow(
              name: 'distanceCorrect',
              color: SiyaqColors.distanceCorrect,
              against: c.surface,
              isText: true,
            ),
            Padding(
              padding: const EdgeInsets.only(top: SiyaqSpacing.sm),
              child: Text(
                'All six fail AA as text on a light surface — use them for bars '
                'and dots, and pair the numeral with textPrimary.',
                style: context.type.role(
                  SiyaqTextRole.bodySmall,
                  script: SiyaqScript.latin,
                  color: c.textMuted,
                ),
              ),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            Row(
              children: [
                for (final d in SiyaqColors.distanceRamp)
                  Expanded(
                    child: Container(
                      height: 8,
                      margin: const EdgeInsets.only(right: 2),
                      decoration: BoxDecoration(
                        color: d,
                        borderRadius: BorderRadius.circular(SiyaqRadius.full),
                      ),
                    ),
                  ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// ── Typography ──────────────────────────────────────────────────────────────

class TypographyPage extends StatelessWidget {
  const TypographyPage({super.key});

  static const _samples = <SiyaqTextRole, (String, String)>{
    SiyaqTextRole.displayLarge: ('سياق', 'Siyaq'),
    SiyaqTextRole.displayMedium: ('اكتشاف الكلمات', 'Word Discovery'),
    SiyaqTextRole.displaySmall: ('انتهت اللعبة', 'Game Over'),
    SiyaqTextRole.headingLarge: ('لوحة المتصدرين', 'Leaderboard'),
    SiyaqTextRole.headingMedium: ('تحدي الأسبوع', 'Weekly Challenge'),
    SiyaqTextRole.headingSmall: ('إحصائياتك', 'Your Statistics'),
    SiyaqTextRole.bodyLarge: (
      'خمّن الكلمة المستهدفة عبر الروابط الدلالية.',
      'Guess the target word by exploring semantic connections.',
    ),
    SiyaqTextRole.bodyMedium: (
      'كل تخمين يكشف مدى قربك من الإجابة.',
      'Each guess reveals how close you are.',
    ),
    SiyaqTextRole.bodySmall: ('٣ محاولات متبقية', '3 guesses remaining'),
    SiyaqTextRole.labelLarge: ('أرسل التخمين', 'SUBMIT GUESS'),
    SiyaqTextRole.labelMedium: ('المسافة ٠.٤٢', 'DISTANCE 0.42'),
    SiyaqTextRole.labelSmall: ('متصل', 'ONLINE'),
    SiyaqTextRole.buttonLarge: ('ابدأ اللعب', 'Start Playing'),
    SiyaqTextRole.buttonMedium: ('انضم', 'Join'),
    SiyaqTextRole.gameDistance: ('٢٣٠', '230'),
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final isRtl = context.isRtl;
    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'TYPE SCALE  · metrics bound in Figma',
          children: [
            for (final e in _samples.entries)
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.md),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${e.key.name}  ·  ${e.key.size.toInt()}px  ·  '
                      'h ${e.key.latinHeight}  ·  ls ${e.key.latinTracking}',
                      style: context.type.numeric(
                        SiyaqTextRole.labelSmall,
                        color: c.textMuted,
                      ),
                    ),
                    const SizedBox(height: SiyaqSpacing.xxs),
                    Text(
                      isRtl ? e.value.$1 : e.value.$2,
                      style: context.type.role(e.key),
                    ),
                  ],
                ),
              ),
          ],
        ),
        GallerySection(
          title: 'MONO / NUMERIC',
          children: [
            Text(
              '#1 · 230 · 01:42',
              style: context.type.numeric(SiyaqTextRole.headingMedium),
            ),
            const SizedBox(height: SiyaqSpacing.xs),
            Text('KICKER LABEL', style: context.type.kicker),
          ],
        ),
        GallerySection(
          title: 'BOTH SCRIPTS AT ONE ROLE',
          children: [
            Text(
              'Siyaq سياق',
              style: context.type.role(SiyaqTextRole.headingMedium),
            ),
            const SizedBox(height: SiyaqSpacing.xxs),
            Text(
              'Arabic drops Latin tracking — positive letter-spacing breaks '
              'cursive joining.',
              style: context.type.role(
                SiyaqTextRole.bodySmall,
                script: SiyaqScript.latin,
                color: c.textMuted,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// ── Spacing, radius, elevation, motion, icons ───────────────────────────────

class LayoutTokensPage extends StatelessWidget {
  const LayoutTokensPage({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'SPACING  · 4px grid',
          children: [
            for (final (name, v) in SiyaqSpacing.scale)
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 56,
                      child: Text(
                        name,
                        style: context.type.role(
                          SiyaqTextRole.bodySmall,
                          script: SiyaqScript.latin,
                        ),
                      ),
                    ),
                    SizedBox(
                      width: 40,
                      child: Text(
                        '${v.toInt()}',
                        style: context.type.numeric(
                          SiyaqTextRole.labelSmall,
                          color: c.textMuted,
                        ),
                      ),
                    ),
                    Container(height: 10, width: v, color: c.primary),
                  ],
                ),
              ),
          ],
        ),
        GallerySection(
          title: 'RADIUS',
          children: [
            Wrap(
              spacing: SiyaqSpacing.sm,
              runSpacing: SiyaqSpacing.sm,
              children: [
                for (final (name, v) in SiyaqRadius.scale)
                  Column(
                    children: [
                      Container(
                        width: 56,
                        height: 44,
                        decoration: BoxDecoration(
                          color: c.surfaceElevated,
                          borderRadius: BorderRadius.circular(v),
                          border: Border.all(color: c.borderStrong),
                        ),
                      ),
                      const SizedBox(height: SiyaqSpacing.xxs),
                      Text(
                        '$name ${v.toInt()}',
                        style: context.type.numeric(
                          SiyaqTextRole.labelSmall,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'ELEVATION  · values local; Figma defines none',
          children: [
            Wrap(
              spacing: SiyaqSpacing.lg,
              runSpacing: SiyaqSpacing.lg,
              children: [
                for (final (name, e) in SiyaqElevation.scale)
                  Column(
                    children: [
                      Container(
                        width: 68,
                        height: 48,
                        decoration: BoxDecoration(
                          color: c.surface,
                          borderRadius: BorderRadius.circular(SiyaqRadius.card),
                          border: Border.all(color: c.border),
                          boxShadow: e.shadows(c.shadow),
                        ),
                      ),
                      const SizedBox(height: SiyaqSpacing.xxs),
                      Text(
                        name,
                        style: context.type.numeric(
                          SiyaqTextRole.labelSmall,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'MOTION  · carried from the app; Figma defines none',
          children: [
            for (final (name, d) in SiyaqMotion.durations)
              Padding(
                padding: const EdgeInsets.only(bottom: SiyaqSpacing.xxs),
                child: Row(
                  children: [
                    SizedBox(
                      width: 96,
                      child: Text(
                        name,
                        style: context.type.role(
                          SiyaqTextRole.bodySmall,
                          script: SiyaqScript.latin,
                        ),
                      ),
                    ),
                    Text(
                      '${d.inMilliseconds}ms',
                      style: context.type.numeric(
                        SiyaqTextRole.labelSmall,
                        color: c.textMuted,
                      ),
                    ),
                  ],
                ),
              ),
          ],
        ),
        GallerySection(
          title: 'ICONS  · replacing emoji; tintable + labelled',
          children: [
            Wrap(
              spacing: SiyaqSpacing.lg,
              runSpacing: SiyaqSpacing.md,
              children: [
                for (final (label, icon) in <(String, IconData)>[
                  ('hot', SiyaqIcons.hot),
                  ('hint', SiyaqIcons.hint),
                  ('locked', SiyaqIcons.locked),
                  ('correct', SiyaqIcons.correct),
                  ('best', SiyaqIcons.best),
                  ('trendUp', SiyaqIcons.trendUp),
                  ('success', SiyaqIcons.success),
                  ('error', SiyaqIcons.error),
                  ('offline', SiyaqIcons.offline),
                ])
                  Column(
                    children: [
                      SiyaqA11y.meaningfulIcon(
                        label: label,
                        child: Icon(
                          icon,
                          size: SiyaqIconSize.lg,
                          color: c.iconPrimary,
                        ),
                      ),
                      const SizedBox(height: SiyaqSpacing.xxs),
                      Text(
                        label,
                        style: context.type.numeric(
                          SiyaqTextRole.labelSmall,
                          color: c.textMuted,
                        ),
                      ),
                    ],
                  ),
              ],
            ),
            const SizedBox(height: SiyaqSpacing.md),
            Row(
              children: [
                for (final s in SiyaqIconSize.scale) ...[
                  Icon(SiyaqIcons.hot, size: s.$2, color: c.primary),
                  const SizedBox(width: SiyaqSpacing.sm),
                ],
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// ── Component-state foundation ──────────────────────────────────────────────
///
/// Phase 1 ships no shared components, so this page validates the *foundation*
/// those components will inherit: state fills, focus rings, minimum touch
/// targets and long-content behaviour.
class StateFoundationPage extends StatefulWidget {
  const StateFoundationPage({super.key});

  @override
  State<StateFoundationPage> createState() => _StateFoundationPageState();
}

class _StateFoundationPageState extends State<StateFoundationPage> {
  bool _focused = true;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    Widget sample(String label, Color fill, Color fg, {bool dim = false}) =>
        Opacity(
          opacity: dim ? 0.5 : 1,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: SiyaqSpacing.lg,
              vertical: SiyaqSpacing.md,
            ),
            constraints: const BoxConstraints(
              minHeight: SiyaqSpacing.minTouchTarget,
            ),
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: fill,
              borderRadius: BorderRadius.circular(SiyaqRadius.button),
            ),
            child: Text(
              label,
              style: context.type.role(SiyaqTextRole.buttonMedium, color: fg),
            ),
          ),
        );

    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'INTERACTION STATES',
          children: [
            Wrap(
              spacing: SiyaqSpacing.sm,
              runSpacing: SiyaqSpacing.sm,
              children: [
                sample('Default', c.primary, c.onAction),
                sample('Pressed', c.primaryStrong, c.onAction),
                sample(
                  'Disabled',
                  c.surfaceDisabled,
                  c.textDisabled,
                  dim: true,
                ),
                sample('Secondary', c.actionSecondary, c.onActionSecondary),
                sample(
                  'Destructive',
                  c.actionDestructive,
                  c.onActionDestructive,
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'FOCUS RING  · Figma mandates 2px; ships no Focus variant',
          children: [
            Row(
              children: [
                SiyaqFocusRing(
                  focused: _focused,
                  color: c.borderFocus,
                  radius: SiyaqRadius.button,
                  child: sample('Focused', c.primary, c.onAction),
                ),
                const SizedBox(width: SiyaqSpacing.lg),
                Switch(
                  value: _focused,
                  onChanged: (v) => setState(() => _focused = v),
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'FEEDBACK TINTS',
          children: [
            for (final (label, fg, bg) in <(String, Color, Color)>[
              ('Success', c.success, c.successSubtle),
              ('Warning', c.warning, c.warningSubtle),
              ('Error', c.error, c.errorSubtle),
              ('Info', c.info, c.infoSubtle),
            ])
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
                padding: const EdgeInsets.all(SiyaqSpacing.md),
                decoration: BoxDecoration(
                  color: bg,
                  borderRadius: BorderRadius.circular(SiyaqRadius.card),
                  border: Border.all(color: fg.withValues(alpha: 0.4)),
                ),
                child: Text(
                  label,
                  style: context.type.role(SiyaqTextRole.bodyMedium, color: fg),
                ),
              ),
          ],
        ),
        GallerySection(
          title: 'LOADING',
          children: [
            Row(
              children: [
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.2,
                    color: c.primary,
                  ),
                ),
                const SizedBox(width: SiyaqSpacing.md),
                Expanded(
                  child: Container(
                    height: 10,
                    decoration: BoxDecoration(
                      color: c.surfaceElevated,
                      borderRadius: BorderRadius.circular(SiyaqRadius.full),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'TOUCH TARGET  · 44px minimum',
          children: [
            Row(
              children: [
                ColoredBox(
                  color: c.primaryContainer,
                  child: SiyaqA11y.minTarget(
                    child: Icon(
                      SiyaqIcons.hint,
                      size: SiyaqIconSize.sm,
                      color: c.primary,
                    ),
                  ),
                ),
                const SizedBox(width: SiyaqSpacing.md),
                Expanded(
                  child: Text(
                    'A 16px icon in a 44px target',
                    style: context.type.role(
                      SiyaqTextRole.bodySmall,
                      script: SiyaqScript.latin,
                      color: c.textMuted,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'LONG CONTENT  · +50% expansion',
          children: [
            Container(
              padding: const EdgeInsets.all(SiyaqSpacing.md),
              decoration: BoxDecoration(
                color: c.surface,
                borderRadius: BorderRadius.circular(SiyaqRadius.card),
                border: Border.all(color: c.border),
              ),
              child: Text(
                context.isRtl
                    ? 'عنوان طويل جدًا لاختبار سلوك الالتفاف وتمدد النص في الواجهة العربية دون قطع.'
                    : 'A deliberately long label used to verify wrapping and text '
                          'expansion without clipping or overflow.',
                style: context.type.role(SiyaqTextRole.bodyMedium),
              ),
            ),
          ],
        ),
      ],
    );
  }
}
