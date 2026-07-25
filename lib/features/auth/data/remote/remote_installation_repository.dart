import '../../../v2/data/remote/v2_api_client.dart';
import '../../domain/repositories/installation_repository.dart';

/// Live [InstallationRepository] over the V2 REST client (contract
/// `/installations/*`). Bodies send the client UUID as `installation_id`; the
/// server maps it to its canonical `inst_…` id.
class RemoteInstallationRepository implements InstallationRepository {
  RemoteInstallationRepository(this._api);
  final V2ApiClient _api;

  @override
  Future<void> register({
    required String installationId,
    required String platform,
    String? appVersion,
    String? buildNumber,
    String? locale,
    String? timezone,
    String? notificationPermission,
  }) => _api.post(
    '/installations/register',
    body: {
      'installation_id': installationId,
      'platform': platform,
      'app_version': ?appVersion,
      'build_number': ?buildNumber,
      'locale': ?locale,
      'timezone': ?timezone,
      'notification_permission': ?notificationPermission,
    },
  );

  @override
  Future<void> heartbeat(String installationId) => _api.post(
    '/installations/heartbeat',
    body: {'installation_id': installationId},
  );

  @override
  Future<void> attach(String installationId) => _api.post(
    '/installations/attach',
    body: {'installation_id': installationId},
  );

  @override
  Future<void> detach(String installationId) => _api.post(
    '/installations/detach',
    body: {'installation_id': installationId},
  );

  @override
  Future<void> registerPushToken({
    required String installationId,
    required String platform,
    required String token,
    String? appVersion,
    String? buildNumber,
    String? locale,
    String? timezone,
    String? notificationPermission,
  }) => _api.post(
    '/installations/push/register',
    body: {
      'installation_id': installationId,
      'platform': platform,
      'token': token,
      'app_version': ?appVersion,
      'build_number': ?buildNumber,
      'locale': ?locale,
      'timezone': ?timezone,
      'notification_permission': ?notificationPermission,
    },
  );

  @override
  Future<void> invalidatePushToken({
    required String installationId,
    required String platform,
  }) => _api.post(
    '/installations/push/invalidate',
    body: {'installation_id': installationId, 'platform': platform},
  );
}
