import 'account.dart';

/// Result of a successful sign-in (contract §3.1). Carries the opaque
/// `session_token` to persist, the [account], and Google-derived name/avatar
/// suggestions for first-run profile setup.
class SignInResult {
  const SignInResult({
    required this.sessionToken,
    required this.account,
    this.created = false,
    this.suggestedDisplayName,
    this.suggestedAvatarUrl,
  });

  final String sessionToken;
  final Account account;

  /// True when this sign-in just created the account (vs. recovered it).
  final bool created;
  final String? suggestedDisplayName;
  final String? suggestedAvatarUrl;
}
