import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Persists the account **session token** (`sess_…` bearer) in platform secure
/// storage (Android Keystore-backed / iOS Keychain). Present only while the
/// user is signed into an account; guests have none.
///
/// Only the opaque session token is stored — never the Google ID token, email,
/// or any provider secret.
class SessionStore {
  SessionStore({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          );

  static const _key = 'siyaq.v2.sessionToken';

  final FlutterSecureStorage _storage;

  /// In-memory cache so synchronous header injection is possible after the
  /// first async read on launch.
  String? _cached;
  bool _loaded = false;

  /// The current token if already loaded into memory (null if none/unknown).
  String? get cachedToken => _cached;

  /// Loads the token from secure storage into the cache (once), returning it.
  Future<String?> load() async {
    if (_loaded) return _cached;
    _cached = await _storage.read(key: _key);
    _loaded = true;
    return _cached;
  }

  Future<void> save(String token) async {
    _cached = token;
    _loaded = true;
    await _storage.write(key: _key, value: token);
  }

  Future<void> clear() async {
    _cached = null;
    _loaded = true;
    await _storage.delete(key: _key);
  }
}
