import 'package:flutter/material.dart';

import '../tokens/siyaq_spacing.dart';

/// Accessibility foundation.
///
/// The audit found **zero** `Semantics` usages and **zero** text-scaling
/// handling in the app (§7). This file provides the primitives so components
/// built from Phase 3 onward inherit correct behaviour by construction, rather
/// than having accessibility retrofitted screen-by-screen later.
///
/// **No production screen is modified in this phase** — nothing here is wired
/// into existing UI yet.
class SiyaqA11y {
  SiyaqA11y._();

  /// Text-scale ceiling for dense, fixed-geometry surfaces.
  ///
  /// Flutter's default is unbounded, and the app currently has fixed heights
  /// (44–192px, audit §12) that clip at large scales. Components should prefer
  /// intrinsic height + min-height; where a hard cap is unavoidable, clamp with
  /// [clampTextScale] rather than disabling scaling outright.
  static const maxScaleDense = 1.6;

  /// Scale points the gallery validates against.
  static const validationScales = <double>[1.0, 1.3, 2.0];

  /// Clamp the inherited text scale for a subtree.
  static Widget clampTextScale({
    required Widget child,
    double max = maxScaleDense,
    double min = 1.0,
  }) => Builder(
    builder: (context) {
      final media = MediaQuery.of(context);
      return MediaQuery(
        data: media.copyWith(
          textScaler: media.textScaler.clamp(
            minScaleFactor: min,
            maxScaleFactor: max,
          ),
        ),
        child: child,
      );
    },
  );

  /// Guarantee a minimum interactive area without changing visual size.
  ///
  /// Wraps [child] so its hit target is at least
  /// [SiyaqSpacing.minTouchTarget] square, as Figma's Foundations page requires.
  static Widget minTarget({
    required Widget child,
    double size = SiyaqSpacing.minTouchTarget,
  }) => Center(
    widthFactor: 1,
    heightFactor: 1,
    child: ConstrainedBox(
      constraints: BoxConstraints(minWidth: size, minHeight: size),
      child: Center(widthFactor: 1, heightFactor: 1, child: child),
    ),
  );

  /// Semantics wrapper for an interactive control.
  ///
  /// Merges descendant semantics so a screen reader announces one node, and
  /// exposes the button/enabled/selected state that assistive tech needs.
  static Widget action({
    required Widget child,
    required String label,
    String? hint,
    bool enabled = true,
    bool selected = false,
    bool isButton = true,
  }) => Semantics(
    container: true,
    button: isButton,
    enabled: enabled,
    selected: selected,
    label: label,
    hint: hint,
    child: ExcludeSemantics(child: child),
  );

  /// Semantics for a decorative element — hidden from assistive tech.
  static Widget decorative(Widget child) => ExcludeSemantics(child: child);

  /// Semantics for an icon that carries meaning (never decorative).
  static Widget meaningfulIcon({
    required Widget child,
    required String label,
  }) => Semantics(
    label: label,
    image: true,
    child: ExcludeSemantics(child: child),
  );
}

/// A visible focus ring, satisfying Figma's stated 2px focus-ring rule.
///
/// Figma mandates *"visible focus rings on all interactive components (2px
/// `border/focus` token)"* but ships **no Focus variant on any component** and
/// never defined the token (audit §11-11). The token is provided as
/// `colors.borderFocus`; this widget draws it.
class SiyaqFocusRing extends StatelessWidget {
  const SiyaqFocusRing({
    super.key,
    required this.child,
    required this.focused,
    required this.color,
    this.radius = 12,
    this.width = 2,
    this.gap = 2,
  });

  final Widget child;
  final bool focused;
  final Color color;
  final double radius;
  final double width;

  /// Inset between the child's edge and the ring.
  final double gap;

  @override
  Widget build(BuildContext context) {
    if (!focused) return child;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          top: -gap,
          bottom: -gap,
          left: -gap,
          right: -gap,
          child: IgnorePointer(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(radius + gap),
                border: Border.all(color: color, width: width),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
