import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/firebase/firebase_bootstrap.dart';
import 'core/notifications/notification_runtime.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final firebaseBootstrap = await ensureFirebaseBootstrapped();

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(prefs),
      firebaseBootstrapResultProvider.overrideWithValue(firebaseBootstrap),
    ],
  );
  final notificationRuntime = container.read(
    notificationRuntimeProvider.notifier,
  );
  unawaited(notificationRuntime.initialize());

  if (kDebugMode) {
    final override = prefs.getString('siyaq.baseUrlOverride');
    debugPrint(
      '[Siyaq] effective CG_BASE = ${AppConfig.resolveBaseUrl(override)}',
    );
  }

  runApp(
    UncontrolledProviderScope(container: container, child: const SiyagApp()),
  );
}
