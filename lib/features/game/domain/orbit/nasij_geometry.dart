/// ─── Nasīj — the geometry model for the Orbit gameplay board ─────────────────
///
/// Transcribed from `Siyaq Game Variants.dc.html` in the Claude Design project
/// (read 2026-07-30). That file carries the prototype's own layout logic, so the
/// constants and formulas here are the design's, not an interpretation of a
/// picture. See `docs/ORBIT_NASIJ_SPEC.md`.
///
/// **Pure model, no Flutter widgets and no painting.** The board renders later on
/// top of this; keeping the maths separate is what makes it testable and what
/// keeps a session's layout identical across rebuilds and restores.
///
/// The design's vocabulary is deliberate and worth keeping: the board is a
/// *weave* (نسيج), each guess is a *thread* (خيط) drawn from the rim inward, and
/// the secret at the centre is the *knot*.
library;

import 'dart:math' as math;
import 'dart:ui' show TextDirection;

/// Design-space constants. The board is authored in a 280×280 viewBox and scaled
/// to its rendered size, so every value below is in that space.
abstract final class NasijSpace {
  /// Centre of the board (`C`).
  static const centre = 140.0;

  /// Radius of the rim where threads begin (`R`).
  static const rim = 118.0;

  /// Golden angle in degrees (`GA`). Successive threads step by this, which is
  /// what keeps them from colliding without any resolution pass — an irrational
  /// turn never repeats a direction.
  static const goldenAngle = 137.508;

  /// A thread tip can never reach the knot: `R - 22`.
  static const minTipRadius = rim - 22;

  /// Closest a tip may sit to the centre in the score formula.
  static const tipFloor = 14.0;

  /// How far the quadratic control point is swung off the thread's own angle,
  /// giving every thread the same handed bow instead of a straight spoke.
  static const bowDegrees = 9.0;

  /// Guide rings (`stroke-dasharray` in the source; drawn dashed except the rim).
  static const guideRings = <double>[96, 70, 44];

  /// Filled backdrop disc.
  static const backdropRadius = 122.0;

  /// Rendered board sizes, in logical pixels.
  ///
  /// The design tested three and recommends [boardCompact] as the default with
  /// [boardExpanded] when the keyboard is dismissed. 196px was explicitly
  /// rejected: at that size "the weave stops being beautiful and becomes a
  /// badge", which is the failure the brief rules out.
  static const boardCompact = 286.0;
  static const boardExpanded = 356.0;

  /// Past this many threads the design collapses labels below [NasijBand.near]
  /// to bare beads and moves them into the list sheet.
  static const labelCollapseThreshold = 24;

  /// Top-3 chips appear only once the single last-result row stops being enough
  /// orientation.
  static const chipsAppearAfter = 12;
}

/// The five proximity bands. Thresholds and stroke weights are the design's.
///
/// Bands are ordinal: [distant] is band 1, [touching] is band 5. Stroke width
/// grows with the band so proximity reads without colour, which the brief
/// requires and which matters for anyone who cannot separate the hues.
enum NasijBand {
  distant(tier: 1, minScore: 0, strokeCompact: 1.5, strokeExpanded: 2.4),
  adjacent(tier: 2, minScore: 20, strokeCompact: 2.2, strokeExpanded: 3.2),
  related(tier: 3, minScore: 45, strokeCompact: 3.0, strokeExpanded: 4.0),
  near(tier: 4, minScore: 70, strokeCompact: 4.0, strokeExpanded: 5.0),
  touching(tier: 5, minScore: 90, strokeCompact: 5.5, strokeExpanded: 6.5),

  /// The secret itself. The prototype gives it the same colour tier as
  /// [touching] but the heaviest stroke, so the winning thread reads as the
  /// thickest line on the board.
  solved(tier: 5, minScore: 100, strokeCompact: 6.0, strokeExpanded: 6.0);

  const NasijBand({
    required this.tier,
    required this.minScore,
    required this.strokeCompact,
    required this.strokeExpanded,
  });

  /// 1–5. Also drives bead size and indexes the `--sy-p1…p5` colour ramp.
  /// Named `tier` rather than `index` because `Enum.index` already exists and is
  /// 0-based — conflating the two would be a quiet off-by-one.
  final int tier;

  /// Inclusive lower bound on the 0–100 score.
  final int minScore;

  /// `w` — stroke width on the compact board.
  final double strokeCompact;

  /// `w2` — stroke width on the larger boards.
  final double strokeExpanded;

  /// Localization key for the band's user-facing name. The design's English
  /// wording is Distant / Adjacent / Related / Near / Touching; the strings
  /// themselves live in the localization tables, never here.
  String get labelKey => switch (this) {
    distant => 'nasijBandDistant',
    adjacent => 'nasijBandAdjacent',
    related => 'nasijBandRelated',
    near => 'nasijBandNear',
    touching => 'nasijBandTouching',
    solved => 'nasijBandSolved',
  };

  /// Bead radius: `2.4 + index * 0.5`.
  double get beadRadius => 2.4 + tier * 0.5;

