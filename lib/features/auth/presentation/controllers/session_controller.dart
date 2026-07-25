import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../v2/data/session_store.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';
import '../../../v2/presentation/controllers/v2_providers.dart';
import '../../domain/entities/account.dart';
import '../../domain/repositories/auth_repository.dart';
import 'auth_providers.dart';

/// Signed-in state. `account == null` means the user is a **guest** (still fully
/// playable via `X-Installation-ID`).
class SessionState {
  const SessionState({
    this.account,
    this.signingIn = false,
    this.suggestedDisplayName,
    this.suggestedAvatarUrl,
    this.justCreated = false,
  });

  final Account? account;
  final bool signingIn;

  /// Google-derived suggestions surfaced to the first-run profile setup screen.
  final String? suggestedDisplayName;
  final String? suggestedAvatarUrl;

  /// True immediately after a sign-in that created a brand-new account.
  final bool justCreated;

  bool get isSignedIn => account != null;

  SessionState copyWith({
    Account? account,
    bool clearAccount = false,
    bool? signingIn,
    String? suggestedDisplayName,
    String? suggestedAvatarUrl,
    bool? justCreated,
  }) => SessionState(
    account: clearAccount ? null : (account ?? this.account),
    signingIn: signingIn ?? this.signingIn,
    suggestedDisplayName: suggestedDisplayName ?? this.suggestedDisplayName,
    suggestedAvatarUrl: suggestedAvatarUrl ?? this.suggestedAvatarUrl,
    justCreated: justCreated ?? this.justCreated,
  );
}

/// Owns account session lifecycle: cold-start restore, Google sign-in (with
/// one-shot guest migration), and logout. Re-evaluates to guest whenever the
/// server rejects the session (via [sessionRevokedProvider]).
class SessionController extends AsyncNotifier<SessionState> {
  AuthRepository get _auth => ref.read(authRepositoryProvider);
  GoogleAuthGateway get _google => ref.read(googleAuthGatewayProvider);
  SessionStore get _sessions => ref.read(sessionStoreProvider);

  @override
  Future<SessionState> build() async {
    // Any 401 rejection bumps this → rebuild restores guest without a network hit.
    ref.watch(sessionRevokedProvider);
    final token = await _sessions.load();
    if (token == null || token.isEmpty) return const SessionState();
    final account = await _auth.currentSession();
    if (account == null) {
      await _sessions.clear();
      return const SessionState();
    }
    return SessionState(account: account);
  }

  /// Interactive Google sign-in. Migrates the current guest installation into
  /// the account in one shot. No-op if the user cancels.
  Future<bool> signInWithGoogle() async {
    final prev = state.asData?.value ?? const SessionState();
    state = AsyncData(prev.copyWith(signingIn: true));
    try {
      final idToken = await _google.obtainIdToken();
      if (idToken == null) {
        state = AsyncData(prev.copyWith(signingIn: false));
        return false; // cancelled
      }
      final installationId = await ref
          .read(installationIdStoreProvider)
          .getOrCreate();
      final result = await _auth.signInWithGoogle(
        idToken: idToken,
        installationId: installationId,
      );
      await _sessions.save(result.sessionToken);
      state = AsyncData(
        SessionState(
          account: result.account,
          suggestedDisplayName: result.suggestedDisplayName,
          suggestedAvatarUrl: result.suggestedAvatarUrl,
          justCreated: result.created,
        ),
      );
      // Account's current_profile is now bearer-scoped — refresh dependent state.
      ref.invalidate(profileControllerProvider);
      return true;
    } catch (e, st) {
      state = AsyncError(e, st);
      // Keep a usable (guest) state so the UI can recover.
      state = AsyncData(prev.copyWith(signingIn: false));
      rethrow;
    }
  }

  /// Sign out: revoke server session, drop the local Google session + token.
  Future<void> logout() async {
    try {
      await _auth.logout();
    } catch (_) {
      // Even if the server call fails, drop local credentials.
    }
    try {
      await _google.signOut();
    } catch (_) {}
    await _sessions.clear();
    ref.invalidate(profileControllerProvider);
    state = const AsyncData(SessionState());
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );
