import 'dart:async';

import 'package:context_game/core/firebase/firebase_bootstrap.dart';
import 'package:context_game/core/notifications/notification_runtime.dart';
import 'package:context_game/core/notifications/push_notifications.dart';
import 'package:context_game/features/game/presentation/controllers/app_settings_controller.dart';
import 'package:context_game/features/v2/data/installation_id_store.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MemStorage implements FlutterSecureStorage {
  final _store = <String, String>{};

  @override
  Future<String?> read({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => _store[key];

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
  }) async => value == null ? _store.remove(key) : _store[key] = value;

  @override
  Future<void> delete({
    required String key,
    iOptions,
    aOptions,
    lOptions,
    webOptions,
    mOptions,
    wOptions,
  }) async => _store.remove(key);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _FakePlatformGateway implements NotificationPlatformGateway {
  int initializeCalls = 0;
  int requestPermissionCalls = 0;
  int openSettingsCalls = 0;
  int topicCalls = 0;
  final tokenRefresh = StreamController<String>.broadcast();

  NotificationPermissionStatus permission =
      NotificationPermissionStatus.notDetermined;
  NotificationPermissionStatus requestResult =
      NotificationPermissionStatus.authorized;
  final tokenStates = <NotificationPlatformTokenState>[];

  void enqueueTokenStates(List<NotificationPlatformTokenState> states) {
    tokenStates
      ..clear()
      ..addAll(states);
  }

  @override
  Stream<String> get onTokenRefresh => tokenRefresh.stream;

  @override
  Future<PushTopicApplyResult> applyTopicIntent({
    required String topic,
    required bool enabled,
  }) async {
    topicCalls++;
    return PushTopicApplyResult(
      topic: topic,
      enabled: enabled,
      status: PushTopicApplyStatus.performed,
    );
  }

  @override
  Future<bool> canRequestPermissionAgain() async => true;

  @override
  Future<void> initialize(NotificationRouter router) async {
    initializeCalls++;
  }

  @override
  Future<bool> openSystemSettings() async {
    openSettingsCalls++;
    return true;
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async => permission;

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    requestPermissionCalls++;
    permission = requestResult;
    return requestResult;
  }

  @override
  Future<NotificationPlatformTokenState> tokenState() async {
    if (tokenStates.isEmpty) {
      return const NotificationPlatformTokenState(
        status: NotificationPlatformTokenStatus.waitingForPlatformToken,
      );
    }
    if (tokenStates.length == 1) return tokenStates.single;
    return tokenStates.removeAt(0);
  }
}

class _FakeBackendRepository implements NotificationBackendRepository {
  int registerInstallationCalls = 0;
  int registerPushCalls = 0;
  int attachCalls = 0;
  int detachCalls = 0;

  @override
  NotificationBackendCapabilities get capabilities =>
      const NotificationBackendCapabilities();

  @override
  Future<void> attachInstallation(String installationId) async {
    attachCalls++;
  }

  @override
  Future<void> detachInstallation(String installationId) async {
    detachCalls++;
  }

  @override
  Future<void> registerInstallation({
    required String installationId,
    required String platform,
    required String locale,
    required String timezone,
    required NotificationPermissionStatus permissionStatus,
  }) async {
    registerInstallationCalls++;
  }

  @override
  Future<void> registerPushToken({
    required String installationId,
    required String platform,
    required String token,
    required String locale,
    required String timezone,
    required NotificationPermissionStatus permissionStatus,
  }) async {
    registerPushCalls++;
  }
}

Future<ProviderContainer> _container({
  required _FakePlatformGateway platform,
  required _FakeBackendRepository backend,
  Map<String, Object>? prefs,
}) async {
  SharedPreferences.setMockInitialValues(prefs ?? const {});
  final sharedPrefs = await SharedPreferences.getInstance();
  return ProviderContainer(
    overrides: [
      sharedPreferencesProvider.overrideWithValue(sharedPrefs),
      firebaseBootstrapResultProvider.overrideWithValue(
        FirebaseAvailable(_FakeFirebaseApp()),
      ),
      installationIdStoreProvider.overrideWithValue(
        InstallationIdStore(storage: _MemStorage()),
      ),
      notificationPlatformGatewayProvider.overrideWithValue(platform),
      notificationBackendRepositoryProvider.overrideWithValue(backend),
    ],
  );
}

class _FakeFirebaseApp implements FirebaseApp {
  @override
  String get name => 'fake';

