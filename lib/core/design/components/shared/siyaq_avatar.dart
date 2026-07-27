import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_typography.dart';

/// Avatar size, matching Figma's `Siyaq/Player Avatar` `Size` axis.
enum SiyaqAvatarSize {
  small(36),
  medium(44),
  large(60),
  xlarge(80);

  const SiyaqAvatarSize(this.diameter);
  final double diameter;

  /// Initial glyph size — a fixed fraction of the circle so the letter is
  /// optically centred at every size.
  double get letterSize => diameter * 0.4;
}

/// Presence ring, matching Figma's `Status` axis.
enum SiyaqPresence { none, online, offline, reconnecting }

/// Player avatar: network image with a letter fallback.
///
/// Adapted from `SiyagAvatar`, which had a single free-form `size` and no
/// presence ring (audit §5). The network/letter fallback behaviour is preserved
/// exactly — it is correct and load-bearing.
///
/// The initial is derived from a grapheme cluster, not `String[0]`, so Arabic
/// letters with diacritics and emoji-range characters are not split.
class SiyaqAvatar extends StatelessWidget {
  const SiyaqAvatar({
    super.key,
    required this.name,
    this.imageUrl,
    this.size = SiyaqAvatarSize.medium,
    this.presence = SiyaqPresence.none,
    this.accent,
    this.emphasised = true,
    this.semanticLabel,
  });

  /// Used for the initial when no [imageUrl] loads.
  final String name;
  final String? imageUrl;
  final SiyaqAvatarSize size;
  final SiyaqPresence presence;

  /// Fill for the emphasised state. Defaults to `colors.primary`.
  final Color? accent;

  /// Filled with [accent] (self / active) rather than a neutral surface.
  final bool emphasised;

  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final fill = accent ?? c.primary;
    final initial = name.characters.isNotEmpty
        ? name.characters.first
        : '؟'; // Arabic question mark — never an empty circle

    final letter = Text(
      initial,
      style: context.type.custom(
        script: SiyaqScript.arabic,
        size: size.letterSize,
        weight: FontWeight.w600,
        color: emphasised ? c.foregroundOn(fill) : c.textSecondary,
      ),
    );

    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;

    Widget avatar = Container(
      width: size.diameter,
      height: size.diameter,
      alignment: Alignment.center,
      clipBehavior: hasImage ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: emphasised ? fill : c.surfaceElevated,
        border: emphasised ? null : Border.all(color: c.border),
      ),
      child: hasImage
          ? Image.network(
              imageUrl!,
              width: size.diameter,
              height: size.diameter,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(child: letter),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Center(child: letter),
            )
          : letter,
    );

    if (presence != SiyaqPresence.none) {
      avatar = Stack(
        clipBehavior: Clip.none,
        children: [
          avatar,
          PositionedDirectional(
            end: 0,
            bottom: 0,
            child: _PresenceDot(presence: presence, parent: size.diameter),
          ),
        ],
      );
    }

    return Semantics(
      // Its own node, so the avatar is not merged into the adjacent name text.
      container: true,
      label: semanticLabel ?? name,
      image: true,
      child: ExcludeSemantics(child: avatar),
    );
  }
}

class _PresenceDot extends StatelessWidget {
  const _PresenceDot({required this.presence, required this.parent});

  final SiyaqPresence presence;
  final double parent;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    final d = (parent * 0.28).clamp(8.0, 18.0);
    final colour = switch (presence) {
      SiyaqPresence.online => c.success,
      SiyaqPresence.reconnecting => c.warning,
      _ => c.textDisabled,
    };
    return Container(
      width: d,
      height: d,
      decoration: BoxDecoration(
        color: colour,
        shape: BoxShape.circle,
        // Ringed in the page background so the dot reads on any surface.
        border: Border.all(color: c.background, width: d * 0.18),
      ),
    );
  }
}
