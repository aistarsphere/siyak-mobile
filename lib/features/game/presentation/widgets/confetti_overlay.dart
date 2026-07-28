import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/design/theme/context_tokens.dart';
import '../../../../core/design/tokens/siyaq_motion.dart';

/// Solved-screen confetti: 150 pieces, 4–12 px squares/circles, random opacity,
/// falling past the bottom while rotating up to ±360°, 2–5 s each, then gone.
///
/// The palette is drawn from **semantic roles** rather than the fixed hex list
/// the original port hardcoded, so the celebration belongs to whichever theme is
/// active instead of sitting at fixed brightness on a light background.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, this.pieceCount = 150, this.colors});

  final int pieceCount;

  /// Optional palette override. Defaults to the theme's accent roles.
  final List<Color>? colors;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiPiece {
  _ConfettiPiece(math.Random rng, int paletteSize)
    : x = rng.nextDouble(),
      size = rng.nextDouble() * 8 + 4,
      colorIndex = rng.nextInt(paletteSize),
      circle = rng.nextBool(),
      opacity = rng.nextDouble(),
      rotation = (rng.nextDouble() * 720 - 360) * math.pi / 180,
      duration =
          SiyaqMotion.confettiMin.inMilliseconds +
          rng.nextInt(
            SiyaqMotion.confettiMax.inMilliseconds -
                SiyaqMotion.confettiMin.inMilliseconds,
          );

  final double x; // horizontal position, fraction of width
  final double size;

  /// Index into the palette resolved at paint time — the piece is generated once
  /// in `initState`, but its colour must follow the live theme.
  final int colorIndex;
  final bool circle;
  final double opacity;
  final double rotation; // total rotation over the fall
  final int duration; // ms
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  static const _paletteSize = 5;

  /// Celebration palette from semantic roles, so it re-tints with the theme.
  List<Color> _palette(BuildContext context) {
    final override = widget.colors;
    if (override != null && override.isNotEmpty) {
      return override;
    }
    final c = context.colors;
    return [c.primary, c.success, c.info, c.error, c.textPrimary];
  }

  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _pieces = List.generate(
      widget.pieceCount,
      (_) => _ConfettiPiece(rng, _paletteSize),
    );
    _controller = AnimationController(
      vsync: this,
      duration: SiyaqMotion.confettiMax,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Reduced motion: a particle system at duration zero is meaningless, so the
    // celebration is skipped outright. The victory *sound* is independent.
    if (!context.motion.celebrationsEnabled) return const SizedBox.shrink();
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isCompleted) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              pieces: _pieces,
              palette: _palette(context),
              elapsedMs:
                  _controller.value * SiyaqMotion.confettiMax.inMilliseconds,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({
    required this.pieces,
    required this.palette,
    required this.elapsedMs,
  });

  final List<_ConfettiPiece> pieces;
  final List<Color> palette;
  final double elapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final t = (elapsedMs / p.duration).clamp(0.0, 1.0);
      if (t >= 1) continue;
      final eased = SiyaqMotion.confettiCurve.transform(t);
      final y = -20 + eased * (size.height * 1.05 + 20);
      final x = p.x * size.width;
      paint.color = palette[p.colorIndex % palette.length].withValues(
        alpha: p.opacity,
      );
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation * eased);
      final rect = Rect.fromCenter(
        center: Offset.zero,
        width: p.size,
        height: p.size,
      );
      if (p.circle) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRRect(
          RRect.fromRectAndRadius(rect, const Radius.circular(2)),
          paint,
        );
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs;
}
