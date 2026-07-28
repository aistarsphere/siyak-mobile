import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_spacing.dart';
import '../../tokens/siyaq_typography.dart';
import '../foundation/siyaq_surface.dart';
import '../foundation/siyaq_text.dart';
import 'siyaq_avatar.dart';
import 'siyaq_chip.dart';

/// A dot + label status line — connection state, presence, room state.
///
/// Deliberately not a chip: this reads as inline status text, and a pill would
/// over-weight it next to real controls.
class SiyaqStatusIndicator extends StatelessWidget {
  const SiyaqStatusIndicator({
    super.key,
    required this.label,
    required this.tone,
    this.pulse = false,
  });

  final String label;

  /// Resolves both the dot and the label colour.
  final SiyaqTone tone;

  /// Hollow dot rather than filled — for a transitional state such as
  /// "reconnecting", where a solid dot would read as settled.
  final bool pulse;

  @override
  Widget build(BuildContext context) {
    final colour = tone.resolve(context.colors).$1;
    return Semantics(
      container: true,
      label: label,
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color: pulse ? Colors.transparent : colour,
                shape: BoxShape.circle,
                border: pulse ? Border.all(color: colour, width: 2) : null,
              ),
            ),
            const SizedBox(width: SiyaqSpacing.sm),
            Flexible(
              child: SiyaqText(
                label,
                role: SiyaqTextRole.bodySmall,
                color: colour,
                maxLines: 1,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A player in a room, lobby or directory.
///
/// Covers Figma's `Siyaq/Player Row` (`Self` / `Opponent` / `Host` / `Ready` /
/// `Waiting`) and replaces the near-duplicate participant rows in the lobby, the
/// invite sheet and the players directory.
///
/// The whole row is one semantics node whose label folds in the role and
/// connection state — a screen reader should hear "Sara, host, offline", not
/// three disconnected fragments. Anything in [trailing] is therefore excluded
/// from semantics when [onTap] is set, so pass its meaning via [statusLabel].
class SiyaqPlayerRow extends StatelessWidget {
  const SiyaqPlayerRow({
    super.key,
    required this.name,
    this.subtitle,
    this.avatarUrl,
    this.presence = SiyaqPresence.none,
    this.roleLabel,
    this.roleAccent,
    this.isSelf = false,
    this.selfSuffix,
    this.statusLabel,
    this.trailing,
    this.onTap,
    this.accent,
  });

  final String name;

  /// Secondary line — a public player id, a rating, a join time.
  final String? subtitle;

  final String? avatarUrl;
  final SiyaqPresence presence;

  /// Short role tag rendered as a chip: host, ready, waiting.
  final String? roleLabel;
  final Color? roleAccent;

  /// The signed-in player's own row — outlined and emphasised.
  final bool isSelf;

  /// Appended to [name] for the self row, e.g. "(you)".
  final String? selfSuffix;

  /// Spoken status appended to the row's announcement (connection, readiness).
  final String? statusLabel;

  final Widget? trailing;
  final VoidCallback? onTap;

  /// Avatar fill. Defaults to `colors.success` for a participant.
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final displayName = isSelf && selfSuffix != null
        ? '$name ($selfSuffix)'
        : name;

    final announcement = [displayName, ?roleLabel, ?statusLabel].join(', ');

    return SiyaqSurface(
      onTap: onTap,
      selected: isSelf,
      accent: accent ?? c.success,
      semanticLabel: announcement,
      padding: const EdgeInsets.symmetric(
        horizontal: SiyaqSpacing.lg,
        vertical: SiyaqSpacing.md,
      ),
      child: LayoutBuilder(
        builder: (context, box) {
          final scale = MediaQuery.textScalerOf(context).scale(1);
          // Below this the role chip cannot share a line with the name without
          // pushing the row past its edge — a long label ("Your turn") at 2.0x
          // on a 320px screen overflowed by 15px. It moves under the name
          // instead, which is also where it reads better when it is that wide.
          //
          // 200 is deliberately tight: a 360dp phone at 1.0x has ~290px here and
          // must keep the chip inline (a first pass used 300 and stacked the
          // Lobby's host badge on an ordinary handset), while 320px at 1.6x has
          // ~248px and must stack.
          final stackRole = roleLabel != null && box.maxWidth < 200 * scale;

          final chip = roleLabel == null
              ? null
              : SiyaqChip(
                  label: roleLabel!,
                  variant: SiyaqChipVariant.accent,
                  accent: roleAccent ?? c.primary,
                );

          return Row(
            children: [
              SiyaqAvatar(
                name: name,
                imageUrl: avatarUrl,
                size: SiyaqAvatarSize.small,
                presence: presence,
                accent: accent ?? (roleAccent ?? c.success),
              ),
              const SizedBox(width: SiyaqSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SiyaqText(
                      displayName,
                      role: SiyaqTextRole.bodyLarge,
                      weight: isSelf ? FontWeight.w600 : FontWeight.w500,
                      maxLines: 1,
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: SiyaqSpacing.xxxs),
                      SiyaqText.numeric(
                        subtitle!,
                        role: SiyaqTextRole.labelSmall,
                        color: c.textMuted,
                        maxLines: 1,
                      ),
                    ],
                    if (stackRole) ...[
                      const SizedBox(height: SiyaqSpacing.xs),
                      Align(
                        alignment: AlignmentDirectional.centerStart,
                        child: chip,
                      ),
                    ],
                  ],
                ),
              ),
              if (chip != null && !stackRole) ...[
                const SizedBox(width: SiyaqSpacing.sm),
                chip,
              ],
              if (trailing != null) ...[
                const SizedBox(width: SiyaqSpacing.sm),
                trailing!,
              ],
            ],
          );
        },
      ),
    );
  }
}
