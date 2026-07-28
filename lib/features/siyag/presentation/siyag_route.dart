import 'package:flutter/material.dart';

import '../../../core/design/tokens/siyaq_motion.dart';

/// Route transition from App.tsx: fade + slide y 12→0, 240ms, easeOutQuint.
///
/// A [PageRouteBuilder]'s duration is fixed at construction, before any
/// context exists, so reduced motion is honoured inside the builder instead:
/// the page is returned bare, fully opaque from the first frame.
Route<T> siyagRoute<T>(Widget page) => PageRouteBuilder<T>(
  transitionDuration: SiyaqMotion.route,
  reverseTransitionDuration: SiyaqMotion.route,
  pageBuilder: (context, animation, _) {
    if (MediaQuery.disableAnimationsOf(context)) return page;
    final curved = CurvedAnimation(
      parent: animation,
      curve: SiyaqMotion.easeOutQuint,
    );
    return FadeTransition(
      opacity: curved,
      child: SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(0, 0.014), // ~12px on 844
          end: Offset.zero,
        ).animate(curved),
        child: page,
      ),
    );
  },
);
