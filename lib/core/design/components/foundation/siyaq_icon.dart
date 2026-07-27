import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_icons.dart';

/// A themed, tintable icon with an explicit accessibility contract.
///
/// The audit found emoji used as UI icons (§6.6) — they ignore [IconTheme],
/// cannot be tinted per state, and are invisible to screen readers. This
/// component replaces them and forces the caller to state intent:
///
///  * [SiyaqIcon] — meaningful. Requires a [semanticLabel], which is announced.
///  * [SiyaqIcon.decorative] — purely visual. Hidden from assistive tech, so a
///    screen reader does not read a chevron next to the label it belongs to.
///
/// Making the distinction unavoidable is the point: a nullable label would
/// silently default to "unlabelled icon" everywhere.
class SiyaqIcon extends StatelessWidget {
  const SiyaqIcon(
    this.icon, {
    super.key,
    required String semanticLabel,
    this.size = SiyaqIconSize.md,
    this.color,
  }) : _label = semanticLabel;

  /// An icon that carries no information of its own.
  const SiyaqIcon.decorative(
    this.icon, {
    super.key,
    this.size = SiyaqIconSize.md,
    this.color,
  }) : _label = null;

  final IconData icon;
  final double size;

  /// Defaults to `colors.iconPrimary`, so an icon is always theme-correct.
  final Color? color;

  final String? _label;

  @override
  Widget build(BuildContext context) {
    final resolved = Icon(
      icon,
      size: size,
      color: color ?? context.colors.iconPrimary,
    );
    if (_label == null) return ExcludeSemantics(child: resolved);
    return Semantics(
      label: _label,
      image: true,
      child: ExcludeSemantics(child: resolved),
    );
  }
}
