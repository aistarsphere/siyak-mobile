import 'package:flutter/material.dart';

import '../../theme/siyag_theme.dart';
import 'siyag_tap.dart';

/// Mono uppercase kicker label (ui.tsx `Kicker`): 10px, 0.18em tracking.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: ST.mono(10, color: color ?? SC.textMute, letterSpacing: 1.8),
  );
}

/// Circular avatar (ui.tsx `Avatar`).
class SiyagAvatar extends StatelessWidget {
  const SiyagAvatar({
    super.key,
    required this.letter,
    this.size = 40,
    this.color,
    this.active = false,
    this.imageUrl,
  });

  final String letter;
  final double size;
  final Color? color;
  final bool active;

  /// Optional network avatar (e.g. the account `avatar_url`). Falls back to the
  /// [letter] tile while loading or on error.
  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SC.coral;
    final letterTile = Text(
      letter,
      style: TextStyle(
        fontFamily: SF.ar,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w600,
        color: active ? SC.onColor(c) : SC.textDim,
      ),
    );
    final hasImage = imageUrl != null && imageUrl!.isNotEmpty;
    return Container(
      width: size,
      height: size,
      alignment: Alignment.center,
      clipBehavior: hasImage ? Clip.antiAlias : Clip.none,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: active ? c : SC.surfaceHi,
        border: active ? null : Border.all(color: SC.line),
      ),
      child: hasImage
          ? Image.network(
              imageUrl!,
              width: size,
              height: size,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) => Center(child: letterTile),
              loadingBuilder: (_, child, progress) =>
                  progress == null ? child : Center(child: letterTile),
            )
          : letterTile,
    );
  }
}

/// Full-width primary button (ui.tsx `PrimaryButton`): rounded-2xl, py-4,
/// colored fill, dark label when fill is a brand color.
class SiyagPrimaryButton extends StatelessWidget {
  const SiyagPrimaryButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
    this.color,
    this.busy = false,
    this.fullWidth = true,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;
  final Color? color;
  final bool busy;

  /// Stretch to the parent's width (the default, for column CTAs). Set to
  /// `false` when placed directly inside a [Row] — a full-width child in an
  /// unbounded Row throws "BoxConstraints forces an infinite width".
  final bool fullWidth;

  @override
  Widget build(BuildContext context) {
    final c = color ?? SC.coral;
    final fg = SC.onColor(c); // readable on graphite/gold/green fills
    return SiyagTap(
      onTap: busy ? null : onTap,
      child: Opacity(
        opacity: onTap == null && !busy ? 0.5 : 1,
        child: Container(
          width: fullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          decoration: BoxDecoration(
            color: c,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            mainAxisSize: fullWidth ? MainAxisSize.max : MainAxisSize.min,
            children: [
              if (busy)
                SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2.2, color: fg),
                )
              else if (icon != null)
                Icon(icon, size: 16, color: fg),
              if (icon != null || busy) const SizedBox(width: 8),
              Text(
                label,
                style: ST.ar(15, weight: FontWeight.w600, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Full-width ghost button (ui.tsx `GhostButton`): surfaceHi fill.
class SiyagGhostButton extends StatelessWidget {
  const SiyagGhostButton({
    super.key,
    required this.label,
    this.onTap,
    this.icon,
  });

  final String label;
  final VoidCallback? onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return SiyagTap(
      onTap: onTap,
      child: Opacity(
        opacity: onTap == null ? 0.5 : 1,
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(vertical: 16),
          decoration: BoxDecoration(
            color: SC.surfaceHi,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: SC.text),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: ST.ar(15, weight: FontWeight.w500, color: SC.text),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Screen header (ui.tsx `ScreenHeader`): kicker + 30px bold title, px-6 pt-12.
class SiyagScreenHeader extends StatelessWidget {
  const SiyagScreenHeader({
    super.key,
    required this.kicker,
    required this.title,
  });

  final String kicker;
  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 48, 24, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Kicker(kicker),
          const SizedBox(height: 4),
          Text(title, style: ST.ar(30, weight: FontWeight.w700, height: 1.1)),
        ],
      ),
    );
  }
}
