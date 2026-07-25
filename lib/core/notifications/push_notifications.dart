import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../firebase/firebase_bootstrap.dart';

@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await ensureFirebaseBootstrapped();
  if (kDebugMode) {
    debugPrint(
      '[Notifications] background message'
      ' id=${message.messageId}'
      ' hasNotification=${message.notification != null}'
      ' dataKeys=${message.data.keys.toList()}',
    );
  }
}

enum NotificationPermissionStatus {
  notDetermined,
  denied,
  authorized,
  provisional,
}

extension NotificationPermissionStatusX on NotificationPermissionStatus {
  bool get isGranted =>
      this == NotificationPermissionStatus.authorized ||
      this == NotificationPermissionStatus.provisional;
}

enum NotificationPlatformTokenStatus {
  unavailable,
  waitingForPlatformToken,
  ready,
}

class NotificationPlatformTokenState {
  const NotificationPlatformTokenState({required this.status, this.fcmToken});

  final NotificationPlatformTokenStatus status;
  final String? fcmToken;

  bool get isReady =>
      status == NotificationPlatformTokenStatus.ready && fcmToken != null;
}

enum NotificationPlatformFailureCode {
  firebaseUnavailable,
  permissionDenied,
  waitingForPlatformToken,
  operationFailed,
  configurationError,
}

class NotificationPlatformException implements Exception {
  const NotificationPlatformException({
    required this.code,
    required this.exceptionType,
  });

  final NotificationPlatformFailureCode code;
  final String exceptionType;

  @override
  String toString() => 'NotificationPlatformException($code, $exceptionType)';
}

abstract class NotificationRouter {
  Future<void> handleRemoteOpen(RemoteMessage message);
  Future<void> handleLocalOpen(String? payload);
}

class DebugNotificationRouter implements NotificationRouter {
  const DebugNotificationRouter();

  @override
  Future<void> handleLocalOpen(String? payload) async {
    if (!kDebugMode) return;
    debugPrint('[Notifications] local open payload=${payload ?? "<empty>"}');
  }

  @override
  Future<void> handleRemoteOpen(RemoteMessage message) async {
    if (!kDebugMode) return;
    debugPrint(
      '[Notifications] remote open'
      ' id=${message.messageId}'
      ' dataKeys=${message.data.keys.toList()}',
    );
  }
}

abstract class NotificationPlatformGateway {
  Stream<String> get onTokenRefresh;

  Future<void> initialize(NotificationRouter router);
  Future<NotificationPermissionStatus> permissionStatus();
  Future<NotificationPermissionStatus> requestPermission();
  Future<bool> canRequestPermissionAgain();
  Future<bool> openSystemSettings();
  Future<NotificationPlatformTokenState> tokenState();
  Future<PushTopicApplyResult> applyTopicIntent({
    required String topic,
    required bool enabled,
  });
}

enum PushTopicApplyStatus { performed, waitingForToken }

class PushTopicApplyResult {
  const PushTopicApplyResult({
    required this.topic,
    required this.enabled,
    required this.status,
  });

  final String topic;
  final bool enabled;
  final PushTopicApplyStatus status;
}