  /// Band for a 0–100 proximity score, highest threshold first.
  static NasijBand forScore(num score) {
    if (score >= solved.minScore) return solved;
    if (score >= touching.minScore) return touching;
    if (score >= near.minScore) return near;
    if (score >= related.minScore) return related;
    if (score >= adjacent.minScore) return adjacent;
    return distant;
  }

  /// Whether a thread in this band keeps a visible label once the board is
  /// crowded past [NasijSpace.labelCollapseThreshold].
  bool get survivesCollapse => tier >= near.tier;

  /// Zero-based index into the five-colour `--sy-p1…p5` ramp.
  ///
  /// [solved] deliberately shares [touching]'s colour, so this is `tier - 1`
  /// rather than the enum's own ordinal — six bands map onto five colours.
  int get rampIndex => tier - 1;
}

/// One placed thread: everything the painter and the semantic list both need.
///
/// Angles are radians in the design's coordinate space, where +x is right and +y
/// is **down** (screen space, as in SVG) — so `sin` is not negated anywhere.
class NasijThread {
  const NasijThread({
    required this.word,
    required this.score,
    required this.band,
    required this.angle,
    required this.rimPoint,
    required this.tipPoint,
    required this.controlPoint,
    required this.beadRadius,
    required this.labelAnchor,
    required this.labelPoint,
  });

  final String word;

  /// 0–100 proximity. Higher is closer to the secret.
  final double score;

  final NasijBand band;

  /// Placement angle in radians.
  final double angle;

  /// Where the thread meets the rim — its start.
  final NasijPoint rimPoint;

  /// Where the thread ends, nearest the knot. The bead sits here.
  final NasijPoint tipPoint;

  /// Quadratic control point, producing the bow.
  final NasijPoint controlPoint;

  final double beadRadius;

  /// Which side of [labelPoint] the text hangs from.
  final NasijLabelAnchor labelAnchor;

  /// Where the word is placed, offset off the tip so it clears the thread.
  final NasijPoint labelPoint;

  /// Stroke width for a given board presentation.
  double strokeFor({required bool expanded}) =>
      expanded ? band.strokeExpanded : band.strokeCompact;
}

/// A point in the 280×280 design space.
class NasijPoint {
  const NasijPoint(this.x, this.y);
  final double x;
  final double y;

  /// Scales into a rendered board of [size] logical pixels.
  NasijPoint scaled(double size) {
    final k = size / 280.0;
    return NasijPoint(x * k, y * k);
  }

  @override
  bool operator ==(Object other) =>
      other is NasijPoint && other.x == x && other.y == y;

  @override
  int get hashCode => Object.hash(x, y);

  @override
  String toString() =>
      'NasijPoint(${x.toStringAsFixed(1)}, '
      '${y.toStringAsFixed(1)})';
}

enum NasijLabelAnchor { start, middle, end }

/// Lays guesses out on the board.
///
/// Deterministic by construction: placement depends only on a thread's **index**
/// in submission order and its score, so the same session always draws the same
/// weave — on rebuild, on restore, and on a different device. Nothing here is
/// random, and there is no collision-resolution pass because the golden angle
/// makes collisions vanishingly unlikely on its own.
abstract final class NasijLayout {
  /// Rounds to one decimal, matching the source's `f()` so transcription can be
  /// checked against the design's own output.
  static double _f(double n) => (n * 10).round() / 10;

  /// Radial distance of a thread's tip for [score].
  ///
  /// `min(R - 22, 14 + (R - 14) * (1 - score/100))` — a score of 100 would sit at
  /// 14, but the clamp keeps every tip outside the knot so the centre stays the
  /// secret's alone.
  static double tipRadius(double score) {
    final t = (score.isNaN ? 0.0 : score).clamp(0.0, 100.0);
    final raw =
        NasijSpace.tipFloor +
        (NasijSpace.rim - NasijSpace.tipFloor) * (1 - t / 100);
    return math.min(NasijSpace.minTipRadius, raw);
  }

  /// Placement angle, in radians, for the thread at [index].
  ///
  /// LTR starts at 12° and steps clockwise; RTL starts at 168° and steps
  /// counter-clockwise, so the first thread still lands where an Arabic reader
  /// enters the board. The design is explicit that this is a different
  /// composition, **not a mirrored one**.
  static double angleAt(int index, {required TextDirection direction}) {
    final rtl = direction == TextDirection.rtl;
    final sign = rtl ? -1 : 1;
    final start = rtl ? 168.0 : 12.0;
    final degrees = (start + sign * index * NasijSpace.goldenAngle) % 360;
    return degrees * math.pi / 180;
  }

