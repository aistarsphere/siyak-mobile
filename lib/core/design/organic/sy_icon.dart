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
/// ## Stroke width — a real, documented deviation
///
/// The backend today is `lucide_icons_flutter`, an **icon font**. Font glyphs
/// carry their stroke baked in — Lucide's fonts are generated at the library
/// default of 2.0 — so the design's 2.75 is **not** reproducible through it.
///
/// [SyIcon.strokeWidth] therefore exists and is honoured by the *contract*, not
/// yet by the pixels: it is recorded, exposed to tests, and will take effect the
/// moment the backend becomes SVG-based (`flutter_svg` over Lucide's SVG source),
/// which is the only faithful route. Call sites are already written against it,
/// so that switch needs no sweep.
///
/// The glyph *shapes* are correct Lucide; only the stroke weight differs from the
/// specified 2.75. That is the trade taken to avoid bundling and rasterising an
/// SVG set in this milestone, and it is recorded rather than hidden.
library;

import 'package:flutter/widgets.dart';
import 'package:lucide_icons_flutter/lucide_icons.dart';

import 'organic_tokens.dart';

/// The icon vocabulary, named for what each glyph *means* in Siyaq rather than
/// for its Lucide slug, so a backend swap or an icon substitution stays local.
abstract final class SyIcons {
  // ── Navigation ────────────────────────────────────────────────────────────
  /// Leading direction of travel. **Mirrors** under RTL — see [SyIcon.mirror].
  static const back = LucideIcons.arrowLeft;
  static const forward = LucideIcons.arrowRight;
  static const close = LucideIcons.x;
  static const chevronDown = LucideIcons.chevronDown;
  static const chevronUp = LucideIcons.chevronUp;

  // ── Destinations ──────────────────────────────────────────────────────────
  static const home = LucideIcons.house;
  static const leaderboard = LucideIcons.trophy;
  static const profile = LucideIcons.user;
  static const settings = LucideIcons.settings;

  // ── Gameplay ──────────────────────────────────────────────────────────────
  /// The hint lamp. Prominent in the prototype's game header.
  static const hint = LucideIcons.lightbulb;

  /// Submit a guess — the send affordance inside the composer pill. Mirrors.
  static const submit = LucideIcons.arrowRight;
  static const language = LucideIcons.globe;
  static const solved = LucideIcons.check;
  static const thread = LucideIcons.circle;

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

  /// Stroke width the design specifies. See the library doc: recorded now,
  /// pixel-accurate once the backend renders SVG.
  static const designStrokeWidth = 2.75;

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
      // [strokeWidth] is deliberately not applied: an icon font has its stroke
      // baked into the glyph outlines and `Icon` exposes no axis to bend. Faking
      // it with a weight variation would be theatre. The value is carried for the
      // SVG backend that will honour it.
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

  /// Whether the active backend can actually render [strokeWidth].
  ///
  /// False today. Exposed so a test can assert the deviation is known rather than
  /// forgotten, and so a debug overlay could surface it.
  static const backendHonoursStrokeWidth = false;
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
