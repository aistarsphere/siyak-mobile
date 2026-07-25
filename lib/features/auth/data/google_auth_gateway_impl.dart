import 'package:flutter/foundation.dart';
import 'package:google_sign_in/google_sign_in.dart';

import '../../../core/config/app_config.dart';
import '../domain/repositories/auth_repository.dart';

/// Real [GoogleAuthGateway] backed by `google_sign_in` v7.
///
/// The ID token is minted for the backend audience via `serverClientId`
/// (the Web/Server OAuth client). The client *secret* is never used here — the
/// backend verifies the token (RS256/JWKS). No email/sub is read locally.
///
/// On iOS/macOS the platform also needs its own **iOS OAuth client ID** as
/// `clientId` (Android instead matches by SHA-1 + package name, so it takes no
/// `clientId`). Both values are public client identifiers — never secrets.
class RealGoogleAuthGateway implements GoogleAuthGateway {
  RealGoogleAuthGateway({String? serverClientId, String? iosClientId})
    : _serverClientId = serverClientId ?? AppConfig.googleServerClientId,
      _iosClientId = iosClientId ?? AppConfig.googleIosClientId;

  final String _serverClientId;
  final String _iosClientId;
  bool _initialized = false;

  GoogleSignIn get _gsi => GoogleSignIn.instance;

  /// Apple platforms require the iOS client ID; Android/others must not set it.
  bool get _isApple =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  Future<void> _ensureInit() async {
    if (_initialized) return;
    await _gsi.initialize(
      clientId: _isApple ? _iosClientId : null,
      serverClientId: _serverClientId,
    );
    _initialized = true;
  }

  @override
  bool get isSupported => _gsi.supportsAuthenticate();

  @override
  Future<String?> obtainIdToken() async {
    await _ensureInit();
    if (!isSupported) {
      throw const GoogleAuthException(
        'Interactive Google sign-in is unavailable on this platform.',
        isConfiguration: true,
      );
    }
    try {
      final account = await _gsi.authenticate();
      final idToken = account.authentication.idToken;
      if (idToken == null || idToken.isEmpty) {
        throw const GoogleAuthException(
          'Google did not return an ID token. Check the OAuth client config.',
          isConfiguration: true,
        );
      }
      return idToken;
    } on GoogleSignInException catch (e) {
      if (e.code == GoogleSignInExceptionCode.canceled) return null;
      final isConfig =
          e.code == GoogleSignInExceptionCode.clientConfigurationError ||
          e.code == GoogleSignInExceptionCode.providerConfigurationError;
      throw GoogleAuthException(
        e.description ?? e.code.name,
        isConfiguration: isConfig,
      );
    }
  }

  @override
  Future<void> signOut() => _gsi.signOut();
}
