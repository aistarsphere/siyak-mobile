import 'package:flutter/animation.dart';

/// Motion constants mirroring the Stitch design's transitions/keyframes.
class AppMotion {
  AppMotion._();

  /// `active:scale-95 duration-100` on icon buttons / chips.
  static const pressDuration = Duration(milliseconds: 100);
  static const pressScale = 0.95;

  /// `active:scale-[0.98] duration-150` on large CTAs.
  static const ctaPressDuration = Duration(milliseconds: 150);
  static const ctaPressScale = 0.98;

  /// `transition-colors 0.2s` (input focus underline).
  static const focus = Duration(milliseconds: 200);

  /// Guess row insertion / chip fade-slide.
  static const rowIn = Duration(milliseconds: 350);

  /// Heat/progress bar fill.
  static const barFill = Duration(milliseconds: 600);

  /// `shimmer 2s infinite` on the best-guess progress bar.
  static const shimmer = Duration(seconds: 2);

  /// `pulse-glow` 2s ease-in-out infinite on the solved card.
  static const pulseGlow = Duration(seconds: 2);

  /// `shine 3s infinite` sweep across the solved card.
  static const shine = Duration(seconds: 3);

  /// Confetti pieces fall 2–5s, cubic-bezier(.37,0,.63,1).
  static const confettiMin = Duration(seconds: 2);
  static const confettiMax = Duration(seconds: 5);
  static const confettiCurve = Cubic(0.37, 0, 0.63, 1);

  /// Trophy bounce 2s infinite on the solved header.
  static const bounce = Duration(seconds: 2);

  /// Hint pill pop-in.
  static const hintPop = Duration(milliseconds: 320);

  /// Screen transitions.
  static const screen = Duration(milliseconds: 380);

  static const easeOut = Curves.easeOutCubic;
  static const easeInOut = Curves.easeInOut;
  static const pop = Curves.easeOutBack;
}
