import 'package:flutter/material.dart';

import '../../components/foundation/siyaq_button.dart';
import '../../components/foundation/siyaq_divider.dart';
import '../../components/foundation/siyaq_icon.dart';
import '../../components/foundation/siyaq_icon_button.dart';
import '../../components/foundation/siyaq_surface.dart';
import '../../components/foundation/siyaq_text.dart';
import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_elevation.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import 'token_pages.dart';

/// Bilingual sample copy, so every component is validated with real Arabic and
/// English rather than lorem placeholder.
String _t(BuildContext context, String ar, String en) =>
    context.isRtl ? ar : en;

/// ── Buttons ─────────────────────────────────────────────────────────────────

class ButtonGalleryPage extends StatelessWidget {
  const ButtonGalleryPage({super.key});

  @override
  Widget build(BuildContext context) {
    final label = _t(context, 'ابدأ اللعب', 'Start Playing');

    Widget matrix(SiyaqButtonSize size) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final type in SiyaqButtonType.values) ...[
          SiyaqText(
            type.name,
            role: SiyaqTextRole.labelSmall,
            script: SiyaqScript.mono,
            color: context.colors.textMuted,
          ),
          const SizedBox(height: SiyaqSpacing.xxs),
          Wrap(
            spacing: SiyaqSpacing.sm,
            runSpacing: SiyaqSpacing.sm,
            children: [
              // Default / pressed-capable
              SiyaqButton(
                label: label,
                type: type,
                size: size,
                onPressed: () {},
              ),
              // Disabled — null callback
              SiyaqButton(label: label, type: type, size: size),
              // Loading
              SiyaqButton(
                label: label,
                type: type,
                size: size,
                loading: true,
                onPressed: () {},
              ),
              // With icons — leading + trailing to check RTL mirroring
              SiyaqButton(
                label: label,
                type: type,
                size: size,
                icon: SiyaqIcons.hint,
                trailingIcon: SiyaqIcons.trendUp,
                onPressed: () {},
              ),
            ],
          ),
          const SizedBox(height: SiyaqSpacing.md),
        ],
      ],
    );

    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'BUTTON · LARGE · 4 types × default/disabled/loading/icons',
          children: [matrix(SiyaqButtonSize.large)],
        ),
        GallerySection(
          title: 'BUTTON · MEDIUM',
          children: [matrix(SiyaqButtonSize.medium)],
        ),
        GallerySection(
          title: 'FULL WIDTH',
          children: [
            SiyaqButton(label: label, fullWidth: true, onPressed: () {}),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqButton(
              label: label,
              type: SiyaqButtonType.secondary,
              fullWidth: true,
              onPressed: () {},
            ),
          ],
        ),
        GallerySection(
          title: 'LONG LABEL · must wrap, never clip',
          children: [
            SiyaqButton(
              label: _t(
                context,
                'زر بعنوان طويل جدًا للتحقق من الالتفاف وتمدد النص',
                'A button with a deliberately long label to verify wrapping',
              ),
              fullWidth: true,
              onPressed: () {},
            ),
          ],
        ),
        GallerySection(
          title: 'KEYBOARD FOCUS · Tab to move, Space/Enter to activate',
          children: [
            Row(
              children: [
                SiyaqButton(
                  label: _t(context, 'الأول', 'First'),
                  size: SiyaqButtonSize.medium,
                  onPressed: () {},
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                SiyaqButton(
                  label: _t(context, 'الثاني', 'Second'),
                  size: SiyaqButtonSize.medium,
                  type: SiyaqButtonType.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// ── Icon buttons, surfaces, dividers, text ──────────────────────────────────

class ComponentGalleryPage extends StatefulWidget {
  const ComponentGalleryPage({super.key});

  @override
  State<ComponentGalleryPage> createState() => _ComponentGalleryPageState();
}

class _ComponentGalleryPageState extends State<ComponentGalleryPage> {
  int _selected = 1;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    return ListView(
      padding: const EdgeInsets.all(SiyaqSpacing.lg),
      children: [
        GallerySection(
          title: 'ICON BUTTON · 3 types × 3 sizes · 32px keeps a 44px target',
          children: [
            for (final type in SiyaqIconButtonType.values) ...[
              SiyaqText(
                type.name,
                role: SiyaqTextRole.labelSmall,
                script: SiyaqScript.mono,
                color: c.textMuted,
              ),
              const SizedBox(height: SiyaqSpacing.xxs),
              Wrap(
                spacing: SiyaqSpacing.md,
                runSpacing: SiyaqSpacing.sm,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  for (final size in SiyaqIconButtonSize.values)
                    SiyaqIconButton(
                      icon: SiyaqIcons.hint,
                      semanticLabel: 'Reveal hint',
                      type: type,
                      size: size,
                      onPressed: () {},
                    ),
                  SiyaqIconButton(
                    icon: SiyaqIcons.close,
                    semanticLabel: 'Close',
                    type: type,
                  ),
                  SiyaqIconButton(
                    icon: SiyaqIcons.hint,
                    semanticLabel: 'Loading',
                    type: type,
                    loading: true,
                    onPressed: () {},
                  ),
                  SiyaqIconButton(
                    icon: SiyaqIcons.settings,
                    semanticLabel: 'Settings',
                    type: type,
                    circular: false,
                    onPressed: () {},
                  ),
                ],
              ),
              const SizedBox(height: SiyaqSpacing.md),
            ],
          ],
        ),
        GallerySection(
          title: 'SURFACE · 5 variants',
          children: [
            for (final v in SiyaqSurfaceVariant.values) ...[
              SiyaqSurface(
                variant: v,
                child: SiyaqText(v.name, role: SiyaqTextRole.bodyMedium),
              ),
              const SizedBox(height: SiyaqSpacing.sm),
            ],
          ],
        ),
        GallerySection(
          title: 'SURFACE · interactive · tap to select',
          children: [
            Row(
              children: [
                for (var i = 0; i < 3; i++) ...[
                  if (i > 0) const SizedBox(width: SiyaqSpacing.sm),
                  Expanded(
                    child: SiyaqSurface(
                      variant: SiyaqSurfaceVariant.interactive,
                      selected: _selected == i,
                      semanticLabel: 'Option ${i + 1}',
                      onTap: () => setState(() => _selected = i),
                      child: Center(
                        child: SiyaqText(
                          '${i + 1}',
                          role: SiyaqTextRole.headingMedium,
                          script: SiyaqScript.mono,
                        ),
                      ),
                    ),
                  ),
                ],
              ],
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqSurface(
              variant: SiyaqSurfaceVariant.interactive,
              disabled: true,
              onTap: () {},
              child: SiyaqText(
                _t(context, 'غير متاح', 'Disabled surface'),
                role: SiyaqTextRole.bodyMedium,
              ),
            ),
          ],
        ),
        GallerySection(
          title: 'SURFACE · game-mode accents',
          children: [
            Wrap(
              spacing: SiyaqSpacing.sm,
              runSpacing: SiyaqSpacing.sm,
              children: [
                for (final (name, accent) in <(String, Color)>[
                  ('solo', c.gameSolo),
                  ('weekly', c.gameWeekly),
                  ('multiplayer', c.gameMultiplayer),
                  ('ranked', c.gameRanked),
                  ('practice', c.gamePractice),
                ])
                  SiyaqSurface(
                    variant: SiyaqSurfaceVariant.accent,
                    accent: accent,
                    padding: const EdgeInsets.symmetric(
                      horizontal: SiyaqSpacing.md,
                      vertical: SiyaqSpacing.sm,
                    ),
                    child: SiyaqText(
                      name,
                      role: SiyaqTextRole.labelMedium,
                      color: accent,
                    ),
                  ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'SURFACE · elevation',
          children: [
            Wrap(
              spacing: SiyaqSpacing.md,
              runSpacing: SiyaqSpacing.md,
              children: [
                for (final (name, e) in SiyaqElevation.scale)
                  SiyaqSurface(
                    elevation: e,
                    width: 110,
                    child: SiyaqText(name, role: SiyaqTextRole.bodySmall),
                  ),
              ],
            ),
          ],
        ),
        GallerySection(
          title: 'TINTED SURFACE · status tones',
          children: [
            for (final tone in SiyaqTone.values) ...[
              SiyaqTintedSurface(
                tone: tone,
                child: SiyaqText(
                  tone.name,
                  role: SiyaqTextRole.bodyMedium,
                  color: tone.resolve(c).$1,
                ),
              ),
              const SizedBox(height: SiyaqSpacing.sm),
            ],
          ],
        ),
        GallerySection(
          title: 'DIVIDER · mirrors under RTL',
          children: [
            const SiyaqDivider(),
            const SizedBox(height: SiyaqSpacing.lg),
            SiyaqDivider.labelled(_t(context, 'أو', 'OR')),
          ],
        ),
        GallerySection(
          title: 'ICON · meaningful vs decorative',
          children: [
            Row(
              children: [
                SiyaqIcon(
                  SiyaqIcons.hot,
                  semanticLabel: _t(context, 'ملتهب', 'Hot'),
                  color: c.error,
                ),
                const SizedBox(width: SiyaqSpacing.md),
                SiyaqIcon.decorative(SiyaqIcons.trendUp, color: c.success),
                const SizedBox(width: SiyaqSpacing.md),
                Expanded(
                  child: SiyaqText(
                    _t(
                      context,
                      'الأولى معلنة لقارئ الشاشة، والثانية مخفية.',
                      'The first is announced; the second is hidden.',
                    ),
                    role: SiyaqTextRole.bodySmall,
                    color: c.textMuted,
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
