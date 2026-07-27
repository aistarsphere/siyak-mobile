import 'package:flutter/material.dart';

import '../tokens/siyaq_typography.dart';
import 'context_tokens.dart';

/// **Migration bridge — temporary.**
///
/// Reproduces the old `ST.ar/sys/mono(size)` helpers *exactly*, but resolves the
/// default text colour from [BuildContext] instead of a mutable global. Same
/// family, same size, same weight, same `height` (null unless passed) → the
/// migration is **pixel-identical**.
///
/// It exists because the two changes are independent and must not be conflated:
///
///  * removing the global colour state is safe and invisible → **this phase**;
///  * collapsing 23 ad-hoc font sizes into 12 named roles *changes rendering*
///    (audit §6.1) → **Phase 3**, per component, with the gallery to verify.
///
/// Do not use in new code. New components take [SiyaqTextRole] via
/// `context.type.role(...)`. This bridge is deleted when the last call site is
/// migrated.
extension SiyaqLegacyTypeContext on BuildContext {
  SiyaqLegacyType get legacyType => SiyaqLegacyType(this);
}

class SiyaqLegacyType {
  const SiyaqLegacyType(this._context);

  final BuildContext _context;

  /// Legacy `ST.ar` — Arabic family, explicit size, no default line-height.
  TextStyle ar(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double? height,
  }) => _context.type.custom(
    script: SiyaqScript.arabic,
    size: size,
    weight: weight,
    color: color ?? _context.colors.textPrimary,
    height: height,
  );

  /// Legacy `ST.mono` — mono family, explicit size, `letterSpacing` default 0.
  TextStyle mono(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
    double letterSpacing = 0,
  }) => _context.type.custom(
    script: SiyaqScript.mono,
    size: size,
    weight: weight,
    color: color ?? _context.colors.textPrimary,
    letterSpacing: letterSpacing,
  );

  /// Legacy `ST.sys` — Latin family, explicit size.
  TextStyle sys(
    double size, {
    FontWeight weight = FontWeight.w400,
    Color? color,
  }) => _context.type.custom(
    script: SiyaqScript.latin,
    size: size,
    weight: weight,
    color: color ?? _context.colors.textPrimary,
  );
}
