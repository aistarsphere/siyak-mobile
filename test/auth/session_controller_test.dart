import 'package:context_game/core/notifications/notification_runtime.dart';
import 'package:context_game/core/notifications/push_notifications.dart';
import 'package:context_game/features/auth/domain/entities/account.dart';
import 'package:context_game/features/auth/domain/entities/sign_in_result.dart';
import 'package:context_game/features/auth/domain/repositories/auth_repository.dart';
import 'package:context_game/features/auth/presentation/controllers/auth_providers.dart';
import 'package:context_game/features/auth/presentation/controllers/session_controller.dart';
import 'package:context_game/features/v2/data/installation_id_store.dart';
import 'package:context_game/features/v2/data/session_store.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';

class _Mem implements FlutterSecureStorage {
  final _m = <String, String>{};
  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => _m[key];
  @override
  Future<void> write({
    required String key,
    required String? value,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => value == null ? _m.remove(key) : _m[key] = value;
  @override
  Future<void> delete({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => _m.remove(key);
  @override
  dynamic noSuchMethod(Invocation i) => throw UnimplementedError();
}

class _FakeAuth implements AuthRepository {
  Account? sessionAccount;
  SignInResult? signInResult;
  String? lastInstallation;
  int logoutCalls = 0;

  @override
  Future<SignInResult> signInWithGoogle({
    required String idToken,
    String? installationId,
    String? deviceLabel,
  }) async {
    lastInstallation = installationId;
    return signInResult!;
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
    lastInstallation = installationId;
    return signInResult!;
  }

  @override
  Future<Account?> currentSession() async => sessionAccount;

  String? lastUpdatedName;
  String? lastUpdatedAvatar;
  @override
  Future<Account> updateAccount({
    String? displayName,
    String? avatarUrl,
  }) async {
    lastUpdatedName = displayName;
    lastUpdatedAvatar = avatarUrl;
    final base = sessionAccount ?? signInResult?.account ?? _account;
    final updated = base.copyWith(
      displayName: displayName,
      avatarUrl: avatarUrl,
    );
    sessionAccount = updated;
    return updated;
  }

  @override
  Future<void> logout() async => logoutCalls++;
  @override
  Future<void> migrateGuest({required String installationId}) async {}
}

class _FakeGoogle implements GoogleAuthGateway {
  _FakeGoogle(this.idToken);
  String? idToken; // null → user cancelled
  int signOutCalls = 0;
  @override
  Future<String?> obtainIdToken() async => idToken;
  @override
  Future<void> signOut() async => signOutCalls++;
  @override
  bool get isSupported => true;
}

class _FakeApple implements AppleAuthGateway {
  _FakeApple(this.credential);
  AppleCredential? credential; // null → user cancelled
  @override
  Future<AppleCredential?> obtainCredential() async => credential;
  @override
  bool get isSupported => true;
}

class _FakeNotificationRuntime implements NotificationRuntimeCoordinator {
  @override
  NotificationRuntimeState get currentState => const NotificationRuntimeState();

  @override
  Future<String?> currentTokenForDebug() async => null;

  @override
  Future<void> initialize() async {}

  @override
  Future<void> maybeRunFirstPermissionFlow() async {}

  @override
  Future<void> openSettings() async {}

  @override
  Future<void> onSessionAuthenticated(String accountId) async {}

  @override
  Future<void> onSessionBecameGuest() async {}

  @override
  Future<NotificationPermissionStatus?> setNotificationsEnabled(
    bool value,
  ) async => null;
}

const _account = Account(publicPlayerId: 'SYG-TEST1', displayName: 'سالم');

ProviderContainer _container({
  required SessionStore session,
  required _FakeAuth auth,
  required _FakeGoogle google,
  _FakeApple? apple,
}) => ProviderContainer(
  overrides: [
    sessionStoreProvider.overrideWithValue(session),
    installationIdStoreProvider.overrideWithValue(
      InstallationIdStore(storage: _Mem()),
    ),
    authRepositoryProvider.overrideWithValue(auth),
    googleAuthGatewayProvider.overrideWithValue(google),
    appleAuthGatewayProvider.overrideWithValue(apple ?? _FakeApple(null)),
    notificationRuntimeActionsProvider.overrideWithValue(
      _FakeNotificationRuntime(),
    ),
  ],
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('cold start with no token → guest', () async {
    final c = _container(
      session: SessionStore(storage: _Mem()),
      auth: _FakeAuth(),
      google: _FakeGoogle(null),
    );
    addTearDown(c.dispose);
    final s = await c.read(sessionControllerProvider.future);
    expect(s.isSignedIn, isFalse);
  });

  test('cold start with a valid token → restores account', () async {
    final store = SessionStore(storage: _Mem());
    await store.save('sess_good');
    final auth = _FakeAuth()..sessionAccount = _account;
    final c = _container(session: store, auth: auth, google: _FakeGoogle(null));
    addTearDown(c.dispose);
    final s = await c.read(sessionControllerProvider.future);
    expect(s.isSignedIn, isTrue);
    expect(s.account!.publicPlayerId, 'SYG-TEST1');
  });

  test(
    'cold start with a rejected token → clears and falls back to guest',
    () async {
      final store = SessionStore(storage: _Mem());
      await store.save('sess_stale');
      final auth = _FakeAuth()..sessionAccount = null; // 401 → null
      final c = _container(
        session: store,
        auth: auth,
        google: _FakeGoogle(null),
      );
      addTearDown(c.dispose);
      final s = await c.read(sessionControllerProvider.future);
      expect(s.isSignedIn, isFalse);
      expect(store.cachedToken, isNull, reason: 'stale token dropped');
    },
  );

  test(
    'Google sign-in saves the session and migrates the guest installation',
    () async {
      final store = SessionStore(storage: _Mem());
      final auth = _FakeAuth()
        ..signInResult = const SignInResult(
          sessionToken: 'sess_new',
          account: _account,
          created: true,
          suggestedDisplayName: 'سالم',
        );
      final c = _container(
        session: store,
        auth: auth,
        google: _FakeGoogle('google-id-token'),
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
      final ok = await c
          .read(sessionControllerProvider.notifier)
          .signInWithGoogle();
      expect(ok, isTrue);
      final s = c.read(sessionControllerProvider).value!;
      expect(s.isSignedIn, isTrue);
      expect(s.justCreated, isTrue);
      expect(store.cachedToken, 'sess_new');
      expect(
        auth.lastInstallation,
        isNotNull,
        reason: 'guest installation passed for one-shot migration',
      );
    },
  );

  test(
    'Apple sign-in saves the session and migrates the installation',
    () async {
      final store = SessionStore(storage: _Mem());
      final auth = _FakeAuth()
        ..signInResult = const SignInResult(
          sessionToken: 'sess_apple',
          account: Account(
            publicPlayerId: 'SYG-APPLE',
            displayName: 'سالم',
            linkedProviders: ['apple'],
          ),
        );
      final c = _container(
        session: store,
        auth: auth,
        google: _FakeGoogle(null),
        apple: _FakeApple(
          const AppleCredential(
            identityToken: 'apple-idtoken',
            givenName: 'سالم',
          ),
        ),
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
      final ok = await c
          .read(sessionControllerProvider.notifier)
          .signInWithApple();
      expect(ok, isTrue);
      final s = c.read(sessionControllerProvider).value!;
      expect(s.account!.publicPlayerId, 'SYG-APPLE');
      expect(s.account!.linkedProviders, contains('apple'));
      expect(store.cachedToken, 'sess_apple');
      expect(auth.lastInstallation, isNotNull);
    },
  );

  test('cancelled Apple sign-in keeps the guest state', () async {
    final store = SessionStore(storage: _Mem());
    final c = _container(
      session: store,
      auth: _FakeAuth(),
      google: _FakeGoogle(null),
      apple: _FakeApple(null),
    );
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    final ok = await c
        .read(sessionControllerProvider.notifier)
        .signInWithApple();
    expect(ok, isFalse);
    expect(c.read(sessionControllerProvider).value!.isSignedIn, isFalse);
  });

  test('cancelled Google sign-in keeps the guest state', () async {
    final store = SessionStore(storage: _Mem());
    final c = _container(
      session: store,
      auth: _FakeAuth(),
      google: _FakeGoogle(null),
    );
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    final ok = await c
        .read(sessionControllerProvider.notifier)
        .signInWithGoogle();
    expect(ok, isFalse);
    expect(c.read(sessionControllerProvider).value!.isSignedIn, isFalse);
  });

  test('logout revokes the session and returns to guest', () async {
    final store = SessionStore(storage: _Mem());
    await store.save('sess_live');
    final auth = _FakeAuth()..sessionAccount = _account;
    final google = _FakeGoogle(null);
    final c = _container(session: store, auth: auth, google: google);
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).logout();
    expect(c.read(sessionControllerProvider).value!.isSignedIn, isFalse);
    expect(store.cachedToken, isNull);
    expect(auth.logoutCalls, 1);
    expect(google.signOutCalls, 1);
  });

  test(
    'updateAccountProfile edits the account and clears justCreated',
    () async {
      final store = SessionStore(storage: _Mem());
      final auth = _FakeAuth()
        ..signInResult = const SignInResult(
          sessionToken: 'sess_new',
          account: _account,
          created: true,
          suggestedDisplayName: 'سالم',
        );
      final c = _container(
        session: store,
        auth: auth,
        google: _FakeGoogle('google-id-token'),
      );
      addTearDown(c.dispose);
      await c.read(sessionControllerProvider.future);
      await c.read(sessionControllerProvider.notifier).signInWithGoogle();
      expect(c.read(sessionControllerProvider).value!.justCreated, isTrue);

      await c
          .read(sessionControllerProvider.notifier)
          .updateAccountProfile(
            displayName: 'اسم جديد',
            avatarUrl: 'https://example.com/a.png',
          );

      final s = c.read(sessionControllerProvider).value!;
      expect(auth.lastUpdatedName, 'اسم جديد');
      expect(auth.lastUpdatedAvatar, 'https://example.com/a.png');
      expect(s.account!.displayName, 'اسم جديد');
      expect(s.account!.avatarUrl, 'https://example.com/a.png');
      expect(
        s.justCreated,
        isFalse,
        reason: 'first-run flag cleared after edit',
      );
    },
  );

  test('consumeJustCreated clears the flag without editing', () async {
    final store = SessionStore(storage: _Mem());
    final auth = _FakeAuth()
      ..signInResult = const SignInResult(
        sessionToken: 'sess_new',
        account: _account,
        created: true,
        suggestedDisplayName: 'سالم',
      );
    final c = _container(
      session: store,
      auth: auth,
      google: _FakeGoogle('google-id-token'),
    );
    addTearDown(c.dispose);
    await c.read(sessionControllerProvider.future);
    await c.read(sessionControllerProvider.notifier).signInWithGoogle();
    c.read(sessionControllerProvider.notifier).consumeJustCreated();
    final s = c.read(sessionControllerProvider).value!;
    expect(s.justCreated, isFalse);
    expect(auth.lastUpdatedName, isNull, reason: 'skip performs no edit');
    expect(s.isSignedIn, isTrue);
  });
}
