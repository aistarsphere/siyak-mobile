import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_motion.dart';

/// Faithful port of the Stitch solved-screen confetti JS:
/// 150 pieces, palette [#FFBF00, #F59E0B, #10B981, #FDFCF0, #EF4444],
/// 4–12 px squares/circles, random opacity, fall past the bottom while
/// rotating up to ±360°, 2–5 s each, cubic-bezier(.37,0,.63,1), then gone.
class ConfettiOverlay extends StatefulWidget {
  const ConfettiOverlay({super.key, this.pieceCount = 150});

  final int pieceCount;

  @override
  State<ConfettiOverlay> createState() => _ConfettiOverlayState();
}

class _ConfettiPiece {
  _ConfettiPiece(math.Random rng)
      : x = rng.nextDouble(),
        size = rng.nextDouble() * 8 + 4,
        color = AppColors.confetti[rng.nextInt(AppColors.confetti.length)],
        circle = rng.nextBool(),
        opacity = rng.nextDouble(),
        rotation = (rng.nextDouble() * 720 - 360) * math.pi / 180,
        duration = AppMotion.confettiMin.inMilliseconds +
            rng.nextInt(AppMotion.confettiMax.inMilliseconds -
                AppMotion.confettiMin.inMilliseconds);

  final double x; // horizontal position, fraction of width
  final double size;
  final Color color;
  final bool circle;
  final double opacity;
  final double rotation; // total rotation over the fall
  final int duration; // ms
}

class _ConfettiOverlayState extends State<ConfettiOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final List<_ConfettiPiece> _pieces;

  @override
  void initState() {
    super.initState();
    final rng = math.Random();
    _pieces = List.generate(widget.pieceCount, (_) => _ConfettiPiece(rng));
    _controller = AnimationController(
      vsync: this,
      duration: AppMotion.confettiMax,
    )..forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: AnimatedBuilder(
        animation: _controller,
        builder: (context, _) {
          if (_controller.isCompleted) return const SizedBox.shrink();
          return CustomPaint(
            size: Size.infinite,
            painter: _ConfettiPainter(
              pieces: _pieces,
              elapsedMs:
                  _controller.value * AppMotion.confettiMax.inMilliseconds,
            ),
          );
        },
      ),
    );
  }
}

class _ConfettiPainter extends CustomPainter {
  _ConfettiPainter({required this.pieces, required this.elapsedMs});

  final List<_ConfettiPiece> pieces;
  final double elapsedMs;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    for (final p in pieces) {
      final t = (elapsedMs / p.duration).clamp(0.0, 1.0);
      if (t >= 1) continue;
      final eased = AppMotion.confettiCurve.transform(t);
      final y = -20 + eased * (size.height * 1.05 + 20);
      final x = p.x * size.width;
      paint.color = p.color.withValues(alpha: p.opacity);
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(p.rotation * eased);
      final rect = Rect.fromCenter(
          center: Offset.zero, width: p.size, height: p.size);
      if (p.circle) {
        canvas.drawOval(rect, paint);
      } else {
        canvas.drawRRect(
            RRect.fromRectAndRadius(rect, const Radius.circular(2)), paint);
      }
      canvas.restore();
    }
  }

  @override
  bool shouldRepaint(_ConfettiPainter oldDelegate) =>
      oldDelegate.elapsedMs != elapsedMs;
}
