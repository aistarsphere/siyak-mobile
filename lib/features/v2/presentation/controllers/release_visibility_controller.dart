import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../domain/entities/release_visibility.dart';
import 'profile_controller.dart';
import 'v2_providers.dart';

/// Release/version information for the Profile screen.
///
/// Resolves to [ReleaseVisibility.hidden] on **any** failure, so the Profile
/// screen renders identically whether the endpoint is healthy, disabled or
/// unreachable. It is never awaited by Profile itself — the section is simply
/// absent until data arrives, which is why loading cannot block or shift the
/// screen.
///
/// ## Refresh triggers
///
/// * **authenticated account changes** — [sessionControllerProvider] is watched,
///   because eligibility is decided per account server-side. Signing in or out
///   re-asks.
/// * **installation identity / profile refresh** — [profileControllerProvider]
///   is watched. The installation id is generated once and never rotates at
///   runtime, so the profile it produces is the observable proxy for it.
/// * **UI language changes** — the `language` query is sent from the app's own
///   setting, so switching language re-asks in the new language.
/// * **Profile opens** — the section invalidates this provider when the Profile
///   tab is entered. The shell keeps tabs alive in an `IndexedStack`, so nothing
///   remounts and that trigger has to be explicit.
///
/// No WebSocket: the server caches the policy briefly and invalidates on admin
/// update, so opening or refreshing Profile is enough to pick up a change.
final releaseVisibilityProvider = FutureProvider<ReleaseVisibility>((
  ref,
) async {
  final language = ref.watch(appSettingsProvider.select((s) => s.lang));
  final repository = ref.watch(releaseVisibilityRepositoryProvider);

  try {
    // Awaited, not merely watched, so the request is made *once* as the caller
    // the server will actually see. Watching these as plain values would fire an
    // extra fetch on cold start — one as an unidentified caller (which the
    // server answers with the hidden response) and another once identity
    // resolved. Awaiting collapses that into a single, correct call.
    //
    // The values themselves are deliberately unused: eligibility is decided
    // server-side from explicit account flags, and the client must never infer
    // internal-tester status for itself.
    await ref.watch(sessionControllerProvider.future);
    await ref.watch(profileControllerProvider.future);

    return await repository.fetch(language: language);
  } catch (_) {
    return ReleaseVisibility.hidden;
  }
});
