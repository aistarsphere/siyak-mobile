import '../../domain/entities/account.dart';
import '../../domain/entities/sign_in_result.dart';

/// JSON → domain translation for the auth endpoints (contract §3). Envelope
/// fields (`request_id`, …) are ignored.
class AuthMappers {
  AuthMappers._();

  static Account account(Map<String, dynamic> j) => Account(
    publicPlayerId: (j['public_player_id'] ?? '').toString(),
    displayName: j['display_name'] as String?,
    avatarUrl: j['avatar_url'] as String?,
    status: (j['status'] ?? 'active').toString(),
    linkedProviders: (j['linked_providers'] as List?)
            ?.map((e) => e.toString())
            .toList() ??
        const [],
    createdAt: _date(j['created_at']),
    lastActiveAt: _date(j['last_active_at']),
  );

  static SignInResult signIn(Map<String, dynamic> j) => SignInResult(
    sessionToken: (j['session_token'] ?? '').toString(),
    account: account((j['account'] as Map).cast<String, dynamic>()),
    created: j['created'] == true,
    suggestedDisplayName: j['suggested_display_name'] as String?,
    suggestedAvatarUrl: j['suggested_avatar_url'] as String?,
  );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;
}
