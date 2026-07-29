import 'package:context_game/core/design/organic/organic_colors.dart';
import 'package:context_game/core/design/organic/organic_tokens.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the Organic layer to the values read from the design MCP.
///
/// These are transcription guards, not design opinions: if a token here drifts,
/// either the design changed (re-read it and update deliberately) or someone
/// hand-edited a value. See `docs/DESIGN_MCP_EXTRACTION.md`.
void main() {
  group('foundations match _ds_manifest.json', () {
    test('role colours', () {
      expect(OrganicPalette.bg, const Color(0xFFF5EAD8));
      expect(OrganicPalette.surface, const Color(0xFFEBDDC5));
      expect(OrganicPalette.text, const Color(0xFF201E1D));
      expect(OrganicPalette.accent, const Color(0xFFC67139));
      expect(OrganicPalette.accent2, const Color(0xFF7A8A5E));
    });

    test('ramps carry all nine steps, darkening monotonically', () {
      const neutral = [
        OrganicPalette.neutral100,
        OrganicPalette.neutral200,
        OrganicPalette.neutral300,
        OrganicPalette.neutral400,
        OrganicPalette.neutral500,
        OrganicPalette.neutral600,
        OrganicPalette.neutral700,
        OrganicPalette.neutral800,
        OrganicPalette.neutral900,
      ];
      const accent = [
        OrganicPalette.accent100,
        OrganicPalette.accent200,
        OrganicPalette.accent300,
        OrganicPalette.accent400,
        OrganicPalette.accent500,
        OrganicPalette.accent600,
        OrganicPalette.accent700,
        OrganicPalette.accent800,
        OrganicPalette.accent900,
      ];
      const sage = [
        OrganicPalette.accent2100,
        OrganicPalette.accent2200,
        OrganicPalette.accent2300,
        OrganicPalette.accent2400,
        OrganicPalette.accent2500,
        OrganicPalette.accent2600,
        OrganicPalette.accent2700,
        OrganicPalette.accent2800,
        OrganicPalette.accent2900,
      ];

      for (final ramp in [neutral, accent, sage]) {
        expect(ramp, hasLength(9));
        for (var i = 1; i < ramp.length; i++) {
          expect(
            ramp[i].computeLuminance(),
            lessThan(ramp[i - 1].computeLuminance()),
            reason: 'step $i must be darker than ${i - 1}',
          );
        }
      }
    });

    test('spacing is the authored 1.10x scale, gaps included', () {
      expect(OrganicSpacing.s1, closeTo(4.4, 0.001));
      expect(OrganicSpacing.s2, closeTo(8.8, 0.001));
      expect(OrganicSpacing.s3, closeTo(13.2, 0.001));
      expect(OrganicSpacing.s4, closeTo(17.6, 0.001));
      expect(OrganicSpacing.s6, closeTo(26.4, 0.001));
      expect(OrganicSpacing.s8, closeTo(35.2, 0.001));
      // 4px base x 1.10 — the fractions are deliberate.
      expect(OrganicSpacing.s1, closeTo(4 * 1.1, 0.001));
    });

    test('radii over-round, with a pill', () {
      expect(OrganicRadius.sm, 8.0);
      expect(OrganicRadius.md, 16.0);
      expect(OrganicRadius.lg, 28.0);
      expect(OrganicRadius.pill, 999.0);
    });

    test('shadows are warm, not black', () {
      for (final shadow in [
        ...OrganicElevation.sm,
        ...OrganicElevation.md,
        ...OrganicElevation.lg,
      ]) {
        final c = shadow.color;
        expect(
          (c.r, c.g, c.b),
          (
            OrganicElevation.shadowBase.r,
            OrganicElevation.shadowBase.g,
            OrganicElevation.shadowBase.b,
          ),
          reason: 'elevation must tint from #2E2B25, never pure black',
        );
      }
    });

    test('the sheet shadow throws upward', () {
      expect(OrganicElevation.sheetLight.single.offset.dy, isNegative);
      expect(OrganicElevation.sheetDark.single.offset.dy, isNegative);
    });
  });

  group('motion', () {
    test('exactly the two authored curves', () {
      expect(OrganicMotion.standard, const Cubic(0.22, 0.9, 0.24, 1));
      expect(OrganicMotion.expressive, const Cubic(0.16, 1, 0.3, 1));
    });

    test('Orbit timings are the ones the prototype uses', () {
      expect(OrganicMotion.tie, const Duration(milliseconds: 420));
      expect(OrganicMotion.travel, const Duration(milliseconds: 820));
      expect(OrganicMotion.arrival, const Duration(milliseconds: 900));
    });

    test('ambient loops are all long and flagged for suppression', () {
      expect(OrganicMotion.ambient, contains(OrganicMotion.breathe));
      expect(OrganicMotion.ambient, contains(OrganicMotion.shimmer));
      expect(OrganicMotion.ambient, contains(OrganicMotion.spin));
      for (final d in OrganicMotion.ambient) {
        expect(
          d.inMilliseconds,
          greaterThan(OrganicMotion.arrival.inMilliseconds),
          reason: 'an ambient loop must never read as feedback',
        );
      }
    });

    test('shimmer variants are out of phase with each other', () {
      expect(OrganicMotion.shimmerVariants.toSet(), hasLength(3));
    });
  });

  group('script-aware type', () {
    test('Arabic gets faces that can actually render it', () {
      expect(OrganicFonts.display(OrganicScript.arabic), 'Baloo Bhaijaan 2');
      expect(OrganicFonts.body(OrganicScript.arabic), 'Tajawal');
      // Caprasimo and Figtree are Latin-only, so they must never be selected
      // for Arabic — that would produce tofu in the app's primary language.
      expect(
        OrganicFonts.display(OrganicScript.arabic),
        isNot(OrganicFonts.latinDisplay),
      );
      expect(
        OrganicFonts.body(OrganicScript.arabic),
        isNot(OrganicFonts.latinBody),
      );
    });

    test('Latin gets the display pair the system names', () {
      expect(OrganicFonts.display(OrganicScript.latin), 'Caprasimo');
      expect(OrganicFonts.body(OrganicScript.latin), 'Figtree');
    });
  });

  group('semantic layer', () {
    test('both themes are fully populated and distinct', () {
      expect(OrganicColors.light.isDark, isFalse);
      expect(OrganicColors.dark.isDark, isTrue);
      expect(
        OrganicColors.light.background,
        isNot(OrganicColors.dark.background),
      );
      expect(OrganicColors.of(Brightness.dark), OrganicColors.dark);
      expect(OrganicColors.of(Brightness.light), OrganicColors.light);
    });

    test('the frame sits behind, and differs from, the page in light', () {
      expect(OrganicColors.light.frame, const Color(0xFFE8DCC6));
      expect(
        OrganicColors.light.frame.computeLuminance(),
        lessThan(OrganicColors.light.background.computeLuminance()),
      );
    });

    test('text on background clears WCAG AA for body copy', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      for (final theme in [OrganicColors.light, OrganicColors.dark]) {
        expect(
          contrast(theme.text, theme.background),
          greaterThanOrEqualTo(4.5),
          reason: 'primary text must be readable, not just decorative',
        );
      }
    });

    test('the accent is documented as unusable for body copy', () {
      double contrast(Color a, Color b) {
        final la = a.computeLuminance(), lb = b.computeLuminance();
        final hi = la > lb ? la : lb, lo = la > lb ? lb : la;
        return (hi + 0.05) / (lo + 0.05);
      }

      // The system states accent:ground is ~3:1 — chrome only. This pins the
      // fact so nobody "fixes" a screen by putting paragraph text in accent.
      final onGround = contrast(OrganicPalette.accent, OrganicPalette.bg);
      expect(onGround, greaterThanOrEqualTo(3.0));
      expect(onGround, lessThan(4.5));
      // The prescribed remedy does clear AA.
      expect(
        contrast(OrganicPalette.accent700, OrganicPalette.bg),
        greaterThanOrEqualTo(4.5),
      );
    });
  });

  group('proximity ramp drives Orbit', () {
    test('five tiers, far to closest, in both themes', () {
      for (final theme in [OrganicColors.light, OrganicColors.dark]) {
        expect(theme.proximity, hasLength(5));
        expect(theme.farthest, theme.proximity.first);
        expect(theme.closest, theme.proximity.last);
      }
    });

    test('the closest tier is the strongest accent, not a neutral', () {
      expect(OrganicColors.light.closest, const Color(0xFFE2704A));
      expect(OrganicColors.dark.closest, const Color(0xFFA33F22));
    });

    test('closeness buckets deterministically, never interpolates', () {
      final c = OrganicColors.light;
      // Same input must always give the same tier — a session must not shuffle
      // colours between rebuilds.
      expect(c.proximityAt(0), c.proximity[0]);
      expect(c.proximityAt(1), c.proximity[4]);
      expect(c.proximityAt(0.5), c.proximity[2]);
      expect(c.proximityAt(0.5), c.proximityAt(0.5));
      // Every result is one of the five authored colours.
      for (var i = 0; i <= 20; i++) {
        expect(c.proximity, contains(c.proximityAt(i / 20)));
      }
    });

    test('out-of-range and NaN closeness degrade safely', () {
      final c = OrganicColors.light;
      expect(c.proximityAt(-1), c.farthest);
      expect(c.proximityAt(9), c.closest);
      expect(c.proximityAt(double.nan), c.farthest);
    });
  });

  group('theme extension behaviour', () {
    test('lerp keeps brightness categorical and ramps aligned', () {
      final mid = OrganicColors.light.lerp(OrganicColors.dark, 0.5);
      expect(mid.proximity, hasLength(5));
      expect(mid.brightness, Brightness.dark);
      final early = OrganicColors.light.lerp(OrganicColors.dark, 0.1);
      expect(early.brightness, Brightness.light);
    });

    test('lerp against null is identity', () {
      expect(OrganicColors.light.lerp(null, 0.5), OrganicColors.light);
    });

    testWidgets('resolves from a real Theme, both brightnesses at once', (
      t,
    ) async {
      OrganicColors? outer, inner;
      await t.pumpWidget(
        MaterialApp(
          theme: ThemeData(extensions: const [OrganicColors.light]),
          home: Builder(
            builder: (context) {
              outer = Theme.of(context).extension<OrganicColors>();
              return Theme(
                data: ThemeData(extensions: const [OrganicColors.dark]),
                child: Builder(
                  builder: (context) {
                    inner = Theme.of(context).extension<OrganicColors>();
                    return const SizedBox();
                  },
                ),
              );
            },
          ),
        ),
      );

      // No static cached palette: two themes coexist in one tree.
      expect(outer!.isDark, isFalse);
      expect(inner!.isDark, isTrue);
    });
  });
}
