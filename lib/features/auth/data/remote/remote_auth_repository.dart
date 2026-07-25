import '../../../v2/data/remote/v2_api_client.dart';
import '../../../v2/domain/errors/v2_error.dart';
import '../../domain/entities/account.dart';
import '../../domain/entities/sign_in_result.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_mappers.dart';

/// Live [AuthRepository] over the V2 REST client (contract §3).
class RemoteAuthRepository implements AuthRepository {
  RemoteAuthRepository(this._api);

  final V2ApiClient _api;

  @override
  Future<SignInResult> signInWithGoogle({
    required String idToken,
    String? installationId,
    String? deviceLabel,
  }) async {
    final res = await _api.post(
      '/auth/google',
      body: {
        'id_token': idToken,
        'installation_id': ?installationId,
        'device_label': ?deviceLabel,
      },
    );
    return AuthMappers.signIn(res);
  }

  @override
  Future<SignInResult> signInWithApple({
    required String identityToken,
    String? authorizationCode,
    String? givenName,
    String? familyName,
    String? installationId,
    String? deviceLabel,
  }) async {
    final res = await _api.post(
      '/auth/apple',
      body: {
        'identity_token': identityToken,
        'authorization_code': ?authorizationCode,
        'given_name': ?givenName,
        'family_name': ?familyName,
        'installation_id': ?installationId,
        'device_label': ?deviceLabel,
      },
    );
    return AuthMappers.signIn(res);
  }

  @override
  Future<Account?> currentSession() async {
    try {
      final res = await _api.get('/auth/session');
      if (res['authenticated'] != true || res['account'] is! Map) return null;
      return AuthMappers.account(
        (res['account'] as Map).cast<String, dynamic>(),
      );
    } on V2Exception catch (e) {
      if (e.isAuthFailure) return null; // 401 → guest
      rethrow;
    }
  }

  @override
  Future<Account> updateAccount({String? displayName, String? avatarUrl}) async {
    final res = await _api.patch(
      '/account/me',
      body: {'display_name': ?displayName, 'avatar_url': ?avatarUrl},
    );
    return AuthMappers.account(res);
  }

  @override
  Future<void> logout() => _api.post('/auth/logout');

  @override
  Future<void> migrateGuest({required String installationId}) => _api.post(
    '/auth/migrate-guest',
    body: {'installation_id': installationId},
  );
}
