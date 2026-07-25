import 'package:flutter/foundation.dart';
import 'package:sign_in_with_apple/sign_in_with_apple.dart';

import '../domain/repositories/auth_repository.dart';

/// Real [AppleAuthGateway] backed by `sign_in_with_apple`. Requests only the
/// name + email scopes; the backend verifies the `identityToken` (no `.p8`
/// private key ever ships in the app).
class RealAppleAuthGateway implements AppleAuthGateway {
  @override
  bool get isSupported =>
      defaultTargetPlatform == TargetPlatform.iOS ||
      defaultTargetPlatform == TargetPlatform.macOS;

  @override
  Future<AppleCredential?> obtainCredential() async {
    if (!await SignInWithApple.isAvailable()) {
      throw const AppleAuthException(
        'Sign in with Apple is unavailable on this device.',
        isConfiguration: true,
      );
    }
    try {
      final c = await SignInWithApple.getAppleIDCredential(
        scopes: const [
          AppleIDAuthorizationScopes.email,
          AppleIDAuthorizationScopes.fullName,
        ],
      );
      final token = c.identityToken;
      if (token == null || token.isEmpty) {
        throw const AppleAuthException(
          'Apple did not return an identity token.',
          isConfiguration: true,
        );
      }
      return AppleCredential(
        identityToken: token,
        authorizationCode: c.authorizationCode,
        givenName: c.givenName,
        familyName: c.familyName,
      );
    } on SignInWithAppleAuthorizationException catch (e) {
      if (e.code == AuthorizationErrorCode.canceled) return null;
      throw AppleAuthException(e.message);
    }
  }
}
