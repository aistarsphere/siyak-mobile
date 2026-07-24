import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:uuid/uuid.dart';

/// Persists the anonymous installation ID in platform secure storage
/// (Android Keystore-backed EncryptedSharedPreferences / iOS Keychain).
///
/// The ID is a random **UUID v4** — it is NEVER derived from any hardware
/// identifier (no IMEI / Android ID / serial / MAC / advertising ID).
class InstallationIdStore {
  InstallationIdStore({FlutterSecureStorage? storage, Uuid? uuid})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            // Android v10+ uses custom ciphers automatically; iOS uses the
            // Keychain, unlocked-once so the ID survives restarts.
            iOptions: IOSOptions(
              accessibility: KeychainAccessibility.first_unlock,
            ),
          ),
      _uuid = uuid ?? const Uuid();

  static const _key = 'siyaq.v2.installationId';

  final FlutterSecureStorage _storage;
  final Uuid _uuid;

  /// Returns the existing installation ID, generating and persisting a new
  /// UUID v4 on first launch. Idempotent across calls.
  Future<String> getOrCreate() async {
    final existing = await _storage.read(key: _key);
    if (existing != null && existing.trim().isNotEmpty) return existing;
    final id = _uuid.v4();
    await _storage.write(key: _key, value: id);
    return id;
  }

  Future<String?> peek() => _storage.read(key: _key);

  Future<void> clear() => _storage.delete(key: _key);
}
