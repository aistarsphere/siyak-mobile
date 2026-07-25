import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/auth/data/remote/remote_installation_repository.dart';
import '../../features/auth/domain/repositories/installation_repository.dart';
import '../../features/game/presentation/controllers/app_settings_controller.dart';
import '../../features/v2/data/installation_id_store.dart';
import '../../features/v2/presentation/controllers/v2_providers.dart';
import '../config/app_config.dart';
import '../firebase/firebase_bootstrap.dart';
import 'push_notifications.dart';

enum NotificationRuntimeStatus {
  unavailable,
  disabledByUser,
  permissionNotDetermined,
  requestingPermission,
  blockedBySystem,
  waitingForPlatformToken,
  registeringWithBackend,
  synchronizing,
  ready,
  recoverableError,
  configurationError,
}

class NotificationRuntimeFailure {
  const NotificationRuntimeFailure({
    required this.code,
    required this.exceptionType,
  });

  final String code;
  final String exceptionType;
}

class NotificationRuntimeState {
  const NotificationRuntimeState({
    this.userEnabled = false,
    this.permissionStatus = NotificationPermissionStatus.notDetermined,
    this.runtimeStatus = NotificationRuntimeStatus.permissionNotDetermined,
    this.installationId,
    this.backendRegistered = false,
    this.lastTokenFingerprint,
    this.lastSuccessfulSyncAt,
    this.recoverableFailure,
  });

  final bool userEnabled;
  final NotificationPermissionStatus permissionStatus;
  final NotificationRuntimeStatus runtimeStatus;
  final String? installationId;
  final bool backendRegistered;
  final String? lastTokenFingerprint;
  final DateTime? lastSuccessfulSyncAt;
  final NotificationRuntimeFailure? recoverableFailure;

  bool get enabled => userEnabled;
  NotificationRuntimeStatus get readiness => runtimeStatus;
  bool get blockedBySystem =>
      runtimeStatus == NotificationRuntimeStatus.blockedBySystem;
  bool get busy =>
      runtimeStatus == NotificationRuntimeStatus.requestingPermission ||
      runtimeStatus == NotificationRuntimeStatus.registeringWithBackend ||
      runtimeStatus == NotificationRuntimeStatus.synchronizing;

  NotificationRuntimeState copyWith({
    bool? userEnabled,
    NotificationPermissionStatus? permissionStatus,
    NotificationRuntimeStatus? runtimeStatus,
    String? installationId,
    bool? backendRegistered,
    String? lastTokenFingerprint,
    DateTime? lastSuccessfulSyncAt,
    NotificationRuntimeFailure? recoverableFailure,
    bool clearRecoverableFailure = false,
    bool clearTokenFingerprint = false,
  }) => NotificationRuntimeState(
    userEnabled: userEnabled ?? this.userEnabled,
    permissionStatus: permissionStatus ?? this.permissionStatus,
    runtimeStatus: runtimeStatus ?? this.runtimeStatus,
    installationId: installationId ?? this.installationId,
    backendRegistered: backendRegistered ?? this.backendRegistered,
    lastTokenFingerprint: clearTokenFingerprint
        ? null
        : (lastTokenFingerprint ?? this.lastTokenFingerprint),
    lastSuccessfulSyncAt: lastSuccessfulSyncAt ?? this.lastSuccessfulSyncAt,
    recoverableFailure: clearRecoverableFailure
        ? null
        : (recoverableFailure ?? this.recoverableFailure),
  );
}

abstract class NotificationRuntimeCoordinator {
  NotificationRuntimeState get currentState;

  Future<void> initialize();
  Future<void> maybeRunFirstPermissionFlow();
  Future<NotificationPermissionStatus?> setNotificationsEnabled(bool value);
  Future<String?> currentTokenForDebug();
  Future<void> openSettings();
  Future<void> onSessionAuthenticated(String accountId);
  Future<void> onSessionBecameGuest();
}

class NotificationBackendCapabilities {
  const NotificationBackendCapabilities({
    this.supportsNotificationSettings = false,
    this.supportsTopicIntents = false,
  });

  final bool supportsNotificationSettings;
  final bool supportsTopicIntents;
}

