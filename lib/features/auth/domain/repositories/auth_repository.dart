import '../entities/account.dart';
import '../entities/sign_in_result.dart';

/// Account authentication (contract §3). Google is the only production provider;
/// the session token is opaque and long-lived (validated via [currentSession]).
abstract class AuthRepository {
  /// Exchange a Google ID token for a backend session. Pass [installationId] to
  /// migrate the current guest's wallet/history into the account in one shot.
  Future<SignInResult> signInWithGoogle({
    required String idToken,
    String? installationId,
    String? deviceLabel,
  });

  /// Validate the stored session bearer. Returns the [Account] when still
  /// authenticated, or `null` on a 401 (session gone → fall back to guest).
  Future<Account?> currentSession();

  /// Update the signed-in account's public profile (contract §4,
  /// `PATCH /account/me`). Only non-null fields are sent. Returns the updated
  /// [Account].
  Future<Account> updateAccount({String? displayName, String? avatarUrl});

  /// Revoke the current session server-side.
  Future<void> logout();

  /// Merge a guest installation's wallet/history into the signed-in account.
  Future<void> migrateGuest({required String installationId});
}

/// Platform gateway that obtains a Google **ID token** for the backend audience
/// (the Web/Server client id). Abstracted so tests never touch native Google.
abstract class GoogleAuthGateway {
  /// Returns a fresh Google ID token, or `null` if the user cancelled.
  /// Throws [GoogleAuthException] on configuration/other failures.
  Future<String?> obtainIdToken();

  /// Sign the user out of the local Google session (does not touch the backend).
  Future<void> signOut();

  /// Whether interactive Google sign-in is available on this platform.
  bool get isSupported;
}

/// A non-cancellation Google failure (misconfiguration, no UI, etc.).
class GoogleAuthException implements Exception {
  const GoogleAuthException(this.message, {this.isConfiguration = false});
  final String message;
  final bool isConfiguration;
  @override
  String toString() => 'GoogleAuthException($message)';
}
