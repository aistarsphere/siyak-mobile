import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_elevation.dart';
import '../../tokens/siyaq_icons.dart';
import '../../tokens/siyaq_spacing.dart';
import '../foundation/siyaq_icon.dart';

enum SiyaqIconTileSize {
  small(40, SiyaqIconSize.md, SiyaqRadius.md),
  medium(48, SiyaqIconSize.lg, SiyaqRadius.lg),
  large(56, SiyaqIconSize.lg, SiyaqRadius.xl);

  const SiyaqIconTileSize(this.box, this.icon, this.radius);

  final double box;
  final double icon;
  final double radius;
}

/// A decorative rounded tile holding a single icon.
///
/// The recurring "mode badge" motif: a filled or tinted square with a glyph,
/// used to head a hero card, a game-mode card or a section row. Extracted from
/// the Weekly hero, which is the first migrated user; the same shape appears on
/// Home (`_WeeklyHeroCard`, `_ModeTile`) and the Multiplayer hub.
///
/// Purely decorative — it carries no semantics. Put the meaning in the adjacent
/// heading, or use [SiyaqIcon] with a label if the glyph is the only cue. For a
/// *tappable* tile use [SiyaqIconButton] instead.
class SiyaqIconTile extends StatelessWidget {
  const SiyaqIconTile({
    super.key,
    required this.icon,
    this.size = SiyaqIconTileSize.large,
    this.accent,
    this.tinted = false,
    this.glow = false,
  });

  final IconData icon;
  final SiyaqIconTileSize size;

  /// Fill (or tint) colour. Defaults to `colors.primary`.
  final Color? accent;

  /// Soft translucent fill with a coloured glyph, rather than a solid fill.
  final bool tinted;

  /// Adds a coloured glow behind the tile — reserved for a hero.
  final bool glow;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final a = accent ?? c.primary;
    return Container(
      width: size.box,
      height: size.box,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        color: tinted ? a.withValues(alpha: 0.16) : a,
        borderRadius: BorderRadius.circular(size.radius),
        boxShadow: glow ? SiyaqGlow.of(a, blur: 24) : null,
      ),
      child: SiyaqIcon.decorative(
        icon,
        size: size.icon,
        color: tinted ? a : c.foregroundOn(a),
      ),
    );
  }
}