abstract class NotificationBackendRepository {
  NotificationBackendCapabilities get capabilities;

  Future<void> registerInstallation({
    required String installationId,
    required String platform,
    required String locale,
    required String timezone,
    required NotificationPermissionStatus permissionStatus,
  });

  Future<void> registerPushToken({
    required String installationId,
    required String platform,
    required String token,
    required String locale,
    required String timezone,
    required NotificationPermissionStatus permissionStatus,
  });

  Future<void> attachInstallation(String installationId);
  Future<void> detachInstallation(String installationId);
}

class InstallationNotificationBackendRepository
    implements NotificationBackendRepository {
  InstallationNotificationBackendRepository(this._repo);

  final InstallationRepository _repo;

  @override
  NotificationBackendCapabilities get capabilities =>
      const NotificationBackendCapabilities();

  @override
  Future<void> attachInstallation(String installationId) =>
      _repo.attach(installationId);

  @override
  Future<void> detachInstallation(String installationId) =>
      _repo.detach(installationId);

  @override
  Future<void> registerInstallation({
    required String installationId,
    required String platform,
    required String locale,
    required String timezone,
    required NotificationPermissionStatus permissionStatus,
  }) => _repo.register(
    installationId: installationId,
    platform: platform,
    appVersion: AppConfig.appVersion,
    buildNumber: AppConfig.buildNumber,
    locale: locale,
    timezone: timezone,
    notificationPermission: _permissionName(permissionStatus),
  );

  @override
  Future<void> registerPushToken({
    required String installationId,
    required String platform,
    required String token,
    required String locale,
    required String timezone,
    required NotificationPermissionStatus permissionStatus,
  }) => _repo.registerPushToken(
    installationId: installationId,
    platform: platform,
    token: token,
    appVersion: AppConfig.appVersion,
    buildNumber: AppConfig.buildNumber,
    locale: locale,
    timezone: timezone,
    notificationPermission: _permissionName(permissionStatus),
  );

  static String _permissionName(NotificationPermissionStatus status) =>
      switch (status) {
        NotificationPermissionStatus.authorized => 'authorized',
        NotificationPermissionStatus.provisional => 'provisional',
        NotificationPermissionStatus.denied => 'denied',
        NotificationPermissionStatus.notDetermined => 'not_determined',
      };
}

final installationRepositoryProvider = Provider<InstallationRepository>(
  (ref) => RemoteInstallationRepository(ref.watch(v2ApiClientProvider)),
);

final notificationBackendRepositoryProvider =
    Provider<NotificationBackendRepository>(
      (ref) => InstallationNotificationBackendRepository(
        ref.watch(installationRepositoryProvider),
      ),
    );

final notificationRuntimeActionsProvider =
    Provider<NotificationRuntimeCoordinator>(
      (ref) => ref.read(notificationRuntimeProvider.notifier),
    );

final notificationRuntimeProvider =
    StateNotifierProvider<NotificationRuntime, NotificationRuntimeState>(
      (ref) => NotificationRuntime(
        platform: ref.watch(notificationPlatformGatewayProvider),
        backend: ref.watch(notificationBackendRepositoryProvider),
        prefs: ref.watch(sharedPreferencesProvider),
        installationIdStore: ref.watch(installationIdStoreProvider),
        localeLoader: () => ref.read(appSettingsProvider).lang,
        timezoneLoader: () => DateTime.now().timeZoneName,
        firebaseBootstrap: ref.watch(firebaseBootstrapResultProvider),
      ),
    );

