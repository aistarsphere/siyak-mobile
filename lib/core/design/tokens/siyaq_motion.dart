import 'package:flutter/material.dart';

/// Motion tokens.
///
/// **Figma specifies no motion at all** — no durations, no easings, no
/// transitions anywhere in the file (audit §3, §11-20). These values are
/// therefore carried over verbatim from the app's existing `SM` class, which is
/// the only motion specification the product has. Nothing is removed.
class SiyaqMotion {
  SiyaqMotion._();

  // ── Durations ─────────────────────────────────────────────────────────────

  /// Press feedback.
  static const tap = Duration(milliseconds: 120);

  /// Small state cross-fades.
  static const quick = Duration(milliseconds: 200);

  /// Route transition (fade + slide y 12→0).
  static const route = Duration(milliseconds: 240);

  /// Row entrance.
  static const rowIn = Duration(milliseconds: 320);

  /// Summary/panel entrance.
  static const summaryIn = Duration(milliseconds: 300);

  /// Heat-bar fill.
  static const barFill = Duration(milliseconds: 550);

  // ── Easings ───────────────────────────────────────────────────────────────

  /// Primary easing — `cubic-bezier(0.22, 1, 0.36, 1)`.
  static const easeOutQuint = Cubic(0.22, 1, 0.36, 1);

  /// Standard entrance.
  static const easeOut = Curves.easeOutCubic;

  /// Symmetric transition.
  static const easeInOut = Curves.easeInOutCubic;

  static const durations = <(String, Duration)>[
    ('tap', tap),
    ('quick', quick),
    ('route', route),
    ('rowIn', rowIn),
    ('summaryIn', summaryIn),
    ('barFill', barFill),
  ];
}
