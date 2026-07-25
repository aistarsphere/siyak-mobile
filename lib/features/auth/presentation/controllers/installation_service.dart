import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../../core/notifications/push_notifications.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/data/installation_id_store.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../data/remote/remote_installation_repository.dart';
import '../../domain/repositories/installation_repository.dart';

final installationRepositoryProvider = Provider<InstallationRepository>(
  (ref) => RemoteInstallationRepository(ref.watch(v2ApiClientProvider)),
);

/// Orchestrates the installation lifecycle: register at startup, attach on
/// login, detach on logout, and keep the FCM push token registered. All calls
/// are best-effort — a failure never blocks the app (guests stay usable).
class InstallationService {
  InstallationService(this._ref);
  final Ref _ref;
  bool _tokenListenerWired = false;

  String get _platform => Platform.isIOS ? 'ios' : 'android';
  InstallationIdStore get _idStore => _ref.read(installationIdStoreProvider);
  InstallationRepository get _repo => _ref.read(installationRepositoryProvider);
  PushMessagingService get _push => _ref.read(pushMessagingServiceProvider);

  Future<String> _id() => _idStore.getOrCreate();

  /// Register (idempotent) the guest installation with device metadata, push the
  /// current token, and keep it fresh across rotations. Called once at startup.
  Future<void> bootstrap() async {
    try {
      final id = await _id();
      final perm = await _push.permissionStatus();
      await _repo.register(
        installationId: id,
        platform: _platform,
        appVersion: AppConfig.appVersion,
        buildNumber: AppConfig.buildNumber,
        locale: _ref.read(appSettingsProvider).lang,
        timezone: DateTime.now().timeZoneName,
        notificationPermission: _permName(perm),
      );
      await _syncPushToken(id);
      _wireTokenRefresh();
      if (kDebugMode) debugPrint('[Installation] registered ($_platform)');
    } catch (e) {
      if (kDebugMode) {
        debugPrint('[Installation] bootstrap skipped (${e.runtimeType})');
      }
    }
  }

  /// After a successful login — attach this installation to the account and
  /// (re)register the push token under the authenticated context.
  Future<void> onLogin() async {
    try {
      final id = await _id();
      await _repo.attach(id);
      await _syncPushToken(id);
      if (kDebugMode) debugPrint('[Installation] attached to account');
    } catch (e) {
      if (kDebugMode) debugPrint('[Installation] attach failed (${e.runtimeType})');
    }
  }

  /// Before logout completes (while the bearer is still valid) — invalidate the
  /// push token and detach. The installation UUID itself is preserved.
  Future<void> onLogout() async {
    try {
      final id = await _id();
      await _repo.invalidatePushToken(installationId: id, platform: _platform);
      await _repo.detach(id);
      if (kDebugMode) debugPrint('[Installation] detached');
    } catch (e) {
      if (kDebugMode) debugPrint('[Installation] detach failed (${e.runtimeType})');
    }
  }

  /// Push the current FCM token to the backend (e.g. after permission granted).
  Future<void> syncPushToken() async {
    try {
      await _syncPushToken(await _id());
    } catch (_) {}
  }

  Future<void> _syncPushToken(String id) async {
    final token = await _push.token();
    if (token == null || token.isEmpty) return;
    await _repo.registerPushToken(
      installationId: id,
      platform: _platform,
      token: token,
    );
    if (kDebugMode) {
      debugPrint(
        '[Installation] push token registered '
        '(${PushMessagingService.fingerprint(token)})',
      );
    }
  }

  void _wireTokenRefresh() {
    if (_tokenListenerWired) return;
    _tokenListenerWired = true;
    _push.onTokenRefresh.listen((token) async {
      try {
        await _repo.registerPushToken(
          installationId: await _id(),
          platform: _platform,
          token: token,
        );
      } catch (_) {}
    });
  }

  static String _permName(PushPermissionStatus s) => switch (s) {
    PushPermissionStatus.authorized => 'authorized',
    PushPermissionStatus.provisional => 'provisional',
    PushPermissionStatus.denied => 'denied',
    PushPermissionStatus.notDetermined => 'not_determined',
  };
}

final installationServiceProvider = Provider<InstallationService>(
  (ref) => InstallationService(ref),
);
