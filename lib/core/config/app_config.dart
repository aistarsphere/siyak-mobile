/// Single source of truth for backend configuration.
///
/// The unified production backend serves everything under one API root
/// `…/api/v1`:
///  - **Gameplay / semantic engine** under `…/api/v1/game/*`
///    (`/modes`, `/new-game`, `/guess`, `/hint`, `/suggest`).
///  - **Platform** under `…/api/v1/*` (auth, account, installations, wallet,
///    rooms, social, ranked, weekly, capabilities, notifications).
///
/// Resolution order for the API root:
///  1. Runtime developer override saved in Settings (SharedPreferences).
///  2. `--dart-define=CG_BASE=...` at build time.
///  3. The documented public URL below.
class AppConfig {
  AppConfig._();

  /// Production API **root** — includes the `/api/v1` prefix. Override via
  /// Settings or `--dart-define=CG_BASE` only for local/staging testing.
  static const String documentedPublicUrl =
      'https://siyak-api.aljoodnet.info/api/v1';

  /// Build-time override. Primary key is `CG_BASE`; `API_BASE_URL` is kept as
  /// a backward-compatible alias.
  static const String _cgBase = String.fromEnvironment('CG_BASE');
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrlFromEnv {
    if (_cgBase.isNotEmpty) return _cgBase;
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return documentedPublicUrl;
  }

  /// The effective API root (`…/api/v1`) given an optional runtime override.
  static String _apiRoot(String? runtimeOverride) {
    final o = runtimeOverride?.trim() ?? '';
    return normalizeBaseUrl(o.isNotEmpty ? o : baseUrlFromEnv);
  }

  /// Platform REST base (`…/api/v1`) — auth, account, installations, wallet,
  /// rooms, social, ranked, weekly, capabilities.
  static String resolveV2BaseUrl(String? runtimeOverride) =>
      _apiRoot(runtimeOverride);

  /// WebSocket origin derived from the platform base (http→ws, https→wss). The
  /// concrete channel path (`/rooms/{id}/events`, `/ranked-matches/{id}/events`)
  /// is appended by the realtime gateway.
  static String resolveV2SocketBase(String? runtimeOverride) {
    final b = resolveV2BaseUrl(runtimeOverride);
    if (b.startsWith('https://')) return 'wss://${b.substring(8)}';
    if (b.startsWith('http://')) return 'ws://${b.substring(7)}';
    return b;
  }

  /// Documented capability-detection endpoint (relative to the platform base).
  static const String capabilitiesPath = '/capabilities';

  /// The API generation served at the API root.
  static const String apiVersion = '1.0';

  /// App marketing/build version reported to the installation registry.
  /// Overridable at build time with `--dart-define`.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');

  // ── Google Sign-In ───────────────────────────────────────────────────────
  /// The Google **Web/Server OAuth client ID** for project `siyag-503420`.
  /// Passed as `serverClientId` so Google issues an ID token whose audience is
  /// the backend (which verifies it in `POST /api/v1/auth/google`). This is a
  /// client *ID*, not a secret — safe to ship; the client *secret* never is.
  /// Overridable at build time with `--dart-define=GOOGLE_SERVER_CLIENT_ID=`.
  static const String googleServerClientId = String.fromEnvironment(
    'GOOGLE_SERVER_CLIENT_ID',
    defaultValue:
        '1098591360557-am6kibuioo85lmhnp0cmbim62b1ob6i4.apps.googleusercontent.com',
  );

  /// The Google **iOS OAuth client ID** for bundle `com.kaher.siyak` (project
  /// `1098591360557`). Required on iOS/macOS as the `clientId` (Android uses the
  /// SHA-1-registered client instead). Public identifier — never a secret; the
  /// reversed form is the `Info.plist` URL scheme.
  /// Overridable with `--dart-define=GOOGLE_IOS_CLIENT_ID=`.
  static const String googleIosClientId = String.fromEnvironment(
    'GOOGLE_IOS_CLIENT_ID',
    defaultValue:
        '1098591360557-8kishc17ka2t9q5qbg15tmiutkrr5b5f.apps.googleusercontent.com',
  );

  /// Normalizes a user/env supplied base URL (trims trailing slashes/spaces).
  static String normalizeBaseUrl(String url) {
    var u = url.trim();
    while (u.endsWith('/')) {
      u = u.substring(0, u.length - 1);
    }
    return u;
  }

  /// Gameplay / semantic-engine base (`…/api/v1/game`) — used by the Solo game
  /// client for `/modes`, `/new-game`, `/guess`, `/hint`, `/suggest`.
  static String resolveBaseUrl(String? runtimeOverride) =>
      '${_apiRoot(runtimeOverride)}/game';

  static const Duration connectTimeout = Duration(seconds: 10);

  /// Out-of-vocabulary/live guesses can take a few seconds on the server.
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int maxHints = 5;
  static const int autocompleteMinChars = 2;
  static const Duration autocompleteDebounce = Duration(milliseconds: 300);
}