  @override
  FirebaseOptions get options => const FirebaseOptions(
    apiKey: 'key',
    appId: 'app',
    messagingSenderId: 'sender',
    projectId: 'project',
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  tearDown(() {
    debugDefaultTargetPlatformOverride = null;
  });

  test('only one NotificationRuntime instance is created', () async {
    final container = await _container(
      platform: _FakePlatformGateway(),
      backend: _FakeBackendRepository(),
    );
    addTearDown(container.dispose);

    final first = container.read(notificationRuntimeProvider.notifier);
    final second = container.read(notificationRuntimeProvider.notifier);
    expect(identical(first, second), isTrue);
  });

  test('initialize runs platform initialization once', () async {
    final platform = _FakePlatformGateway()
      ..permission = NotificationPermissionStatus.authorized
      ..enqueueTokenStates([
        const NotificationPlatformTokenState(
          status: NotificationPlatformTokenStatus.ready,
          fcmToken: 'token-1',
        ),
      ]);
    final backend = _FakeBackendRepository();
    final container = await _container(platform: platform, backend: backend);
    addTearDown(container.dispose);

    final runtime = container.read(notificationRuntimeProvider.notifier);
    await runtime.initialize();
    await runtime.initialize();

    expect(platform.initializeCalls, 1);
    expect(backend.registerPushCalls, 0);
  });

  test(
    'first install requests permission once and does not prompt again',
    () async {
      final platform = _FakePlatformGateway()
        ..permission = NotificationPermissionStatus.notDetermined
        ..requestResult = NotificationPermissionStatus.authorized
        ..enqueueTokenStates([
          const NotificationPlatformTokenState(
            status: NotificationPlatformTokenStatus.ready,
            fcmToken: 'token-2',
          ),
        ]);
      final backend = _FakeBackendRepository();
      final container = await _container(platform: platform, backend: backend);
      addTearDown(container.dispose);

      final runtime = container.read(notificationRuntimeProvider.notifier);
      await runtime.maybeRunFirstPermissionFlow();
      await runtime.maybeRunFirstPermissionFlow();

      expect(platform.requestPermissionCalls, 1);
    },
  );

  test('iOS denied opens settings instead of prompting again', () async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final platform = _FakePlatformGateway()
      ..permission = NotificationPermissionStatus.denied;
    final backend = _FakeBackendRepository();
    final container = await _container(platform: platform, backend: backend);
    addTearDown(container.dispose);

    final runtime = container.read(notificationRuntimeProvider.notifier);
    final permission = await runtime.setNotificationsEnabled(true);

    expect(permission, NotificationPermissionStatus.denied);
    expect(platform.requestPermissionCalls, 0);
    expect(platform.openSettingsCalls, 1);
  });

  test(
    'APNs delay moves to waitingForPlatformToken then token refresh completes sync',
    () async {
      final platform = _FakePlatformGateway()
        ..permission = NotificationPermissionStatus.authorized
        ..enqueueTokenStates([
          const NotificationPlatformTokenState(
            status: NotificationPlatformTokenStatus.waitingForPlatformToken,
          ),
        ]);
      final backend = _FakeBackendRepository();
      final container = await _container(
        platform: platform,
        backend: backend,
        prefs: const {'siyaq.notifications.userEnabled': true},
      );
      addTearDown(container.dispose);

      final runtime = container.read(notificationRuntimeProvider.notifier);
      await runtime.initialize();
      expect(
        container.read(notificationRuntimeProvider).runtimeStatus,
        NotificationRuntimeStatus.waitingForPlatformToken,
      );

      platform.enqueueTokenStates([
        const NotificationPlatformTokenState(
          status: NotificationPlatformTokenStatus.ready,
          fcmToken: 'token-3',
        ),
      ]);
      platform.tokenRefresh.add('token-3');
      await pumpEventQueue();

      final state = container.read(notificationRuntimeProvider);
      expect(state.runtimeStatus, NotificationRuntimeStatus.ready);
      expect(backend.registerPushCalls, 1);
    },
  );

  test(
    'unchanged token refresh does not create duplicate registration',
    () async {
      final platform = _FakePlatformGateway()
        ..permission = NotificationPermissionStatus.authorized
        ..enqueueTokenStates([
          const NotificationPlatformTokenState(
            status: NotificationPlatformTokenStatus.ready,
            fcmToken: 'token-4',
          ),
        ]);
      final backend = _FakeBackendRepository();
      final container = await _container(
        platform: platform,
        backend: backend,
        prefs: const {'siyaq.notifications.userEnabled': true},
      );
      addTearDown(container.dispose);

      final runtime = container.read(notificationRuntimeProvider.notifier);
      await runtime.initialize();
      platform.tokenRefresh.add('token-4');
      await pumpEventQueue();

      expect(backend.registerPushCalls, 1);
    },
  );

  test('logout detaches account but keeps token registration state', () async {
    final platform = _FakePlatformGateway()
      ..permission = NotificationPermissionStatus.authorized
      ..enqueueTokenStates([
        const NotificationPlatformTokenState(
          status: NotificationPlatformTokenStatus.ready,
          fcmToken: 'token-5',
        ),
      ]);
    final backend = _FakeBackendRepository();
    final container = await _container(
      platform: platform,
      backend: backend,
      prefs: const {'siyaq.notifications.userEnabled': true},
    );
    addTearDown(container.dispose);

    final runtime = container.read(notificationRuntimeProvider.notifier);
    await runtime.initialize();
    await runtime.onSessionAuthenticated('SYG-1');
    await runtime.onSessionBecameGuest();

    final state = container.read(notificationRuntimeProvider);
    expect(backend.attachCalls, 1);
    expect(backend.detachCalls, 1);
    expect(state.lastTokenFingerprint, isNotNull);
  });

  test(
    'disabling notifications does not invalidate token registration',
    () async {
      final platform = _FakePlatformGateway()
        ..permission = NotificationPermissionStatus.authorized
        ..enqueueTokenStates([
          const NotificationPlatformTokenState(
            status: NotificationPlatformTokenStatus.ready,
            fcmToken: 'token-6',
          ),
        ]);
      final backend = _FakeBackendRepository();
      final container = await _container(
        platform: platform,
        backend: backend,
        prefs: const {'siyaq.notifications.userEnabled': true},
      );
      addTearDown(container.dispose);

      final runtime = container.read(notificationRuntimeProvider.notifier);
      await runtime.initialize();
      await runtime.setNotificationsEnabled(false);

      expect(
        container.read(notificationRuntimeProvider).runtimeStatus,
        NotificationRuntimeStatus.disabledByUser,
      );
      expect(backend.registerPushCalls, 1);
    },
  );
}
