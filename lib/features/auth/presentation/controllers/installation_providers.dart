import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../v2/data/installation_id_store.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../data/remote/remote_installation_repository.dart';
import '../../domain/repositories/installation_repository.dart';

/// Live installation repository over the shared V2 REST client. Used to send the
/// FCM token to the backend (`/installations/push/*`) and attach/detach the
/// installation on login/logout.
final installationRepositoryProvider = Provider<InstallationRepository>(
  (ref) => RemoteInstallationRepository(ref.watch(v2ApiClientProvider)),
);

/// Ensures the backend knows about this device before anything else uses it.
final installationRegistrarProvider = Provider<InstallationRegistrar>(
  (ref) => InstallationRegistrar(
    store: ref.watch(installationIdStoreProvider),
    repo: ref.watch(installationRepositoryProvider),
  ),
);

/// Creates the backend installation record for this device (idempotent upsert).
///
/// The backend rejects `/installations/push/register`, `/installations/attach`
/// and `/installations/heartbeat` with `INSTALLATION_NOT_FOUND` ("Register the
/// installation first.") until this has run. Because push registration is
/// best-effort, that rejection is otherwise invisible — and the device silently
/// never receives a backend-sent notification. Every caller of those endpoints
/// must therefore await [ensureRegistered] first.
class InstallationRegistrar {
  InstallationRegistrar({required this.store, required this.repo});

  final InstallationIdStore store;
  final InstallationRepository repo;

  Future<String>? _done;

  /// Registers once per process and returns the client installation id.
  /// A failure is not cached, so the next caller retries (e.g. after the device
  /// regains connectivity).
  Future<String> ensureRegistered() =>
      _done ??= _register().onError((error, stack) {
        _done = null;
        Error.throwWithStackTrace(error!, stack);
      });

  Future<String> _register() async {
    final id = await store.getOrCreate();
    await repo.register(
      installationId: id,
      platform: defaultTargetPlatform == TargetPlatform.iOS
          ? 'ios'
          : 'android',
      appVersion: AppConfig.appVersion,
      buildNumber: AppConfig.buildNumber,
      locale: Platform.localeName,
      timezone: DateTime.now().timeZoneName,
    );
    return id;
  }
}