class NotificationRuntime extends StateNotifier<NotificationRuntimeState>
    with WidgetsBindingObserver
    implements NotificationRuntimeCoordinator {
  NotificationRuntime({
    required this._platform,
    required this._backend,
    required SharedPreferences prefs,
    required this._installationIdStore,
    required this._localeLoader,
    required this._timezoneLoader,
    required this._firebaseBootstrap,
  }) :
       _prefs = prefs,
       super(
         NotificationRuntimeState(
           userEnabled: prefs.getBool(_kUserEnabled) ?? false,
           runtimeStatus: (prefs.getBool(_kUserEnabled) ?? false)
               ? NotificationRuntimeStatus.synchronizing
               : NotificationRuntimeStatus.disabledByUser,
         ),
       );

  static const _kUserEnabled = 'siyaq.notifications.userEnabled';
  static const _kPermissionFlowCompleted =
      'siyaq.notifications.permissionFlowCompleted';
  static const _kLastTokenFingerprint =
      'siyaq.notifications.lastTokenFingerprint';
  static const _kCurrentAccountId = 'siyaq.notifications.currentAccountId';
  static const _kLastSyncedAccountId =
      'siyaq.notifications.lastSyncedAccountId';
  static const _kLastMetadataFingerprint =
      'siyaq.notifications.lastMetadataFingerprint';
  static const _kLastSuccessfulSyncAt =
      'siyaq.notifications.lastSuccessfulSyncAt';
  static const _kTopicIntents = 'siyaq.notifications.topicIntents';
  static const _defaultTopics = <String>{'all'};
  static const _permissionDelays = <Duration>[
    Duration.zero,
    Duration(milliseconds: 300),
    Duration(milliseconds: 1200),
  ];

  final NotificationPlatformGateway _platform;
  final NotificationBackendRepository _backend;
  final SharedPreferences _prefs;
  final InstallationIdStore _installationIdStore;
  final String Function() _localeLoader;
  final String Function() _timezoneLoader;
  final FirebaseBootstrapResult _firebaseBootstrap;

  Future<void>? _initializeFuture;
  Future<void>? _syncFuture;
  StreamSubscription<String>? _tokenRefreshSub;
  bool _observersAttached = false;

  @override
  NotificationRuntimeState get currentState => state;

  @override
  Future<void> initialize() {
    return _initializeFuture ??= _initialize();
  }

  Future<void> _initialize() async {
    if (!_observersAttached) {
      WidgetsBinding.instance.addObserver(this);
      _observersAttached = true;
    }
    final installationId = await _installationIdStore.getOrCreate();
    state = state.copyWith(installationId: installationId);

    if (_firebaseBootstrap case FirebaseUnavailable(:final failure)) {
      state = state.copyWith(
        runtimeStatus: _mapFirebaseUnavailable(failure),
        recoverableFailure: NotificationRuntimeFailure(
          code: failure.code.name,
          exceptionType: failure.exceptionType,
        ),
      );
      return;
    }

    await _platform.initialize(const DebugNotificationRouter());
    _tokenRefreshSub ??= _platform.onTokenRefresh.listen(_handleTokenRefresh);

    final permission = await _safePermissionStatus();
    await _registerInstallation(permission);
    final userEnabled = _prefs.getBool(_kUserEnabled) ?? false;
    state = state.copyWith(
      installationId: installationId,
      permissionStatus: permission,
      userEnabled: userEnabled,
      runtimeStatus: _statusFor(
        userEnabled: userEnabled,
        permission: permission,
      ),
      lastTokenFingerprint: _prefs.getString(_kLastTokenFingerprint),
      lastSuccessfulSyncAt: _readSyncTime(),
      backendRegistered: _prefs.getString(_kLastTokenFingerprint) != null,
      clearRecoverableFailure: true,
    );

    if (userEnabled && permission.isGranted) {
      await _synchronize(reason: 'initialize', allowShortDelay: false);
    }
  }

  @override
  Future<void> maybeRunFirstPermissionFlow() async {
    await initialize();
    if (_prefs.getBool(_kPermissionFlowCompleted) ?? false) return;
    final permission = await _safePermissionStatus();
    if (permission.isGranted) {
      await _prefs.setBool(_kPermissionFlowCompleted, true);
      if (state.userEnabled) {
        await _synchronize(reason: 'first_run_granted', allowShortDelay: false);
      }
      return;
    }
    if (permission == NotificationPermissionStatus.denied) {
      await _prefs.setBool(_kPermissionFlowCompleted, true);
      state = state.copyWith(
        permissionStatus: permission,
        runtimeStatus: NotificationRuntimeStatus.blockedBySystem,
      );
      return;
    }
    await setNotificationsEnabled(true, firstRunPrompt: true);
    if (state.runtimeStatus != NotificationRuntimeStatus.recoverableError &&
        state.runtimeStatus != NotificationRuntimeStatus.configurationError &&
        state.runtimeStatus != NotificationRuntimeStatus.unavailable) {
      await _prefs.setBool(_kPermissionFlowCompleted, true);
    }
  }

  @override
  Future<NotificationPermissionStatus?> setNotificationsEnabled(
    bool value, {
    bool firstRunPrompt = false,
  }) async {
    await initialize();
    if (!value) {
      await _prefs.setBool(_kUserEnabled, false);
      await _syncTopics(enabled: false, reason: 'user_disabled');
      state = state.copyWith(
        userEnabled: false,
        runtimeStatus: NotificationRuntimeStatus.disabledByUser,
        clearRecoverableFailure: true,
      );
      return null;
    }

    final currentPermission = await _safePermissionStatus();
    if (currentPermission == NotificationPermissionStatus.denied &&
        !_canPromptAgainOnCurrentPlatform()) {
      await _platform.openSystemSettings();
      state = state.copyWith(
        userEnabled: true,
        permissionStatus: currentPermission,
        runtimeStatus: NotificationRuntimeStatus.blockedBySystem,
      );
      return currentPermission;
    }

    NotificationPermissionStatus permission = currentPermission;
    if (!permission.isGranted) {
      state = state.copyWith(
        userEnabled: true,
        permissionStatus: permission,
        runtimeStatus: NotificationRuntimeStatus.requestingPermission,
        clearRecoverableFailure: true,
      );
      try {
        permission = await _platform.requestPermission();
      } catch (e) {
        state = state.copyWith(
          runtimeStatus: NotificationRuntimeStatus.recoverableError,
          recoverableFailure: NotificationRuntimeFailure(
            code: 'request_permission_failed',
            exceptionType: e.runtimeType.toString(),
          ),
        );
        return currentPermission;
      }
    }

    if (!permission.isGranted) {
      await _prefs.setBool(_kUserEnabled, false);
      state = state.copyWith(
        userEnabled: false,
        permissionStatus: permission,
        runtimeStatus: permission == NotificationPermissionStatus.denied
            ? NotificationRuntimeStatus.blockedBySystem
            : NotificationRuntimeStatus.permissionNotDetermined,
      );
      return permission;
    }

    await _prefs.setBool(_kUserEnabled, true);
    if (!firstRunPrompt) {
      await _prefs.setBool(_kPermissionFlowCompleted, true);
    }
    state = state.copyWith(
      userEnabled: true,
      permissionStatus: permission,
      runtimeStatus: NotificationRuntimeStatus.synchronizing,
      clearRecoverableFailure: true,
    );
    await _synchronize(reason: 'enable', allowShortDelay: true);
    return permission;
  }

  bool _canPromptAgainOnCurrentPlatform() {
    // iOS denied is effectively blocked once the system has answered denied.
    return defaultTargetPlatform != TargetPlatform.iOS;
  }

  @override
  Future<String?> currentTokenForDebug() async {
    await initialize();
    final tokenState = await _platform.tokenState();
    return tokenState.fcmToken;
  }

  @override
  Future<void> openSettings() async {
    await _platform.openSystemSettings();
  }

  @override
  Future<void> onSessionAuthenticated(String accountId) async {
    await initialize();
    final installationId = state.installationId;
    if (installationId == null) return;
    final previous = _prefs.getString(_kCurrentAccountId);
    if (previous == accountId) return;
    try {
      await _backend.attachInstallation(installationId);
      await _prefs.setString(_kCurrentAccountId, accountId);
      await _synchronize(reason: 'account_attach', allowShortDelay: false);
    } catch (e) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.recoverableError,
        recoverableFailure: NotificationRuntimeFailure(
          code: 'attach_failed',
          exceptionType: e.runtimeType.toString(),
        ),
      );
    }
  }

  @override
  Future<void> onSessionBecameGuest() async {
    await initialize();
    final installationId = state.installationId;
    if (installationId == null) return;
    if (_prefs.getString(_kCurrentAccountId) == null) return;
    try {
      await _backend.detachInstallation(installationId);
      await _prefs.remove(_kCurrentAccountId);
      if (state.userEnabled && state.permissionStatus.isGranted) {
        await _synchronize(reason: 'account_detach', allowShortDelay: false);
      }
    } catch (e) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.recoverableError,
        recoverableFailure: NotificationRuntimeFailure(
          code: 'detach_failed',
          exceptionType: e.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> _handleTokenRefresh(String token) async {
    if (redactedTokenFingerprint(token) ==
        _prefs.getString(_kLastTokenFingerprint)) {
      return;
    }
    await _synchronize(reason: 'token_refresh', allowShortDelay: false);
  }

  Future<void> _registerInstallation(
    NotificationPermissionStatus permission,
  ) async {
    final installationId = state.installationId;
    if (installationId == null) return;
    await _backend.registerInstallation(
      installationId: installationId,
      platform: defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android',
      locale: _localeLoader(),
      timezone: _timezoneLoader(),
      permissionStatus: permission,
    );
  }

  Future<void> _synchronize({
    required String reason,
    required bool allowShortDelay,
  }) {
    return _syncFuture ??= _doSynchronize(
      reason: reason,
      allowShortDelay: allowShortDelay,
    ).whenComplete(() => _syncFuture = null);
  }

  Future<void> _doSynchronize({
    required String reason,
    required bool allowShortDelay,
  }) async {
    if (!state.userEnabled) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.disabledByUser,
      );
      return;
    }
    final permission = await _safePermissionStatus();
    state = state.copyWith(permissionStatus: permission);
    if (!permission.isGranted) {
      state = state.copyWith(
        runtimeStatus: permission == NotificationPermissionStatus.denied
            ? NotificationRuntimeStatus.blockedBySystem
            : NotificationRuntimeStatus.permissionNotDetermined,
      );
      return;
    }

    final tokenState = await _awaitTokenState(allowShortDelay: allowShortDelay);
    if (tokenState.status == NotificationPlatformTokenStatus.unavailable) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.unavailable,
      );
      return;
    }
    if (!tokenState.isReady || tokenState.fcmToken == null) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.waitingForPlatformToken,
      );
      return;
    }

    final token = tokenState.fcmToken!;
    final fingerprint = redactedTokenFingerprint(token);
    final metadataFingerprint = _computeMetadataFingerprint(
      tokenFingerprint: fingerprint,
      permission: permission,
    );

    final changed =
        fingerprint != _prefs.getString(_kLastTokenFingerprint) ||
        metadataFingerprint != _prefs.getString(_kLastMetadataFingerprint) ||
        _prefs.getString(_kCurrentAccountId) !=
            _prefs.getString(_kLastSyncedAccountId);

    if (!changed && state.backendRegistered) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.ready,
        clearRecoverableFailure: true,
      );
      return;
    }

    state = state.copyWith(
      runtimeStatus: NotificationRuntimeStatus.registeringWithBackend,
      clearRecoverableFailure: true,
    );

    try {
      await _registerInstallation(permission);
      await _backend.registerPushToken(
        installationId: state.installationId!,
        platform: defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
        token: token,
        locale: _localeLoader(),
        timezone: _timezoneLoader(),
        permissionStatus: permission,
      );
      await _syncTopics(enabled: true, reason: reason);
      await _prefs.setString(_kLastTokenFingerprint, fingerprint);
      await _prefs.setString(_kLastMetadataFingerprint, metadataFingerprint);
      final currentAccountId = _prefs.getString(_kCurrentAccountId);
      if (currentAccountId == null) {
        await _prefs.remove(_kLastSyncedAccountId);
      } else {
        await _prefs.setString(_kLastSyncedAccountId, currentAccountId);
      }
      final now = DateTime.now().toUtc();
      await _prefs.setString(_kLastSuccessfulSyncAt, now.toIso8601String());
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.ready,
        backendRegistered: true,
        lastTokenFingerprint: fingerprint,
        lastSuccessfulSyncAt: now,
        clearRecoverableFailure: true,
      );
    } catch (e) {
      state = state.copyWith(
        runtimeStatus: NotificationRuntimeStatus.recoverableError,
        recoverableFailure: NotificationRuntimeFailure(
          code: 'sync_failed',
          exceptionType: e.runtimeType.toString(),
        ),
      );
    }
  }

  Future<void> _syncTopics({
    required bool enabled,
    required String reason,
  }) async {
    final topics = _readTopicIntents();
    if (topics.isEmpty) return;
    for (final topic in topics) {
      final result = await _platform.applyTopicIntent(
        topic: topic,
        enabled: enabled,
      );
      if (result.status == PushTopicApplyStatus.waitingForToken) {
        state = state.copyWith(
          runtimeStatus: NotificationRuntimeStatus.waitingForPlatformToken,
        );
      }
    }
    if (kDebugMode) {
      debugPrint(
        '[Notifications] topic sync reason=$reason count=${topics.length}',
      );
    }
  }

  Set<String> _readTopicIntents() {
    final raw = _prefs.getStringList(_kTopicIntents);
    if (raw == null || raw.isEmpty) return _defaultTopics;
    return raw.toSet();
  }

  Future<NotificationPlatformTokenState> _awaitTokenState({
    required bool allowShortDelay,
  }) async {
    final delays = allowShortDelay ? _permissionDelays : const [Duration.zero];
    NotificationPlatformTokenState last = const NotificationPlatformTokenState(
      status: NotificationPlatformTokenStatus.waitingForPlatformToken,
    );
    for (final delay in delays) {
      if (delay > Duration.zero) {
        await Future<void>.delayed(delay);
      }
      last = await _platform.tokenState();
      if (last.isReady) {
        return last;
      }
    }
    return last;
  }

  Future<NotificationPermissionStatus> _safePermissionStatus() async {
    try {
      return await _platform.permissionStatus();
    } catch (_) {
      return NotificationPermissionStatus.notDetermined;
    }
  }

  NotificationRuntimeStatus _statusFor({
    required bool userEnabled,
    required NotificationPermissionStatus permission,
  }) {
    if (!userEnabled) return NotificationRuntimeStatus.disabledByUser;
    if (permission.isGranted) return NotificationRuntimeStatus.synchronizing;
    if (permission == NotificationPermissionStatus.denied) {
      return NotificationRuntimeStatus.blockedBySystem;
    }
    return NotificationRuntimeStatus.permissionNotDetermined;
  }

  NotificationRuntimeStatus _mapFirebaseUnavailable(
    FirebaseBootstrapFailure failure,
  ) {
    return switch (failure.code) {
      FirebaseBootstrapFailureCode.timeout =>
        NotificationRuntimeStatus.unavailable,
      FirebaseBootstrapFailureCode.initializationFailed =>
        NotificationRuntimeStatus.configurationError,
      FirebaseBootstrapFailureCode.unsupportedPlatform =>
        NotificationRuntimeStatus.configurationError,
    };
  }

  String _computeMetadataFingerprint({
    required String tokenFingerprint,
    required NotificationPermissionStatus permission,
  }) => base64Encode(
    utf8.encode(
      jsonEncode({
        'token_fp': tokenFingerprint,
        'locale': _localeLoader(),
        'timezone': _timezoneLoader(),
        'permission': permission.name,
        'app_version': AppConfig.appVersion,
        'build_number': AppConfig.buildNumber,
        'account_id': _prefs.getString(_kCurrentAccountId),
        'user_enabled': state.userEnabled,
      }),
    ),
  );

  DateTime? _readSyncTime() {
    final raw = _prefs.getString(_kLastSuccessfulSyncAt);
    if (raw == null || raw.isEmpty) return null;
    return DateTime.tryParse(raw);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed) return;
    unawaited(_reconcileOnResume());
  }

  Future<void> _reconcileOnResume() async {
    await initialize();
    final permission = await _safePermissionStatus();
    state = state.copyWith(permissionStatus: permission);
    if (state.userEnabled && permission.isGranted) {
      await _synchronize(reason: 'resume', allowShortDelay: false);
    } else {
      state = state.copyWith(
        runtimeStatus: _statusFor(
          userEnabled: state.userEnabled,
          permission: permission,
        ),
      );
    }
  }

  @override
  void dispose() {
    if (_observersAttached) {
      WidgetsBinding.instance.removeObserver(this);
      _observersAttached = false;
    }
    _tokenRefreshSub?.cancel();
    super.dispose();
  }
}
