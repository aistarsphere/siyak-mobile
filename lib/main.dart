import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/push_notifications.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Firebase foundation (Core + Messaging). Initialized once before startup;
  // never requests notification permission here.
  await initializeFirebase();

  final prefs = await SharedPreferences.getInstance();
  // Debug-only: surface the effective backend base URL (from CG_BASE define,
  // saved override, or the documented default).
  if (kDebugMode) {
    final override = prefs.getString('siyaq.baseUrlOverride');
    debugPrint(
      '[Siyaq] effective CG_BASE = ${AppConfig.resolveBaseUrl(override)}',
    );
    // Prove FCM is installed (redacted token only) — non-blocking, no prompt.
    unawaited(
      verifyFcmInstallation(PushMessagingService(FirebaseMessaging.instance)),
    );
  }
  runApp(
    ProviderScope(
      overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
      child: const SiyagApp(),
    ),
  );
}
