import 'package:context_game/core/design/siyaq_design.dart';
import 'package:context_game/features/game/presentation/widgets/confetti_overlay.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Guards the reduced-motion policy.
///
/// Every animated call site reads `context.motion.<role>` instead of the raw
/// token, so honouring the OS "remove animations" setting is one policy in one
/// place — these tests pin that policy.
void main() {
  group('SiyaqMotionResolved', () {
    test('roles pass through at full duration normally', () {
      const m = SiyaqMotionResolved(reduced: false);
      expect(m.instant, SiyaqMotion.instant);
      expect(m.short, SiyaqMotion.short);
      expect(m.standard, SiyaqMotion.standard);
      expect(m.emphasized, SiyaqMotion.emphasized);
      expect(m.quick, SiyaqMotion.quick);
      expect(m.rowIn, SiyaqMotion.rowIn);
      expect(m.celebrationsEnabled, isTrue);
    });

    test('every role collapses to zero under reduced motion', () {
      const m = SiyaqMotionResolved(reduced: true);
      for (final d in [
        m.instant,
        m.short,
        m.standard,
        m.emphasized,
        m.tap,
        m.quick,
        m.route,
        m.rowIn,
        m.summaryIn,
        m.barFill,
      ]) {
        expect(d, Duration.zero);
      }
      expect(m.celebrationsEnabled, isFalse);
    });

    test('role aliases sit on the existing scale — one set of numbers', () {
      expect(SiyaqMotion.instant, SiyaqMotion.tap);
      expect(SiyaqMotion.short, SiyaqMotion.quick);
      expect(SiyaqMotion.standard, SiyaqMotion.route);
      expect(SiyaqMotion.emphasized, SiyaqMotion.rowIn);
    });
  });

  group('context.motion', () {
    testWidgets('reflects MediaQuery.disableAnimations', (t) async {
      late SiyaqMotionResolved seen;
      Widget host(bool disable) => MediaQuery(
        data: MediaQueryData(disableAnimations: disable),
        child: Builder(
          builder: (context) {
            seen = context.motion;
            return const SizedBox();
          },
        ),
      );

      await t.pumpWidget(host(false));
      expect(seen.reduced, isFalse);

      await t.pumpWidget(host(true));
      expect(seen.reduced, isTrue);
      expect(seen.quick, Duration.zero);
    });
  });

  group('celebrations', () {
    testWidgets('confetti renders normally', (t) async {
      await t.pumpWidget(
        const MaterialApp(home: ConfettiOverlay(pieceCount: 5)),
      );
      await t.pump();
      expect(find.byType(CustomPaint), findsWidgets);
      // Let the controller finish so the test ends with no live ticker.
      await t.pumpAndSettle(const Duration(seconds: 1));
    });

    testWidgets('confetti is skipped entirely under reduced motion', (
      t,
    ) async {
      await t.pumpWidget(
        const MediaQuery(
          data: MediaQueryData(disableAnimations: true),
          child: MaterialApp(home: ConfettiOverlay(pieceCount: 5)),
        ),
      );
      await t.pump();
      expect(
        find.descendant(
          of: find.byType(ConfettiOverlay),
          matching: find.byType(CustomPaint),
        ),
        findsNothing,
      );
    });
  });
}
