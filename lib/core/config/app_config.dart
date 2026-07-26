/// Single source of truth for backend configuration.
///
/// The base URL **includes** the service path prefix `/api/context-game`,
/// so gameplay endpoints are relative to it (`/health`, `/new-game`, …).
///
/// Resolution order:
///  1. Runtime developer override saved in Settings (SharedPreferences).
///  2. `--dart-define=CG_BASE=...` at build time.
///  3. The documented public Cloudflare URL below.
class AppConfig {
  AppConfig._();

  /// Production Runtime base URL for the "Arabic English Context Game" service.
  /// INCLUDES the `/api/context-game` prefix. This is the stable production
  /// host — not a temporary tunnel. Override via Settings or
  /// `--dart-define=CG_BASE` only for local/staging testing.
  static const String documentedPublicUrl =
      'https://siyak-api.aljoodnet.info/api/context-game';

  /// Build-time override. Primary key is `CG_BASE`; `API_BASE_URL` is kept as
  /// a backward-compatible alias.
  static const String _cgBase = String.fromEnvironment('CG_BASE');
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  /// Optional explicit V2 base (`--dart-define=CG_V2_BASE=...`). When empty,
  /// the V2 base is derived from the gameplay base (`<base>/v2`) so there is
  /// only ONE URL to configure in the common case.
  static const String _cgV2Base = String.fromEnvironment('CG_V2_BASE');

  static String get baseUrlFromEnv {
    if (_cgBase.isNotEmpty) return _cgBase;
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return documentedPublicUrl;
  }

  /// Resolve the effective V2 REST base URL. Order: explicit `CG_V2_BASE`
  /// override → `<effective gameplay base>/v2`.
  static String resolveV2BaseUrl(String? runtimeOverride) {
    if (_cgV2Base.isNotEmpty) return normalizeBaseUrl(_cgV2Base);
    return '${resolveBaseUrl(runtimeOverride)}/v2';
  }

  /// WebSocket origin derived from the V2 base (http→ws, https→wss).
  /// The concrete room path is appended by the realtime gateway once the V2
  /// contract is known.
  static String resolveV2SocketBase(String? runtimeOverride) {
    final v2 = resolveV2BaseUrl(runtimeOverride);
    if (v2.startsWith('https://')) return 'wss://${v2.substring(8)}';
    if (v2.startsWith('http://')) return 'ws://${v2.substring(7)}';
    return v2;
  }

  /// Documented capability-detection endpoint (relative to the V2 base).
  static const String capabilitiesPath = '/capabilities';

  // ── Frozen backend contract identity (bundle `2026-07.1`) ────────────────
  /// The contract revision this client targets. The backend echoes
  /// `contract_version` / `X-Contract-Version`; surfaced for telemetry only.
  static const String contractVersion = '2026-07.1';

  /// The V2 API generation served at the V2 base.
  static const String apiVersion = '2.0';

  /// App marketing/build version reported to the installation registry.
  /// Overridable at build time with `--dart-define`.
  static const String appVersion =
      String.fromEnvironment('APP_VERSION', defaultValue: '1.0.0');
  static const String buildNumber =
      String.fromEnvironment('BUILD_NUMBER', defaultValue: '1');

  // ── Google Sign-In ───────────────────────────────────────────────────────
  /// The Google **Web/Server OAuth client ID** for project `siyag-503420`.
  /// Passed as `serverClientId` so Google issues an ID token whose audience is
  /// the backend (which verifies it in `POST /v2/auth/google`). This is a
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

  /// Resolve the effective base URL given an optional runtime override.
  static String resolveBaseUrl(String? runtimeOverride) {
    final o = runtimeOverride?.trim() ?? '';
    return normalizeBaseUrl(o.isNotEmpty ? o : baseUrlFromEnv);
  }

  static const Duration connectTimeout = Duration(seconds: 10);

  /// Out-of-vocabulary/live guesses can take a few seconds on the server.
  static const Duration receiveTimeout = Duration(seconds: 30);

  static const int maxHints = 5;
  static const int autocompleteMinChars = 2;
  static const Duration autocompleteDebounce = Duration(milliseconds: 300);
}
