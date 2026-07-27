import 'package:flutter/material.dart';

/// Spacing scale — the 16 steps documented on Figma's Foundations page,
/// on a 4px base grid (audit §9.5).
///
/// Existing screens use off-grid values (`3, 5, 9, 43, 47, 51, 53, 63, 70, 72,
/// 75` — audit §6.3). Those are left untouched in this phase; new components
/// must draw from this scale only.
class SiyaqSpacing {
  SiyaqSpacing._();

  static const none = 0.0;
  static const xxxs = 2.0;
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const smd = 10.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 20.0;
  static const xxl = 24.0;
  static const xxxl = 32.0;
  static const huge = 40.0;
  static const huge2 = 48.0;
  static const huge3 = 56.0;
  static const huge4 = 64.0;
  static const huge5 = 80.0;

  /// All steps in ascending order — used by the gallery's spacing ruler.
  static const scale = <(String, double)>[
    ('none', none),
    ('xxxs', xxxs),
    ('xxs', xxs),
    ('xs', xs),
    ('sm', sm),
    ('smd', smd),
    ('md', md),
    ('lg', lg),
    ('xl', xl),
    ('xxl', xxl),
    ('xxxl', xxxl),
    ('huge', huge),
    ('huge2', huge2),
    ('huge3', huge3),
    ('huge4', huge4),
    ('huge5', huge5),
  ];

  /// Minimum interactive target, per Figma's accessibility rules and the
  /// Material/HIG floor. Enforced by the tap primitive.
  static const minTouchTarget = 44.0;

  /// Standard screen gutter.
  static const screenGutter = xxl;
}

/// Named corner radii — Figma's 9 documented steps (audit §9.5).
///
/// Note the conflict recorded in audit §11-8: Foundations documents `lg = 12`
/// while the bound variable says `radius/lg = 16`. Foundations is treated as
/// authoritative here because it is the approved page; `button` is called out
/// separately so the 12px button radius survives either reading.
class SiyaqRadius {
  SiyaqRadius._();

  static const none = 0.0;
  static const xs = 2.0;
  static const sm = 4.0;
  static const md = 8.0;
  static const lg = 12.0;
  static const xl = 16.0;
  static const xxl = 20.0;
  static const xxxl = 24.0;
  static const full = 999.0;

  /// Button radius (Figma `radius/button`).
  static const button = lg;

  /// Default card/surface radius, matching current app usage (16 dominates).
  static const card = xl;

  static const scale = <(String, double)>[
    ('none', none),
    ('xs', xs),
    ('sm', sm),
    ('md', md),
    ('lg', lg),
    ('xl', xl),
    ('2xl', xxl),
    ('3xl', xxxl),
    ('full', full),
  ];

  static BorderRadius all(double r) => BorderRadius.circular(r);

  /// Direction-aware radius — mirrors correctly under RTL.
  static BorderRadiusDirectional only({
    double topStart = 0,
    double topEnd = 0,
    double bottomStart = 0,
    double bottomEnd = 0,
  }) => BorderRadiusDirectional.only(
    topStart: Radius.circular(topStart),
    topEnd: Radius.circular(topEnd),
    bottomStart: Radius.circular(bottomStart),
    bottomEnd: Radius.circular(bottomEnd),
  );
}
