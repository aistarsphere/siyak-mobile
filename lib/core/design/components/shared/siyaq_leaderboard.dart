import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_colors.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_motion.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_text.dart';
import 'siyaq_avatar.dart';

/// A small icon + value pair — attempts, elapsed time, hints.
///
/// Trailing metadata on a list row. The value is mono so columns align down the
/// list, and the icon is decorative because [semanticLabel] carries the meaning.
class SiyaqMetaStat extends StatelessWidget {
  const SiyaqMetaStat({
    super.key,
    required this.value,
    required this.icon,
    required this.semanticLabel,
    this.color,
  });

  final String value;
  final IconData icon;

  /// Spoken form, e.g. "12 attempts" — without it a screen reader reads a bare
  /// number next to an unlabelled glyph.
  final String semanticLabel;

  final Color? color;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.textMuted;
    return Semantics(
      container: true,
      label: semanticLabel,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SiyaqText.numeric(
              value,
              role: SiyaqTextRole.labelSmall,
              color: tint,
            ),
            const SizedBox(width: SiyaqSpacing.xxxs),
            Icon(icon, size: SiyaqIconSize.xs, color: tint),
          ],
        ),
      ),
    );
  }
}

/// One row of a leaderboard.
///
/// Covers Figma's `Siyaq/Leaderboard Row` (`Top1` / `Top2` / `Top3` / `Regular`
/// / `Self`). The medal tint for the top three and the highlighted `Self`
/// treatment are variants of one component rather than branches in a screen.
class SiyaqLeaderboardRow extends StatelessWidget {
  const SiyaqLeaderboardRow({
    super.key,
    required this.placement,
    required this.label,
    this.isSelf = false,
    this.solved = false,
    this.solvedLabel,
    this.trailing = const [],
    this.onTap,
  });

  final int placement;
  final String label;

  /// The signed-in player's own row — emphasised and outlined.
  final bool isSelf;

  final bool solved;

  /// Accessible name for the solved marker.
  final String? solvedLabel;

  /// Metadata such as [SiyaqMetaStat]s.
  final List<Widget> trailing;

  final VoidCallback? onTap;

  /// Below this width (scaled by the active text scale) [trailing] metadata moves
  /// to a second line.
  ///
  /// The player's name is the row's primary content, so when space runs short the
  /// metadata yields rather than the name truncating to "…Ab" — which is what
  /// happened at 320px / 1.6× before this existed.
  final double stackTrailingBelow = 300;

  /// Medal tint for the podium places; `null` for the rest.
  static Color? medalColor(int placement, SiyaqColors c) => switch (placement) {
    1 => c.primary,
    2 => c.textSecondary,
    3 => c.info,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final medal = medalColor(placement, c);
    final rankColor = isSelf ? c.primary : (medal ?? c.textMuted);

    return Container(
      margin: EdgeInsets.symmetric(vertical: isSelf ? SiyaqSpacing.xs : 0),
      padding: EdgeInsets.symmetric(
        horizontal: isSelf ? SiyaqSpacing.lg : SiyaqSpacing.sm,
        vertical: SiyaqSpacing.md,
      ),
      decoration: isSelf
          ? BoxDecoration(
              color: c.surface,
              borderRadius: BorderRadius.circular(SiyaqRadius.card),
              border: Border.all(color: c.primary.withValues(alpha: 0.33)),
            )
          : BoxDecoration(
              border: Border(bottom: BorderSide(color: c.border)),
            ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          final stack =
              trailing.isNotEmpty &&
              constraints.maxWidth < stackTrailingBelow * scale;

          final meta = Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < trailing.length; i++) ...[
                if (i > 0) const SizedBox(width: SiyaqSpacing.smd),
                trailing[i],
              ],
            ],
          );

          final name = SiyaqText(
            label,
            role: SiyaqTextRole.bodyLarge,
            weight: isSelf ? FontWeight.w500 : FontWeight.w400,
            color: isSelf ? c.textPrimary : c.textSecondary,
            maxLines: 1,
          );

          final solvedMark = solved
              ? Semantics(
                  container: true,
                  label: solvedLabel,
                  child: ExcludeSemantics(
                    child: Icon(
                      SiyaqIcons.success,
                      size: SiyaqIconSize.sm,
                      color: c.success,
                    ),
                  ),
                )
              : null;

