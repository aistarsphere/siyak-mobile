/// ─── SyIcon — the application's only icon surface ────────────────────────────
///
/// The Organic system specifies **Lucide** icons at **stroke-width 2.75**. This
/// wrapper is the single seam between the app and whatever library provides them,
/// so swapping the backend later touches this file and nothing else.
///
/// Nothing outside `lib/core/design/organic/` should import
/// `lucide_icons_flutter` directly. [SyIcons] re-exports the glyphs the app
/// actually uses, which keeps the dependency contained and makes the app's icon
/// vocabulary reviewable in one place.
///
/// ## Stroke width
///
/// The design asks for stroke-width **2.75**, and the backend can supply it: the
/// package ships six separate Lucide builds (`Lucide100`…`Lucide600`), each the
/// same codepoints at a different stroke. Thickness is therefore chosen by
/// selecting a *variant IconData*, not by styling one glyph.
///
/// An earlier pass here mapped `strokeWidth` onto a font-weight variation to look
/// as though it were doing something, and then recorded the whole thing as an
/// unfixable deviation. Both were wrong. What remains true is that the steps are
/// **discrete**: the design's 2.75 is served by the nearest one rather than
/// exactly, and [SyIconStroke] documents the assumed scale.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'organic_tokens.dart';

/// The icon vocabulary, named for what each glyph *means* in Siyaq rather than
/// for its Lucide slug, so a backend swap or an icon substitution stays local.
abstract final class SyIcons {
  // Each entry names the *design* stroke step (see [SyIconStroke.design]), so a
  // change of step is one edit here rather than a sweep of call sites.

  // ── Navigation ────────────────────────────────────────────────────────────
  /// Leading direction of travel. **Mirrors** under RTL — see [SyIcon.mirror].
  static const back = LucideIcons.arrowLeft500;
  static const forward = LucideIcons.arrowRight500;
  static const close = LucideIcons.x500;
  static const chevronDown = LucideIcons.chevronDown500;
  static const chevronUp = LucideIcons.chevronUp500;

  // ── Destinations ──────────────────────────────────────────────────────────
  static const home = LucideIcons.house500;
  static const leaderboard = LucideIcons.trophy500;
  static const profile = LucideIcons.user500;
  static const settings = LucideIcons.settings500;

  // ── Gameplay ──────────────────────────────────────────────────────────────
  /// The hint lamp. Prominent in the prototype's game header.
  static const hint = LucideIcons.lightbulb500;

  /// Submit a guess — the send affordance inside the composer pill. Mirrors.
  static const submit = LucideIcons.arrowRight500;
  static const language = LucideIcons.globe500;
  static const solved = LucideIcons.check500;
  static const thread = LucideIcons.circle500;

  /// Icons whose meaning is directional, so they must flip in RTL. A tick or a
  /// lamp must not; flipping those is the classic mirroring bug.
  ///
  /// [submit] deliberately shares [forward]'s glyph, so listing both would be a
  /// duplicate set element — membership covers it either way.
  ///
  /// Not `const`: `IconData` overrides `==`, which Dart forbids in a constant set.
  static final directional = <IconData>{back, forward};
}

/// Renders an icon from the Organic system.
class SyIcon extends StatelessWidget {
  const SyIcon({
    super.key,
    required this.icon,
    this.size = SyIconSize.md,
    this.color,
    this.strokeWidth = designStrokeWidth,
    this.semanticLabel,
    this.mirror,
  });

  /// A decorative icon: invisible to assistive tech.
  ///
  /// Use when an adjacent label already carries the meaning. Anything a player
  /// must understand on its own needs a [semanticLabel] instead.
  const SyIcon.decorative({
    super.key,
    required this.icon,
    this.size = SyIconSize.md,
    this.color,
    this.strokeWidth = designStrokeWidth,
    this.mirror,
  }) : semanticLabel = null;

  /// Stroke width the design specifies.
  static const designStrokeWidth = SyIconStroke.designStrokeWidth;

  final IconData icon;
  final double size;
  final Color? color;

  /// Requested stroke width. Defaults to the design's 2.75.
  final double strokeWidth;

  /// Announced label. Null means decorative.
  final String? semanticLabel;

  /// Force mirroring on or off. Null means "decide from [SyIcons.directional]",
  /// which is almost always what you want.
  final bool? mirror;