  /// Places one thread.
  static NasijThread thread({
    required String word,
    required double score,
    required int index,
    required TextDirection direction,
  }) {
    final rtl = direction == TextDirection.rtl;
    final sign = rtl ? -1 : 1;
    const c = NasijSpace.centre;
    const r = NasijSpace.rim;

    final a = angleAt(index, direction: direction);
    final band = NasijBand.forScore(score);
    final tipR = tipRadius(score);

    // The control point is swung off-angle and placed midway out, which is what
    // bows every thread the same way instead of drawing plain spokes.
    final controlAngle = a + sign * NasijSpace.bowDegrees * math.pi / 180;
    final mid = (r + tipR) / 2;

    final tipX = c + tipR * math.cos(a);
    final tipY = c + tipR * math.sin(a);

    return NasijThread(
      word: word,
      score: score,
      band: band,
      angle: a,
      rimPoint: NasijPoint(_f(c + r * math.cos(a)), _f(c + r * math.sin(a))),
      tipPoint: NasijPoint(_f(tipX), _f(tipY)),
      controlPoint: NasijPoint(
        _f(c + mid * math.cos(controlAngle)),
        _f(c + mid * math.sin(controlAngle)),
      ),
      beadRadius: band.beadRadius,
      labelAnchor: _anchorFor(a),
      // Offset 8 along the angle and 12 perpendicular, so the word clears both
      // the bead and its own thread.
      labelPoint: NasijPoint(
        _f(tipX + 8 * math.cos(a) - 12 * math.sin(a)),
        _f(tipY + 8 * math.sin(a) + 12 * math.cos(a)),
      ),
    );
  }

  static NasijLabelAnchor _anchorFor(double angle) {
    final cos = math.cos(angle);
    if (cos < -0.15) return NasijLabelAnchor.end;
    if (cos > 0.15) return NasijLabelAnchor.start;
    return NasijLabelAnchor.middle;
  }

  /// Places a whole session.
  ///
  /// [guesses] must be in **submission order** — index drives the angle, so
  /// reordering the input rearranges the board. Callers holding a rank-ordered
  /// list (as the gameplay API returns) must restore submission order first.
  static List<NasijThread> layout(
    List<({String word, double score})> guesses, {
    required TextDirection direction,
  }) => [
    for (var i = 0; i < guesses.length; i++)
      thread(
        word: guesses[i].word,
        score: guesses[i].score,
        index: i,
        direction: direction,
      ),
  ];

  /// Whether a thread's word should be drawn on the board.
  ///
  /// Below [NasijBand.related] a label is noise even on a quiet board; once the
  /// board is crowded, only [NasijBand.near] and above keep theirs and the rest
  /// live in the list sheet. Nothing disappears — the list is always reachable,
  /// which the brief requires.
  static bool showsLabel(
    NasijThread thread, {
    required int threadCount,
    bool expanded = false,
  }) {
    final crowded = threadCount > NasijSpace.labelCollapseThreshold;
    if (crowded) return thread.band.survivesCollapse;
    // The full-bleed board has room for one band more.
    final floor = expanded ? NasijBand.adjacent.tier : NasijBand.related.tier;
    return thread.band.tier >= floor;
  }

  /// The rosette: a closed hull through the tips of every thread at
  /// [NasijBand.adjacent] or better, drawn as quadratic segments whose control
  /// points are pulled 28% toward the centre.
  ///
  /// Returns an empty list below three qualifying threads — the design draws no
  /// rosette until there is a shape to draw.
  static List<NasijRosetteSegment> rosette(List<NasijThread> threads) {
    final near =
        threads.where((t) => t.band.tier >= NasijBand.adjacent.tier).toList()
          ..sort((a, b) => a.angle.compareTo(b.angle));
    if (near.length < 3) return const [];

    const c = NasijSpace.centre;
    return [
      for (var i = 0; i < near.length; i++)
        () {
          final from = near[i].tipPoint;
          final to = near[(i + 1) % near.length].tipPoint;
          final mx = (from.x + to.x) / 2;
          final my = (from.y + to.y) / 2;
          return NasijRosetteSegment(
            from: from,
            control: NasijPoint(
              _f(mx + (c - mx) * 0.28),
              _f(my + (c - my) * 0.28),
            ),
            to: to,
          );
        }(),
    ];
  }

  /// The hint wedge: a pie slice between two threads' angles, which the design
  /// lights between the player's two strongest threads. No numbers are revealed.
  static NasijWedge? hintWedge(List<NasijThread> threads) {
    if (threads.length < 2) return null;
    final strongest = threads.toList()
      ..sort((a, b) => b.score.compareTo(a.score));
    var sweep = strongest[1].angle - strongest[0].angle;
    while (sweep < 0) {
      sweep += math.pi * 2;
    }
    return NasijWedge(
      startAngle: strongest[0].angle,
      sweep: sweep,
      radius: NasijSpace.rim,
    );
  }
}

/// One quadratic segment of the rosette hull.
class NasijRosetteSegment {
  const NasijRosetteSegment({
    required this.from,
    required this.control,
    required this.to,
  });
  final NasijPoint from;
  final NasijPoint control;
  final NasijPoint to;
}

/// The hint sector.
class NasijWedge {
  const NasijWedge({
    required this.startAngle,
    required this.sweep,
    required this.radius,
  });
  final double startAngle;
  final double sweep;
  final double radius;

  /// True when the slice covers more than half the board, which the source flags
  /// as the SVG large-arc case.
  bool get isLargeArc => sweep > math.pi;
}
