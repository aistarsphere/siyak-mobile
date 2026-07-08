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

  /// Documented public base URL — the Cloudflare tunnel fronting the
  /// "Arabic English Context Game" service. INCLUDES `/api/context-game`.
  ///
  /// NOTE: `trycloudflare.com` quick tunnels are ephemeral and rotate when
  /// the server restarts; override via Settings or --dart-define=CG_BASE.
  static const String documentedPublicUrl =
      'https://viking-subject-watched-woods.trycloudflare.com/api/context-game';

  /// Build-time override. Primary key is `CG_BASE`; `API_BASE_URL` is kept as
  /// a backward-compatible alias.
  static const String _cgBase = String.fromEnvironment('CG_BASE');
  static const String _apiBaseUrl = String.fromEnvironment('API_BASE_URL');

  static String get baseUrlFromEnv {
    if (_cgBase.isNotEmpty) return _cgBase;
    if (_apiBaseUrl.isNotEmpty) return _apiBaseUrl;
    return documentedPublicUrl;
  }

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
