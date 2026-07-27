import 'package:flutter/material.dart';

import '../../theme/context_tokens.dart';
import '../../tokens/siyaq_typography.dart';

/// Text bound to a named role from the type scale.
///
/// Exists to make the scale the path of least resistance: a call site names a
/// *role*, not a pixel size. The audit found 153 call sites using 23 ad-hoc
/// sizes (§6.1); every new component uses this instead.
///
/// Script resolution, per-script line-height, Arabic tracking suppression and
/// mixed-script font fallback all come from `context.type` — a call site never
/// picks a font family.
class SiyaqText extends StatelessWidget {
  const SiyaqText(
    this.data, {
    super.key,
    this.role = SiyaqTextRole.bodyMedium,
    this.color,
    this.script,
    this.weight,
    this.align,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textDirection,
  });

  /// Convenience for tabular numbers — ranks, timers, room codes.
  const SiyaqText.numeric(
    this.data, {
    super.key,
    this.role = SiyaqTextRole.labelMedium,
    this.color,
    this.weight,
    this.align,
    this.maxLines,
    this.overflow,
    this.softWrap,
    this.semanticsLabel,
    this.textDirection,
  }) : script = SiyaqScript.mono;

  final String data;
  final SiyaqTextRole role;
  final Color? color;

  /// Overrides the locale-derived script. Use for content whose language is
  /// known to differ from the UI language (a Latin player name in Arabic UI).
  final SiyaqScript? script;

  final FontWeight? weight;
  final TextAlign? align;
  final int? maxLines;
  final TextOverflow? overflow;
  final bool? softWrap;

  /// Spoken instead of [data]. Use when the visual string is not readable aloud
  /// — e.g. "#14" should be announced as "rank 14".
  final String? semanticsLabel;

  final TextDirection? textDirection;

  @override
  Widget build(BuildContext context) => Text(
    data,
    style: context.type.role(
      role,
      script: script,
      color: color,
      weight: weight,
    ),
    textAlign: align,
    maxLines: maxLines,
    // Default to ellipsis only when the caller bounded the lines; otherwise let
    // text wrap so large text scales are never clipped.
    overflow: overflow ?? (maxLines != null ? TextOverflow.ellipsis : null),
    softWrap: softWrap,
    semanticsLabel: semanticsLabel,
    textDirection: textDirection,
  );
}
