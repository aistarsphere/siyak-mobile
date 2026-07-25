import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';

import '../../firebase_options.dart';

/// Initializes Firebase exactly once, before app startup, using the generated
/// platform options (`firebase_options.dart`, project `siyak-game`).
///
/// - **Fails visibly in development** (rethrows) so a broken config is obvious.
/// - **Degrades gracefully in release** — a Firebase outage must never block or
///   crash app launch (the app is fully usable without it).
/// - **Avoids duplicate initialization** and **never blocks forever** (timeout).
/// - Logs no credentials/tokens/private configuration.
Future<void> initializeFirebase() async {
  if (Firebase.apps.isNotEmpty) return; // already initialized
  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    ).timeout(const Duration(seconds: 10));
    if (kDebugMode) {
      debugPrint('[Firebase] initialized: ${Firebase.app().options.projectId}');
    }
  } catch (e, st) {
    if (kDebugMode) {
      // Surface loudly in development.
      FlutterError.reportError(
        FlutterErrorDetails(
          exception: e,
          stack: st,
          library: 'firebase_bootstrap',
          context: ErrorDescription('Firebase.initializeApp failed'),
        ),
      );
      rethrow;
    }
    // Release: continue without Firebase; log type only (no config values).
    debugPrint('[Firebase] init skipped (${e.runtimeType})');
  }
}
