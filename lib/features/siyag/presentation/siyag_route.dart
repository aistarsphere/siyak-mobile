import 'package:flutter/material.dart';

import '../../../core/theme/siyag_theme.dart';

/// Route transition from App.tsx: fade + slide y 12→0, 240ms, easeOutQuint.
Route<T> siyagRoute<T>(Widget page) => PageRouteBuilder<T>(
      transitionDuration: SM.route,
      reverseTransitionDuration: SM.route,
      pageBuilder: (_, animation, _) {
        final curved = CurvedAnimation(parent: animation, curve: SM.easeOutQuint);
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