          return Row(
            children: [
              // Fixed rank gutter so names align down the list regardless of
              // digit count.
              ConstrainedBox(
                constraints: const BoxConstraints(minWidth: 26),
                child: SiyaqText.numeric(
                  '$placement',
                  role: SiyaqTextRole.labelLarge,
                  color: rankColor,
                  maxLines: 1,
                ),
              ),
              const SizedBox(width: SiyaqSpacing.sm),
              SiyaqAvatar(
                name: label,
                size: SiyaqAvatarSize.small,
                emphasised: isSelf || medal != null,
                accent: medal,
              ),
              const SizedBox(width: SiyaqSpacing.md),
              Expanded(
                child: stack
                    ? Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            children: [
                              Expanded(child: name),
                              if (solvedMark != null) ...[
                                const SizedBox(width: SiyaqSpacing.sm),
                                solvedMark,
                              ],
                            ],
                          ),
                          const SizedBox(height: SiyaqSpacing.xxs),
                          meta,
                        ],
                      )
                    : name,
              ),
              if (!stack) ...[
                if (solvedMark != null) ...[
                  const SizedBox(width: SiyaqSpacing.sm),
                  solvedMark,
                ],
                const SizedBox(width: SiyaqSpacing.smd),
                meta,
              ],
            ],
          );
        },
      ),
    );
  }
}

/// One podium place.
@immutable
class SiyaqPodiumPlace {
  const SiyaqPodiumPlace({
    required this.placement,
    required this.label,
    this.imageUrl,
  });

  final int placement;
  final String label;
  final String? imageUrl;
}

/// Top-three podium in 2·1·3 order with animated risers.
///
/// Figma defines no podium component, so the arrangement is specified here: the
/// winner sits centre on the tallest riser, tinted with the medal colours from
/// [SiyaqLeaderboardRow.medalColor] so podium and list agree.
///
/// Renders nothing unless exactly three places are supplied — a partial podium
/// reads as a bug.
class SiyaqPodium extends StatelessWidget {
  const SiyaqPodium({super.key, required this.places, this.animate = true});

  /// Ordered 1st, 2nd, 3rd.
  final List<SiyaqPodiumPlace> places;

  final bool animate;

  static const _heights = <double>[70, 96, 56];

  @override
  Widget build(BuildContext context) {
    if (places.length < 3) return const SizedBox.shrink();
    final c = context.colors;
    // Visual order 2 · 1 · 3.
    final order = [places[1], places[0], places[2]];

    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: SiyaqSpacing.lg,
        vertical: SiyaqSpacing.sm,
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          for (var i = 0; i < 3; i++) ...[
            if (i > 0) const SizedBox(width: SiyaqSpacing.md),
            Expanded(
              child: _Place(
                place: order[i],
                accent:
                    SiyaqLeaderboardRow.medalColor(order[i].placement, c) ??
                    c.textSecondary,
                height: _heights[i],
                winner: i == 1,
                animate: animate,
                delayIndex: i,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _Place extends StatelessWidget {
  const _Place({
    required this.place,
    required this.accent,
    required this.height,
    required this.winner,
    required this.animate,
    required this.delayIndex,
  });

  final SiyaqPodiumPlace place;
  final Color accent;
  final double height;
  final bool winner;
  final bool animate;
  final int delayIndex;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;

    final riser = Container(
      width: double.infinity,
      alignment: Alignment.topCenter,
      padding: const EdgeInsets.only(top: SiyaqSpacing.sm),
      decoration: BoxDecoration(
        color: winner ? c.primaryContainer : c.surface,
        borderRadius: const BorderRadius.vertical(
          top: Radius.circular(SiyaqRadius.card),
        ),
        border: Border(top: BorderSide(color: accent, width: 2)),
      ),
      child: SiyaqText.numeric(
        '${place.placement}',
        role: SiyaqTextRole.headingMedium,
        color: accent,
      ),
    );

    return Semantics(
      container: true,
      label: '${place.label} — ${place.placement}',
      child: ExcludeSemantics(
        child: Column(
          children: [
            SiyaqAvatar(
              name: place.label,
              imageUrl: place.imageUrl,
              size: winner ? SiyaqAvatarSize.large : SiyaqAvatarSize.medium,
              accent: accent,
              emphasised: winner,
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqText(
              place.label,
              role: SiyaqTextRole.bodySmall,
              color: c.textSecondary,
              align: TextAlign.center,
              maxLines: 1,
            ),
            const SizedBox(height: SiyaqSpacing.sm),
            if (!animate)
              SizedBox(height: height, child: riser)
            else
              TweenAnimationBuilder<double>(
                tween: Tween(begin: 0, end: height),
                duration: Duration(
                  milliseconds:
                      SiyaqMotion.barFill.inMilliseconds + delayIndex * 80,
                ),
                curve: SiyaqMotion.easeOutQuint,
                builder: (context, h, child) =>
                    SizedBox(height: h, child: child),
                child: riser,
              ),
          ],
        ),
      ),
    );
  }
}
