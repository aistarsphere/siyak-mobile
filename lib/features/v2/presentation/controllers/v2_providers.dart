import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/config/app_config.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../data/installation_id_store.dart';
import '../../data/remote/remote_realtime_gateway.dart';
import '../../data/remote/remote_repositories.dart';
import '../../data/remote/v2_api_client.dart';
import '../../domain/repositories/v2_repositories.dart';
import 'profile_controller.dart';

/// ─────────────────────────────────────────────────────────────────────────
/// V2 dependency wiring — THE SWAP SEAM.
///
/// Production is REMOTE-ONLY: every provider resolves to a live `data/remote/*`
/// implementation. There is no mock data path in the shipped app. Tests swap
/// these repository providers directly (see test/support/v2_mock/) — the
/// abstract repository interfaces are the only coupling the UI ever sees.
/// ─────────────────────────────────────────────────────────────────────────

final installationIdStoreProvider =
    Provider<InstallationIdStore>((ref) => InstallationIdStore());

/// Shared live REST client (injects `X-Installation-ID`, maps errors, retries).
final v2ApiClientProvider = Provider<V2ApiClient>((ref) {
  final override = ref.watch(appSettingsProvider.select((s) => s.baseUrlOverride));
  return V2ApiClient(
    baseUrl: AppConfig.resolveV2BaseUrl(override),
    installationIdLoader: () =>
        ref.read(installationIdStoreProvider).getOrCreate(),
  );
});

/// Current server profile id (`prof_…`) for attributing "me" in rooms /
/// leaderboards. Read lazily so repos see it once the profile registers.
String? _myProfileId(Ref ref) =>
    ref.read(profileControllerProvider).value?.profileId;

final capabilitiesRepositoryProvider = Provider<CapabilitiesRepository>((ref) {
  return RemoteCapabilitiesRepository(ref.watch(v2ApiClientProvider));
});

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  final uiLang = ref.read(appSettingsProvider).lang;
  return RemoteProfileRepository(ref.watch(v2ApiClientProvider),
      uiLanguage: uiLang);
});

final weeklyRepositoryProvider = Provider<WeeklyRepository>((ref) {
  return RemoteWeeklyRepository(ref.watch(v2ApiClientProvider),
      myProfileId: () => _myProfileId(ref));
});

/// Single shared room repo instance per config.
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RemoteRoomRepository(ref.watch(v2ApiClientProvider),
      myProfileId: () => _myProfileId(ref));
});

/// Realtime gateway factory (a fresh gateway per connection).
final realtimeGatewayProvider = Provider<RealtimeGateway>((ref) {
  final override = ref.watch(appSettingsProvider.select((s) => s.baseUrlOverride));
  return RemoteRealtimeGateway(
    socketBase: AppConfig.resolveV2SocketBase(override),
    myProfileId: () => _myProfileId(ref),
  );
});