  /// Whether this icon flips in the given direction.
  bool mirrorsIn(TextDirection direction) {
    if (direction != TextDirection.rtl) return false;
    return mirror ?? SyIcons.directional.contains(icon);
  }

  @override
  Widget build(BuildContext context) {
    final direction = Directionality.of(context);
    final flip = mirrorsIn(direction);

    Widget glyph = Icon(
      icon,
      size: size,
      color: color,
      // Mirroring is handled below rather than by Icon's own textDirection, so
      // the decision stays in one auditable place and can be overridden per call.
      textDirection: TextDirection.ltr,
      // Stroke is not styled here — it is baked into whichever `LucideNNN`
      // family [icon] came from. [SyIcons] selects the design step centrally.
    );

    if (flip) {
      glyph = Transform.flip(flipX: true, child: glyph);
    }

    // Semantics wraps the transform so the label is announced regardless of
    // mirroring, and decorative icons are excluded outright rather than being
    // given an empty label — an empty label is still a node.
    return semanticLabel == null
        ? ExcludeSemantics(child: glyph)
        : Semantics(label: semanticLabel, image: true, child: glyph);
  }

  /// Whether the backend can render distinct stroke widths at all.
  ///
  /// True: the package ships six Lucide builds. The steps are discrete, so the
  /// design's 2.75 is approximated by the nearest — see [SyIconStroke].
  static const backendHonoursStrokeWidth = true;
}

/// The stroke steps the Lucide package provides.
///
/// Six builds of the same glyph set, `Lucide100`…`Lucide600`. The package does
/// not publish what stroke each corresponds to, so the mapping below is an
/// **assumption**: Lucide's own `stroke-width` range is 1–3 with a default of 2,
/// spread linearly across the six steps. It is written down rather than buried so
/// it can be corrected if upstream documents otherwise.
///
///   w100 ≈ 1.0 · w200 ≈ 1.4 · w300 ≈ 1.8 · w400 ≈ 2.2 · w500 ≈ 2.6 · w600 ≈ 3.0
///
/// The design's 2.75 falls between w500 and w600 and is nearer w500 (Δ0.15 vs
/// Δ0.25), so [design] is w500.
enum SyIconStroke {
  w100(approxStroke: 1.0),
  w200(approxStroke: 1.4),
  w300(approxStroke: 1.8),
  w400(approxStroke: 2.2),
  w500(approxStroke: 2.6),
  w600(approxStroke: 3.0);

  const SyIconStroke({required this.approxStroke});

  /// Assumed stroke width this build renders at.
  final double approxStroke;

  /// What the Organic system asks for.
  static const designStrokeWidth = 2.75;

  /// The step [SyIcons] uses.
  static const design = w500;

  /// The step closest to [target] under the assumed scale.
  static SyIconStroke nearest(double target) {
    var best = values.first;
    for (final step in values) {
      if ((step.approxStroke - target).abs() <
          (best.approxStroke - target).abs()) {
        best = step;
      }
    }
    return best;
  }
}

/// Icon sizes. The prototype draws interface icons at 18–19px inside 38px
/// circular taps, which is where these come from.
abstract final class SyIconSize {
  /// Inline with small text.
  static const sm = 16.0;

  /// The interface default — the prototype's 19px header and composer glyphs.
  static const md = 19.0;

  /// Emphasis, e.g. an empty-state mark.
  static const lg = 24.0;

  /// The circular tap target those glyphs sit inside.
  static const tapTarget = 38.0;
}

/// Convenience: an icon on the Organic surface, coloured from the theme's text
/// role by default. Kept separate so [SyIcon] itself stays theme-free and usable
/// inside painters and tests.
class SyThemedIcon extends StatelessWidget {
  const SyThemedIcon({
    super.key,
    required this.icon,
    this.size = SyIconSize.md,
    this.semanticLabel,
    this.script,
  });

  final IconData icon;
  final double size;
  final String? semanticLabel;

  /// Reserved for scripts that need a different glyph, not just a flip. Unused
  /// today; present so the call sites do not change when one appears.
  final OrganicScript? script;

  @override
  Widget build(BuildContext context) => SyIcon(
    icon: icon,
    size: size,
    semanticLabel: semanticLabel,
    color: DefaultTextStyle.of(context).style.color,
  );
}
