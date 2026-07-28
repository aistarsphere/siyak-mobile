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

  /// Solved-screen confetti: each piece falls for a random duration in this
  /// range, on [confettiCurve].
  static const confettiMin = Duration(seconds: 2);
  static const confettiMax = Duration(seconds: 5);
  static const confettiCurve = Cubic(0.37, 0, 0.63, 1);

  // ── Roles ─────────────────────────────────────────────────────────────────
  // Named for *why* a duration is used, aliased onto the raw scale above so
  // there is one set of numbers, not two. Prefer `context.motion.<role>` at
  // call sites — that is the reduced-motion-aware accessor; these raw tokens
  // are for places with no BuildContext.

  /// Instant feedback — press states, selection ticks.
  static const instant = tap;

  /// Short interaction — small cross-fades, chip/panel state changes.
  static const short = quick;

  /// Standard transition — route changes, screen-level swaps.
  static const standard = route;

  /// Emphasized transition — content entrances the eye should follow
  /// (new rows, summaries sliding in).
  static const emphasized = rowIn;

  /// Celebration — victory moments. Anything longer than this is a cutscene.
  static const celebration = confettiMax;

  // ── Gameplay feel (beta pass) ─────────────────────────────────────────────
  // These three were literal `Duration(milliseconds: …)` inside gameplay
  // components; promoting them here is what makes the budget complete — every
  // animation in the app now resolves from this file.

  /// Attention pulse on an existing element — the already-played row when a
  /// duplicate is rejected. Matches [barFill] so a pulsing row and a filling
  /// bar settle together.
  static const pulse = barFill;

  /// Rejection nudge — the composer shake. Deliberately the shortest
  /// non-instant value: a rejection should register, not perform.
  static const nudge = Duration(milliseconds: 250);

  /// Reward flash — the glow when Best improves, and the result-screen pop.
  /// The one place gameplay is allowed to linger.
  static const reward = Duration(milliseconds: 600);

  /// How long a transient status message stays legible before it fades. Not an
  /// animation but a *timing* the player feels, so it belongs to the budget.
  static const messageDwell = Duration(milliseconds: 2200);

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
    ('confettiMin', confettiMin),
    ('confettiMax', confettiMax),
  ];

  /// Role → duration, for gallery/documentation. At call sites use
  /// `context.motion.<role>` so reduced motion is honoured.
  static const roles = <(String, Duration)>[
    ('instant', instant),
    ('short', short),
    ('standard', standard),
    ('emphasized', emphasized),
    ('pulse', pulse),
    ('nudge', nudge),
    ('reward', reward),
    ('celebration', celebration),
    ('messageDwell', messageDwell),
  ];
}
