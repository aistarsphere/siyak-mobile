import 'package:flutter/foundation.dart';
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
      if (kDebugMode) {
        debugPrint('[Auth] stored session invalid → guest (token cleared)');
      }
      return const SessionState();
    }
    if (kDebugMode) {
      debugPrint(
        '[Auth] session restored from cold start: player=${account.publicPlayerId} '
        'providers=${account.linkedProviders}',
      );
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
        if (kDebugMode) debugPrint('[Auth] Google sign-in cancelled by user');
        state = AsyncData(prev.copyWith(signingIn: false));
        return false; // cancelled
      }
      if (kDebugMode) {
        debugPrint('[Auth] Google ID token obtained (redacted); '
            'submitting to backend /v2/auth/google');
      }
      final installationId = await ref
          .read(installationIdStoreProvider)
          .getOrCreate();
      final result = await _auth.signInWithGoogle(
        idToken: idToken,
        installationId: installationId,
      );
      await _sessions.save(result.sessionToken);
      if (kDebugMode) {
        debugPrint(
          '[Auth] Google sign-in OK: player=${result.account.publicPlayerId} '
          'created=${result.created} providers=${result.account.linkedProviders} '
          '(session token stored securely, redacted)',
        );
      }
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
      if (kDebugMode) debugPrint('[Auth] Google sign-in FAILED: ${e.runtimeType}');
      state = AsyncError(e, st);
      // Keep a usable (guest) state so the UI can recover.
      state = AsyncData(prev.copyWith(signingIn: false));
      rethrow;
    }
  }

  /// Edit the signed-in account's public profile (`PATCH /account/me`). No-op
  /// when guest. Clears [SessionState.justCreated] once applied.
  Future<void> updateAccountProfile({
    String? displayName,
    String? avatarUrl,
  }) async {
    final prev = state.asData?.value;
    if (prev == null || prev.account == null) return;
    final updated = await _auth.updateAccount(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    state = AsyncData(prev.copyWith(account: updated, justCreated: false));
    // Account display name feeds bearer-scoped profile views.
    ref.invalidate(profileControllerProvider);
    if (kDebugMode) {
      debugPrint(
        '[Auth] account profile updated: player=${updated.publicPlayerId}',
      );
    }
  }

  /// Acknowledge the one-shot first-run flag without editing anything (the user
  /// skipped the welcome setup), so the setup sheet is not offered again.
  void consumeJustCreated() {
    final prev = state.asData?.value;
    if (prev == null || !prev.justCreated) return;
    state = AsyncData(prev.copyWith(justCreated: false));
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
    if (kDebugMode) debugPrint('[Auth] logged out → guest (session cleared)');
    state = const AsyncData(SessionState());
  }
}

final sessionControllerProvider =
    AsyncNotifierProvider<SessionController, SessionState>(
      SessionController.new,
    );
