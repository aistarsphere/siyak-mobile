import 'package:flutter/material.dart';

import '../../design/theme/context_tokens.dart';
import '../../design/theme/legacy_type_bridge.dart';
import '../../design/tokens/siyaq_typography.dart';
import 'siyag_tap.dart';

/// Mono uppercase kicker label (ui.tsx `Kicker`): 10px, 0.18em tracking.
class Kicker extends StatelessWidget {
  const Kicker(this.text, {super.key, this.color});

  final String text;
  final Color? color;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    style: context.legacyType.mono(
      10,
      color: color ?? context.colors.textMuted,
      letterSpacing: 1.8,
    ),
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
    final c = color ?? context.colors.primary;
    final letterTile = Text(
      letter,
      style: TextStyle(
        fontFamily: SiyaqFonts.arabic,
        fontSize: size * 0.4,
        fontWeight: FontWeight.w600,
        color: active
            ? context.colors.onColorLegacy(c)
            : context.colors.textSecondary,
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
        color: active ? c : context.colors.surfaceElevated,
        border: active ? null : Border.all(color: context.colors.border),
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
    final c = color ?? context.colors.primary;
    final fg = context.colors.onColorLegacy(
      c,
    ); // readable on graphite/gold/green fills
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
                style: context.legacyType.ar(
                  15,
                  weight: FontWeight.w600,
                  color: fg,
                ),
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
            color: context.colors.surfaceElevated,
            borderRadius: BorderRadius.circular(16),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (icon != null) ...[
                Icon(icon, size: 16, color: context.colors.textPrimary),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: context.legacyType.ar(
                  15,
                  weight: FontWeight.w500,
                  color: context.colors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// `SiyagScreenHeader` was removed once the Leaderboard migration replaced its
// only remaining call site with `SiyaqScreenHeader`. Other screens use
// `SiyagTopBar`, which is unrelated and still live.

/// A consistent confirm/cancel dialog for destructive actions (leave, forfeit,
/// sign-out). Returns `true` when the user confirms. The confirm button is
/// coloured [context.colors.error] when [destructive] (the default).
Future<bool> showSiyagConfirm(
  BuildContext context, {
  required TextDirection direction,
  required String title,
  required String body,
  required String confirmLabel,
  required String cancelLabel,
  bool destructive = true,
}) async {
  final ok = await showDialog<bool>(
    context: context,
    barrierColor: context.colors.scrim,
    builder: (ctx) => Directionality(
      textDirection: direction,
      child: Dialog(
        backgroundColor: context.colors.surface,
        insetPadding: const EdgeInsets.symmetric(horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(22, 24, 22, 18),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                title,
                textAlign: TextAlign.center,
                style: context.legacyType.ar(18, weight: FontWeight.w700),
              ),
              const SizedBox(height: 10),
              Text(
                body,
                textAlign: TextAlign.center,
                style: context.legacyType.ar(
                  13.5,
                  color: context.colors.textMuted,
                  height: 1.5,
                ),
              ),
              const SizedBox(height: 22),
              SiyagPrimaryButton(
                label: confirmLabel,
                color: destructive ? context.colors.error : null,
                onTap: () => Navigator.of(ctx).pop(true),
              ),
              const SizedBox(height: 8),
              SiyagGhostButton(
                label: cancelLabel,
                onTap: () => Navigator.of(ctx).pop(false),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  return ok ?? false;
}
