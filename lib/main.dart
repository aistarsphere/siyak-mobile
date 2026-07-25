import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'app.dart';
import 'core/config/app_config.dart';
import 'core/notifications/notification_service.dart';
import 'features/auth/presentation/controllers/installation_providers.dart';
import 'features/game/presentation/controllers/app_settings_controller.dart';
import 'features/v2/presentation/controllers/v2_providers.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  final prefs = await SharedPreferences.getInstance();
  final container = ProviderContainer(
    overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
  );

  // Send the FCM token to the backend at init and on every rotation.
  NotificationService.instance.onTokenRefreshed = (token) =>
      _registerFcmToken(container, token);

  // Firebase init + notification permission + FCM token happen inside init(),
  // deliberately AFTER the first frame so the app never blocks on the splash.
  unawaited(NotificationService.instance.init());

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

/// Registers the current FCM token with the backend for this installation
/// (`POST /installations/push/register`). Best-effort — retried on next refresh.
Future<void> _registerFcmToken(ProviderContainer container, String token) async {
  if (token.isEmpty) return;
  try {
    final installationId = await container
        .read(installationIdStoreProvider)
        .getOrCreate();
    await container
        .read(installationRepositoryProvider)
        .registerPushToken(
          installationId: installationId,
          platform: defaultTargetPlatform == TargetPlatform.iOS
              ? 'ios'
              : 'android',
          token: token,
        );
    if (kDebugMode) debugPrint('[Notifications] FCM token registered');
  } catch (_) {
    // Ignore; re-registers on the next token refresh / login.
  }
}
