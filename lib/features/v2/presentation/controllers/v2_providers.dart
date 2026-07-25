import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/config/app_config.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../data/installation_id_store.dart';
import '../../data/remote/ranked_realtime_nudge.dart';
import '../../data/remote/remote_realtime_gateway.dart';
import '../../data/remote/remote_repositories.dart';
import '../../data/remote/v2_api_client.dart';
import '../../data/session_store.dart';
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

final installationIdStoreProvider = Provider<InstallationIdStore>(
  (ref) => InstallationIdStore(),
);

/// Account session-token store (`sess_…` bearer). Empty for guests.
final sessionStoreProvider = Provider<SessionStore>((ref) => SessionStore());

/// Bumped whenever the server rejects the current session (401 auth failure),
/// so session-aware controllers can re-evaluate and prompt re-authentication.
final sessionRevokedProvider = StateProvider<int>((ref) => 0);

/// Shared live REST client. Injects `X-Installation-ID` (guest) + `Authorization:
/// Bearer` (account) + `X-Request-ID`; drops a rejected session on 401.
final v2ApiClientProvider = Provider<V2ApiClient>((ref) {
  final override = ref.watch(
    appSettingsProvider.select((s) => s.baseUrlOverride),
  );
  final session = ref.read(sessionStoreProvider);
  return V2ApiClient(
    baseUrl: AppConfig.resolveV2BaseUrl(override),
    installationIdLoader: () =>
        ref.read(installationIdStoreProvider).getOrCreate(),
    sessionTokenProvider: () => session.cachedToken,
    // Persist a rotated session token atomically so queued retries resume with
    // it (single-flight refresh lives in the client).
    onTokenRotated: (newToken) => session.save(newToken),
    onAuthFailure: (_) {
      // Refresh failed / unrecoverable → clear the session and signal listeners.
      session.clear();
      ref.read(sessionRevokedProvider.notifier).state++;
    },
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
  return RemoteProfileRepository(
    ref.watch(v2ApiClientProvider),
    uiLanguage: uiLang,
  );
});

final weeklyRepositoryProvider = Provider<WeeklyRepository>((ref) {
  return RemoteWeeklyRepository(
    ref.watch(v2ApiClientProvider),
    myProfileId: () => _myProfileId(ref),
  );
});

/// Single shared room repo instance per config.
final roomRepositoryProvider = Provider<RoomRepository>((ref) {
  return RemoteRoomRepository(
    ref.watch(v2ApiClientProvider),
    myProfileId: () => _myProfileId(ref),
  );
});

/// Ranked-match realtime nudge factory (§11). Content-agnostic — signals the
/// ranked match stream to refetch the authoritative REST snapshot on any frame.
final rankedRealtimeNudgeProvider = Provider<RankedRealtimeNudge>((ref) {
  final override = ref.watch(
    appSettingsProvider.select((s) => s.baseUrlOverride),
  );
  return RankedRealtimeNudge(
    socketBase: AppConfig.resolveV2SocketBase(override),
  );
});

/// Realtime gateway factory (a fresh gateway per connection).
final realtimeGatewayProvider = Provider<RealtimeGateway>((ref) {
  final override = ref.watch(
    appSettingsProvider.select((s) => s.baseUrlOverride),
  );
  return RemoteRealtimeGateway(
    socketBase: AppConfig.resolveV2SocketBase(override),
    myProfileId: () => _myProfileId(ref),
  );
});
