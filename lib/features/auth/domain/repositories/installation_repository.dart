/// App-installation lifecycle (contract §installations). The installation is the
/// stable, guest-owned device identity (keyed by the client `X-Installation-ID`
/// UUID). It survives logout and restarts; login **attaches** it to the account.
abstract class InstallationRepository {
  /// Register (idempotent) the guest installation with device metadata.
  Future<void> register({
    required String installationId,
    required String platform,
    String? appVersion,
    String? buildNumber,
    String? locale,
    String? timezone,
    String? notificationPermission,
  });

  /// Liveness ping — updates `last_seen_at`.
  Future<void> heartbeat(String installationId);

  /// Attach the guest installation to the signed-in account (bearer).
  Future<void> attach(String installationId);

  /// Detach on logout (bearer) — the installation returns to guest ownership.
  Future<void> detach(String installationId);

  /// Register/update the FCM push token for this installation
  /// (`POST /installations/push/register` → `RegisterPushRequest`). Field names
  /// match that contract exactly: `app_build` (not `build_number`) and
  /// `notifications_enabled` (boolean, not the string `notification_permission`
  /// used by the separate `/installations/register` endpoint).
  Future<void> registerPushToken({
    required String installationId,
    required String platform,
    required String token,
    String? appVersion,
    String? appBuild,
    String? locale,
    String? timezone,
    bool? notificationsEnabled,
  });

  /// Invalidate the push token (e.g. on logout / notifications disabled).
  Future<void> invalidatePushToken({
    required String installationId,
    required String platform,
  });
}
