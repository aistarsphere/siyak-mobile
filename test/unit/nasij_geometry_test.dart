import 'dart:math' as math;
import 'dart:ui' show TextDirection;

import 'package:context_game/features/game/domain/orbit/nasij_geometry.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the Nasīj layout to the algorithm in `Siyaq Game Variants.dc.html`.
///
/// The design file ships its own layout logic, so these are transcription
/// guards: the expected numbers below were computed from the source formulas, and
/// a failure means either the design changed or the port drifted.
void main() {
  const ltr = TextDirection.ltr;
  const rtl = TextDirection.rtl;

  group('bands', () {
    test('thresholds match the design exactly', () {
      expect(NasijBand.forScore(0), NasijBand.distant);
      expect(NasijBand.forScore(19.9), NasijBand.distant);
      expect(NasijBand.forScore(20), NasijBand.adjacent);
      expect(NasijBand.forScore(44.9), NasijBand.adjacent);
      expect(NasijBand.forScore(45), NasijBand.related);
      expect(NasijBand.forScore(69.9), NasijBand.related);
      expect(NasijBand.forScore(70), NasijBand.near);
      expect(NasijBand.forScore(89.9), NasijBand.near);
      expect(NasijBand.forScore(90), NasijBand.touching);
      expect(NasijBand.forScore(100), NasijBand.touching);
    });

    test('stroke width grows with the band, so colour is not load-bearing', () {
      final ordered = [
        NasijBand.distant,
        NasijBand.adjacent,
        NasijBand.related,
        NasijBand.near,
        NasijBand.touching,
      ];
      for (var i = 1; i < ordered.length; i++) {
        expect(
          ordered[i].strokeCompact,
          greaterThan(ordered[i - 1].strokeCompact),
        );
        expect(
          ordered[i].strokeExpanded,
          greaterThan(ordered[i - 1].strokeExpanded),
        );
        // The larger board always draws heavier than the compact one.
        expect(
          ordered[i].strokeExpanded,
          greaterThan(ordered[i].strokeCompact),
        );
      }
    });

    test('exact widths from the source band() table', () {
      expect(NasijBand.touching.strokeCompact, 5.5);
      expect(NasijBand.touching.strokeExpanded, 6.5);
      expect(NasijBand.distant.strokeCompact, 1.5);
      expect(NasijBand.distant.strokeExpanded, 2.4);
    });

    test('bead radius is 2.4 + tier * 0.5', () {
      expect(NasijBand.distant.beadRadius, closeTo(2.9, 1e-9));
      expect(NasijBand.touching.beadRadius, closeTo(4.9, 1e-9));
    });

    test('tier is 1-based and distinct from Enum.index', () {
      expect(NasijBand.distant.tier, 1);
      expect(NasijBand.distant.index, 0);
      expect(NasijBand.touching.tier, 5);
      expect(NasijBand.touching.index, 4);
    });

    test('every band names a localization key, never a literal', () {
      for (final b in NasijBand.values) {
        expect(b.labelKey, startsWith('nasijBand'));
      }
      expect(
        NasijBand.values.map((b) => b.labelKey).toSet(),
        hasLength(NasijBand.values.length),
      );
    });
  });

  group('tip radius', () {
    test('a far guess sits at the rim, a close one deep inside', () {
      // score 0 -> 14 + 104 * 1 = 118, clamped to R-22 = 96.
      expect(NasijLayout.tipRadius(0), closeTo(96, 1e-9));
      // score 100 -> 14, under the clamp.
      expect(NasijLayout.tipRadius(100), closeTo(14, 1e-9));
      // score 50 -> 14 + 104 * 0.5 = 66.
      expect(NasijLayout.tipRadius(50), closeTo(66, 1e-9));
    });

    test('is monotonic — closer always means nearer the knot', () {
      double? previous;
      for (var s = 0; s <= 100; s += 5) {
        final r = NasijLayout.tipRadius(s.toDouble());
        if (previous != null) expect(r, lessThanOrEqualTo(previous));
        previous = r;
      }
    });

    test('never reaches the knot, so the centre stays the secret alone', () {
      for (var s = 0; s <= 100; s++) {
        expect(NasijLayout.tipRadius(s.toDouble()), greaterThan(0));
        expect(
          NasijLayout.tipRadius(s.toDouble()),
          lessThanOrEqualTo(NasijSpace.minTipRadius),
        );
      }
    });

    test('out-of-range and NaN scores clamp instead of exploding', () {
      expect(NasijLayout.tipRadius(-50), NasijLayout.tipRadius(0));
      expect(NasijLayout.tipRadius(500), NasijLayout.tipRadius(100));
      expect(NasijLayout.tipRadius(double.nan), NasijLayout.tipRadius(0));
    });
  });

  group('angular placement', () {
    test('LTR starts at 12 degrees and steps by the golden angle', () {
      expect(
        NasijLayout.angleAt(0, direction: ltr) * 180 / math.pi,
        closeTo(12, 1e-9),
      );
      expect(
        NasijLayout.angleAt(1, direction: ltr) * 180 / math.pi,
        closeTo((12 + 137.508) % 360, 1e-9),
      );
    });

    test('RTL starts at 168 degrees and steps counter-clockwise', () {
      expect(
        NasijLayout.angleAt(0, direction: rtl) * 180 / math.pi,
        closeTo(168, 1e-9),
      );
      // Not a mirror of LTR: a genuinely different composition.
      expect(
        NasijLayout.angleAt(1, direction: rtl),
        isNot(closeTo(NasijLayout.angleAt(1, direction: ltr), 1e-6)),
      );
    });

    test('golden-angle spacing keeps 40 threads well separated', () {
      // This is why no collision-resolution pass is needed.
      final angles = [
        for (var i = 0; i < 40; i++)
          NasijLayout.angleAt(i, direction: ltr) * 180 / math.pi,
      ]..sort();
      var minGap = 360.0;
      for (var i = 1; i < angles.length; i++) {
        minGap = math.min(minGap, angles[i] - angles[i - 1]);
      }
      expect(
        minGap,
        greaterThan(1.0),
        reason: 'no two of 40 threads may share a direction',
      );
    });

    test('placement is deterministic across calls', () {
      for (var i = 0; i < 10; i++) {
        expect(
          NasijLayout.angleAt(i, direction: ltr),
          NasijLayout.angleAt(i, direction: ltr),
        );
      }
    });
  });

  group('threads', () {
    NasijThread build(double score, {int index = 0, TextDirection d = ltr}) =>
        NasijLayout.thread(word: 'w', score: score, index: index, direction: d);

    test('runs from the rim inward, never outward', () {
      final t = build(60);
      double dist(NasijPoint p) => math.sqrt(
        math.pow(p.x - NasijSpace.centre, 2) +
            math.pow(p.y - NasijSpace.centre, 2),
      );
      expect(dist(t.rimPoint), closeTo(NasijSpace.rim, 0.2));
      expect(dist(t.tipPoint), lessThan(dist(t.rimPoint)));
    });

    test('a closer guess ends nearer the centre', () {
      double dist(NasijThread t) => math.sqrt(
        math.pow(t.tipPoint.x - NasijSpace.centre, 2) +
            math.pow(t.tipPoint.y - NasijSpace.centre, 2),
      );
      expect(dist(build(95)), lessThan(dist(build(50))));
      expect(dist(build(50)), lessThan(dist(build(5))));
    });

    test('the control point bows the thread off its own spoke', () {
      final t = build(60);
      // A straight spoke would put the control point on the same angle; the 9°
      // swing is what makes the weave organic rather than a starburst.
      final controlAngle = math.atan2(
        t.controlPoint.y - NasijSpace.centre,
        t.controlPoint.x - NasijSpace.centre,
      );
      expect((controlAngle - t.angle).abs(), greaterThan(0.05));
    });

    test('RTL bows the other way', () {
      double bow(TextDirection d) {
        final t = build(60, d: d);
        final ca = math.atan2(
          t.controlPoint.y - NasijSpace.centre,
          t.controlPoint.x - NasijSpace.centre,
        );
        return ca - t.angle;
      }

      expect(bow(ltr).sign, isNot(bow(rtl).sign));
    });

    test('label anchor follows which side of the board the tip is on', () {
      // Right of centre reads outward from the start edge; left, from the end.
      final right = build(30, index: 0); // 12deg -> cos > 0
      expect(right.labelAnchor, NasijLabelAnchor.start);
      final left = NasijLayout.thread(
        word: 'w',
        score: 30,
        index: 0,
        direction: rtl,
      ); // 168deg -> cos < 0
      expect(left.labelAnchor, NasijLabelAnchor.end);
    });

    test('stroke width follows the board presentation', () {
      final t = build(95);
      expect(t.strokeFor(expanded: false), NasijBand.touching.strokeCompact);
      expect(t.strokeFor(expanded: true), NasijBand.touching.strokeExpanded);
    });
  });

  group('session layout', () {
    final session = <({String word, double score})>[
      (word: 'school', score: 88),
      (word: 'river', score: 6),
      (word: 'book', score: 61),
      (word: 'doctor', score: 41),
      (word: 'tutor', score: 95),
      (word: 'music', score: 12),
      (word: 'lesson', score: 76),
    ];

    test('lays out the design fixture without collision', () {
      final threads = NasijLayout.layout(session, direction: ltr);
      expect(threads, hasLength(7));
      expect(threads.map((t) => t.angle).toSet(), hasLength(7));
    });

    test('identical input gives an identical weave every time', () {
      final a = NasijLayout.layout(session, direction: ltr);
      final b = NasijLayout.layout(session, direction: ltr);
      for (var i = 0; i < a.length; i++) {
        expect(a[i].angle, b[i].angle);
        expect(a[i].tipPoint, b[i].tipPoint);
        expect(a[i].labelPoint, b[i].labelPoint);
      }
    });

    test('order is submission order — reordering moves the weave', () {
      final forward = NasijLayout.layout(session, direction: ltr);
      final reversed = NasijLayout.layout(
        session.reversed.toList(),
        direction: ltr,
      );
      // Documents the contract: callers holding the API's rank-ordered list must
      // restore submission order first, or the board rearranges itself.
      expect(forward.first.word, isNot(reversed.first.word));
      expect(forward.first.angle, reversed.first.angle);
    });

    test('scales into a rendered board', () {
      final t = NasijLayout.layout(session, direction: ltr).first;
      final scaled = t.tipPoint.scaled(NasijSpace.boardCompact);
      final k = NasijSpace.boardCompact / 280.0;
      expect(scaled.x, closeTo(t.tipPoint.x * k, 1e-9));
    });
  });

  group('label visibility', () {
    test('a quiet board shows Related and better', () {
      bool shows(double score) => NasijLayout.showsLabel(
        NasijLayout.thread(word: 'w', score: score, index: 0, direction: ltr),
        threadCount: 7,
      );
      expect(shows(95), isTrue);
      expect(shows(76), isTrue);
      expect(shows(61), isTrue);
      expect(shows(41), isFalse);
      expect(shows(6), isFalse);
    });

    test('the expanded board affords one band more', () {
      bool shows(double score, {required bool expanded}) =>
          NasijLayout.showsLabel(
            NasijLayout.thread(
              word: 'w',
              score: score,
              index: 0,
              direction: ltr,
            ),
            threadCount: 7,
            expanded: expanded,
          );
      expect(shows(41, expanded: false), isFalse);
      expect(shows(41, expanded: true), isTrue);
    });

    test('past 24 threads only Near and better keep labels', () {
      bool shows(double score) => NasijLayout.showsLabel(
        NasijLayout.thread(word: 'w', score: score, index: 0, direction: ltr),
        threadCount: 26,
      );
      expect(shows(95), isTrue);
      expect(shows(76), isTrue);
      expect(
        shows(61),
        isFalse,
        reason: 'Related collapses to a bead on a crowded board',
      );
    });

    test('26 threads still all place — none are dropped', () {
      final many = <({String word, double score})>[
        for (var i = 0; i < 26; i++)
          (word: 'w$i', score: (6 + ((i * 37) % 88)).toDouble()),
      ];
      final threads = NasijLayout.layout(many, direction: ltr);
      expect(threads, hasLength(26));
      // Collapsing hides a *label*, never a thread — the list sheet keeps them
      // all reachable.
      expect(
        threads.where((t) => NasijLayout.showsLabel(t, threadCount: 26)).length,
        lessThan(26),
      );
    });
  });

  group('rosette', () {
    NasijThread t(double score, int i) =>
        NasijLayout.thread(word: 'w', score: score, index: i, direction: ltr);

    test('needs three qualifying threads before it draws', () {
      expect(NasijLayout.rosette([]), isEmpty);
      expect(NasijLayout.rosette([t(60, 0), t(60, 1)]), isEmpty);
      expect(NasijLayout.rosette([t(60, 0), t(60, 1), t(60, 2)]), hasLength(3));
    });

    test('ignores Distant threads', () {
      // Three threads, but all below the Adjacent floor.
      expect(
        NasijLayout.rosette([t(5, 0), t(8, 1), t(11, 2)]),
        isEmpty,
        reason: 'the hull is drawn through meaningful guesses only',
      );
    });

    test('closes the hull — last segment returns to the first tip', () {
      final threads = [t(60, 0), t(70, 1), t(88, 2), t(45, 3)];
      final segments = NasijLayout.rosette(threads);
      expect(segments, hasLength(4));
      expect(segments.last.to, segments.first.from);
    });

    test('control points pull toward the centre, tightening the shape', () {
      final segments = NasijLayout.rosette([t(60, 0), t(70, 1), t(88, 2)]);
      for (final s in segments) {
        final mx = (s.from.x + s.to.x) / 2;
        final my = (s.from.y + s.to.y) / 2;
        final midDist = math.sqrt(
          math.pow(mx - NasijSpace.centre, 2) +
              math.pow(my - NasijSpace.centre, 2),
        );
        final ctrlDist = math.sqrt(
          math.pow(s.control.x - NasijSpace.centre, 2) +
              math.pow(s.control.y - NasijSpace.centre, 2),
        );
        expect(ctrlDist, lessThan(midDist + 0.2));
      }
    });
  });

  group('hint wedge', () {
    NasijThread t(double score, int i) =>
        NasijLayout.thread(word: 'w', score: score, index: i, direction: ltr);

    test('needs two threads', () {
      expect(NasijLayout.hintWedge([]), isNull);
      expect(NasijLayout.hintWedge([t(90, 0)]), isNull);
    });

    test('spans between the two strongest threads', () {
      final strongest = t(95, 4);
      final second = t(88, 0);
      final wedge = NasijLayout.hintWedge([
        t(12, 1),
        second,
        strongest,
        t(6, 2),
      ]);
      expect(wedge, isNotNull);
      expect(wedge!.startAngle, strongest.angle);
      expect(wedge.radius, NasijSpace.rim);
    });

    test('sweep is always positive and under a full turn', () {
      final wedge = NasijLayout.hintWedge([t(95, 0), t(88, 7)])!;
      expect(wedge.sweep, greaterThan(0));
      expect(wedge.sweep, lessThan(2 * math.pi));
    });

    test('flags the large-arc case', () {
      final small = NasijLayout.hintWedge([t(95, 0), t(90, 1)])!;
      expect(small.isLargeArc, small.sweep > math.pi);
    });
  });

  group('design-space constants', () {
    test('match the source header', () {
      expect(NasijSpace.centre, 140.0);
      expect(NasijSpace.rim, 118.0);
      expect(NasijSpace.goldenAngle, 137.508);
      expect(NasijSpace.minTipRadius, 96.0);
      expect(NasijSpace.bowDegrees, 9.0);
    });

    test('board sizes exclude the rejected 196px medallion', () {
      expect(NasijSpace.boardCompact, 286.0);
      expect(NasijSpace.boardExpanded, 356.0);
      expect(NasijSpace.boardCompact, greaterThan(196));
    });

    test('collapse and chip thresholds are the documented ones', () {
      expect(NasijSpace.labelCollapseThreshold, 24);
      expect(NasijSpace.chipsAppearAfter, 12);
    });
  });
}
