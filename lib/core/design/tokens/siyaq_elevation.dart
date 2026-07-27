import 'package:flutter/material.dart';

/// Named elevation levels.
///
/// Figma names 6 effect styles (`Low`, `Medium`, `High`, `Glow/Saffron`,
/// `Glow/Teal`, `Glow/Purple`) but defines **no blur, spread, offset or opacity
/// for any of them** (audit §3, §11-20). The values below are therefore chosen
/// locally, tuned to the existing shadow tokens so nothing shifts visually.
///
/// Shadow colour comes from the active palette rather than being baked in, so
/// elevation reads correctly in both themes — Dark uses a heavier alpha
/// (`0x66`) than Light (`0x14`).
enum SiyaqElevation {
  /// Flat — no shadow. The app's default; most surfaces use borders, not depth.
  none(0, 0),

  /// Low — resting cards that need separation from the canvas.
  low(2, 6),

  /// Medium — menus, raised sheets.
  medium(4, 12),

  /// High — dialogs, modal surfaces.
  high(8, 24);

  const SiyaqElevation(this.dy, this.blur);

  final double dy;
  final double blur;

  /// Resolve to a box shadow list using the theme's [shadowColor].
  List<BoxShadow> shadows(Color shadowColor) => this == SiyaqElevation.none
      ? const []
      : [
          BoxShadow(
            color: shadowColor,
            offset: Offset(0, dy),
            blurRadius: blur,
          ),
        ];

  static const scale = <(String, SiyaqElevation)>[
    ('none', none),
    ('low', low),
    ('medium', medium),
    ('high', high),
  ];
}

/// Coloured glow, for game-mode emphasis (Figma's `Glow/*` effect styles).
///
/// Values are local; Figma provides none.
class SiyaqGlow {
  SiyaqGlow._();

  static List<BoxShadow> of(
    Color accent, {
    double blur = 16,
    double alpha = 0.35,
  }) => [
    BoxShadow(
      color: accent.withValues(alpha: alpha),
      blurRadius: blur,
    ),
  ];
}