class FirebaseNotificationPlatformGateway
    implements NotificationPlatformGateway {
  FirebaseNotificationPlatformGateway(this._messaging);

  final FirebaseMessaging? _messaging;
  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();

  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'siyaq_general',
    'عام',
    description: 'إشعارات سياق العامة',
    importance: Importance.high,
  );

  bool _initialized = false;
  StreamSubscription<RemoteMessage>? _foregroundSub;
  StreamSubscription<RemoteMessage>? _openSub;

  @override
  Stream<String> get onTokenRefresh =>
      _messaging?.onTokenRefresh ?? const Stream<String>.empty();

  @override
  Future<void> initialize(NotificationRouter router) async {
    if (_initialized || _messaging == null) return;
    _initialized = true;

    FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

    const androidInit = AndroidInitializationSettings('ic_stat_siyaq');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (response) async {
        await router.handleLocalOpen(response.payload);
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    await _messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    _foregroundSub ??= FirebaseMessaging.onMessage.listen((message) async {
      if (defaultTargetPlatform == TargetPlatform.android &&
          message.notification != null) {
        await _showAndroidForegroundNotification(message);
      }
    });

    _openSub ??= FirebaseMessaging.onMessageOpenedApp.listen(
      router.handleRemoteOpen,
    );
    final initial = await _messaging.getInitialMessage();
    if (initial != null) {
      await router.handleRemoteOpen(initial);
    }
  }

  Future<void> _showAndroidForegroundNotification(RemoteMessage message) async {
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
      id: notification.hashCode,
      title: notification.title,
      body: notification.body,
      notificationDetails: NotificationDetails(
        android: AndroidNotificationDetails(
          _channel.id,
          _channel.name,
          channelDescription: _channel.description,
          importance: Importance.high,
          priority: Priority.high,
          icon: 'ic_stat_siyaq',
          color: const Color(0xFFDDB75F),
        ),
      ),
      payload: message.messageId,
    );
  }

  @override
  Future<NotificationPermissionStatus> permissionStatus() async {
    if (_messaging == null) {
      throw const NotificationPlatformException(
        code: NotificationPlatformFailureCode.firebaseUnavailable,
        exceptionType: 'firebase_unavailable',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _mapPermissionHandler(await ph.Permission.notification.status);
    }
    final settings = await _messaging.getNotificationSettings();
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<NotificationPermissionStatus> requestPermission() async {
    if (_messaging == null) {
      throw const NotificationPlatformException(
        code: NotificationPlatformFailureCode.firebaseUnavailable,
        exceptionType: 'firebase_unavailable',
      );
    }
    if (defaultTargetPlatform == TargetPlatform.android) {
      final result = await ph.Permission.notification.request();
      await _messaging.requestPermission();
      return _mapPermissionHandler(result);
    }
    final settings = await _messaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _mapAuthorizationStatus(settings.authorizationStatus);
  }

  @override
  Future<bool> canRequestPermissionAgain() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return !(await ph.Permission.notification.isPermanentlyDenied);
    }
    final status = await permissionStatus();
    return status != NotificationPermissionStatus.denied;
  }

  @override
  Future<bool> openSystemSettings() => ph.openAppSettings();

  @override
  Future<NotificationPlatformTokenState> tokenState() async {
    if (_messaging == null) {
      return const NotificationPlatformTokenState(
        status: NotificationPlatformTokenStatus.unavailable,
      );
    }
    try {
      if (Platform.isIOS) {
        final apns = await _messaging.getAPNSToken();
        if (apns == null || apns.isEmpty) {
          return const NotificationPlatformTokenState(
            status: NotificationPlatformTokenStatus.waitingForPlatformToken,
          );
        }
      }
      final token = await _messaging.getToken();
      if (token == null || token.isEmpty) {
        return const NotificationPlatformTokenState(
          status: NotificationPlatformTokenStatus.waitingForPlatformToken,
        );
      }
      return NotificationPlatformTokenState(
        status: NotificationPlatformTokenStatus.ready,
        fcmToken: token,
      );
    } catch (e) {
      final text = e.toString();
      if (text.contains('apns-token-not-set')) {
        return const NotificationPlatformTokenState(
          status: NotificationPlatformTokenStatus.waitingForPlatformToken,
        );
      }
      throw NotificationPlatformException(
        code: NotificationPlatformFailureCode.operationFailed,
        exceptionType: e.runtimeType.toString(),
      );
    }
  }

  @override
  Future<PushTopicApplyResult> applyTopicIntent({
    required String topic,
    required bool enabled,
  }) async {
    if (_messaging == null) {
      throw const NotificationPlatformException(
        code: NotificationPlatformFailureCode.firebaseUnavailable,
        exceptionType: 'firebase_unavailable',
      );
    }
    final token = await tokenState();
    if (!token.isReady) {
      return PushTopicApplyResult(
        topic: topic,
        enabled: enabled,
        status: PushTopicApplyStatus.waitingForToken,
      );
    }
    try {
      if (enabled) {
        await _messaging.subscribeToTopic(topic);
      } else {
        await _messaging.unsubscribeFromTopic(topic);
      }
      return PushTopicApplyResult(
        topic: topic,
        enabled: enabled,
        status: PushTopicApplyStatus.performed,
      );
    } catch (e) {
      throw NotificationPlatformException(
        code: NotificationPlatformFailureCode.operationFailed,
        exceptionType: e.runtimeType.toString(),
      );
    }
  }

  static NotificationPermissionStatus _mapAuthorizationStatus(
    AuthorizationStatus status,
  ) => switch (status) {
    AuthorizationStatus.authorized => NotificationPermissionStatus.authorized,
    AuthorizationStatus.provisional => NotificationPermissionStatus.provisional,
    AuthorizationStatus.denied => NotificationPermissionStatus.denied,
    AuthorizationStatus.notDetermined =>
      NotificationPermissionStatus.notDetermined,
  };

  static NotificationPermissionStatus _mapPermissionHandler(
    ph.PermissionStatus status,
  ) {
    if (status.isGranted || status.isLimited) {
      return NotificationPermissionStatus.authorized;
    }
    if (status.isProvisional) {
      return NotificationPermissionStatus.provisional;
    }
    return NotificationPermissionStatus.denied;
  }
}

final firebaseMessagingProvider = Provider<FirebaseMessaging?>((ref) {
  final result = ref.watch(firebaseBootstrapResultProvider);
  return result is FirebaseAvailable ? FirebaseMessaging.instance : null;
});

final notificationRouterProvider = Provider<NotificationRouter>(
  (ref) => const DebugNotificationRouter(),
);

final notificationPlatformGatewayProvider =
    Provider<NotificationPlatformGateway>(
      (ref) => FirebaseNotificationPlatformGateway(
        ref.watch(firebaseMessagingProvider),
      ),
    );

String redactedTokenFingerprint(String token) =>
    'len=${token.length} fp=${token.hashCode.toRadixString(16)}';
