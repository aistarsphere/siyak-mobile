import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_button.dart';
import '../foundation/siyaq_pressable.dart';
import '../foundation/siyaq_text.dart';

/// A revealed hint: a word and where it ranks.
@immutable
class SiyaqHintData {
  const SiyaqHintData({required this.word, required this.rank});

  final String word;
  final int rank;
}

/// A collapsible hint assistant.
///
/// Hints are an aid, not the game, so the panel gives its space back when it is
/// closed: collapsed it is a single tappable row, expanded it lists what has
/// been revealed and offers the next one.
///
/// Revealed hints are labelled by their **rank**, never by an ordinal like
/// "Hint #1" — the sequence number tells the player nothing about how useful the
/// word is, which is the only thing they need from it.
class SiyaqHintPanel extends StatelessWidget {
  const SiyaqHintPanel({
    super.key,
    required this.expanded,
    required this.onToggle,
    required this.title,
    required this.remainingLabel,
    required this.toggleSemanticLabel,
    required this.hints,
    required this.rankLabel,
    required this.emptyLabel,
    required this.revealLabel,
    required this.onRequestHint,
    this.loading = false,
    this.script,
    this.accent,
  });

  final bool expanded;
  final VoidCallback onToggle;

  /// Header label, e.g. "Hints".
  final String title;

  /// Localized remaining count, e.g. "2 left" or "No hints left".
  final String remainingLabel;

  /// Accessible name for the expand/collapse action — "Show hints" when
  /// collapsed, "Hide hints" when expanded. The chevron alone says nothing.
  final String toggleSemanticLabel;

  final List<SiyaqHintData> hints;

  /// Localized word for "rank", spoken before the number.
  final String rankLabel;

  /// Shown when nothing has been revealed yet.
  final String emptyLabel;

  final String revealLabel;

  /// Null disables the reveal action — no hints remaining, or the game is over.
  final VoidCallback? onRequestHint;

  final bool loading;

  /// Script of the hint words — the *gameplay* language.
  final SiyaqScript? script;

  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;

    return DecoratedBox(
      decoration: BoxDecoration(
        color: c.surface,
        borderRadius: BorderRadius.circular(SiyaqRadius.lg),
        border: Border.all(
          color: expanded ? a.withValues(alpha: 0.4) : c.border,
        ),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          SiyaqPressable(
            onTap: onToggle,
            semanticLabel: toggleSemanticLabel,
            focusRadius: SiyaqRadius.lg,
            enforceMinTarget: false,
            builder: (context, state) => Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: SiyaqSpacing.md,
                vertical: SiyaqSpacing.smd,
              ),
              child: Row(
                children: [
                  Icon(SiyaqIcons.hint, size: SiyaqIconSize.sm, color: a),
                  const SizedBox(width: SiyaqSpacing.sm),
                  Expanded(
                    child: SiyaqText(
                      title,
                      role: SiyaqTextRole.labelLarge,
                      maxLines: 1,
                    ),
                  ),
                  SiyaqText(
                    remainingLabel,
                    role: SiyaqTextRole.labelSmall,
                    color: c.textMuted,
                    maxLines: 1,
                  ),
                  const SizedBox(width: SiyaqSpacing.xs),
                  AnimatedRotation(
                    turns: expanded ? 0.5 : 0,
                    duration: context.motion.quick,
                    child: Icon(
                      Icons.keyboard_arrow_down_rounded,
                      size: SiyaqIconSize.md,
                      color: c.iconSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ),
          AnimatedSize(
            duration: context.motion.quick,
            curve: SiyaqMotion.easeOut,
            alignment: Alignment.topCenter,
            child: expanded
                ? Padding(
                    padding: const EdgeInsets.fromLTRB(
                      SiyaqSpacing.md,
                      0,
                      SiyaqSpacing.md,
                      SiyaqSpacing.md,
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        if (hints.isEmpty)
                          Padding(
                            padding: const EdgeInsets.only(
                              bottom: SiyaqSpacing.md,
                            ),
                            child: SiyaqText(
                              emptyLabel,
                              role: SiyaqTextRole.bodySmall,
                              color: c.textMuted,
                            ),
                          )
                        else
                          for (final h in hints)
                            _HintLine(
                              hint: h,
                              rankLabel: rankLabel,
                              script: script,
                              accent: a,
                            ),
                        SiyaqButton(
                          label: revealLabel,
                          icon: SiyaqIcons.hint,
                          type: SiyaqButtonType.secondary,
                          size: SiyaqButtonSize.medium,
                          fullWidth: true,
                          loading: loading,
                          accent: a,
                          onPressed: onRequestHint,
                        ),
                      ],
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
        ],
      ),
    );
  }
}

class _HintLine extends StatelessWidget {
  const _HintLine({
    required this.hint,
    required this.rankLabel,
    required this.accent,
    this.script,
  });

  final SiyaqHintData hint;
  final String rankLabel;
  final Color accent;
  final SiyaqScript? script;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Semantics(
      container: true,
      label: '${hint.word}, $rankLabel ${hint.rank}',
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.only(bottom: SiyaqSpacing.sm),
          child: Row(
            children: [
              Container(
                width: 6,
                height: 6,
                margin: const EdgeInsetsDirectional.only(end: SiyaqSpacing.sm),
                decoration: BoxDecoration(
                  color: accent,
                  shape: BoxShape.circle,
                ),
              ),
              // A revealed hint costs the player one of five, and its rank is
              // usually far better than anything they have guessed — yet on
              // device it rendered smaller and fainter than an ordinary guess
              // row. Weighted to match its value: the word reads as content,
              // the rank as a real number rather than a footnote.
              Expanded(
                child: SiyaqText(
                  hint.word,
                  role: SiyaqTextRole.bodyLarge,
                  script: script,
                  weight: FontWeight.w600,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: SiyaqSpacing.sm),
              SiyaqText.numeric(
                '#${hint.rank}',
                role: SiyaqTextRole.labelMedium,
                color: c.textSecondary,
                maxLines: 1,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
