import 'dart:ui' show Color;

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:permission_handler/permission_handler.dart' as ph;

import '../firebase/firebase_bootstrap.dart';

/// Background/terminated message handler. MUST be a top-level or static function
/// annotated with `@pragma('vm:entry-point')` — the OS runs it in a **separate
/// isolate**, so Firebase has to be (re)initialized here. Keep it light; heavy
/// work risks the OS killing the isolate. A *notification* message is still
/// rendered in the system tray by the OS automatically — this runs for the data
/// payload / bookkeeping only.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  await initializeFirebase();
  if (kDebugMode) {
    debugPrint(
      '[FCM] background message received: id=${message.messageId} '
      'hasNotification=${message.notification != null} '
      'data=${message.data.keys.toList()}',
    );
  }
}

/// Observable notification-permission status (platform-neutral).
enum PushPermissionStatus { notDetermined, denied, authorized, provisional }

extension PushPermissionStatusX on PushPermissionStatus {
  bool get isGranted =>
      this == PushPermissionStatus.authorized ||
      this == PushPermissionStatus.provisional;
}

/// Complete Firebase Cloud Messaging facade: configuration, permission,
/// token lifecycle, and topic subscribe/unsubscribe. Backend-agnostic — it does
/// not upload the token anywhere (that is a later, deliberate step).
class PushMessagingService {
  PushMessagingService(this._fm);
  final FirebaseMessaging _fm;

  final FlutterLocalNotificationsPlugin _local =
      FlutterLocalNotificationsPlugin();
  bool _configured = false;

  /// Well-known broadcast topic every opted-in device joins.
  static const String broadcastTopic = 'all';

  /// Default channel — mirrors the native `siyaq_general` channel referenced by
  /// the FCM manifest metadata (high importance → heads-up).
  static const AndroidNotificationChannel _channel = AndroidNotificationChannel(
    'siyaq_general',
    'عام',
    description: 'إشعارات سياق العامة',
    importance: Importance.high,
  );

  // ── Streams ────────────────────────────────────────────────────────────────
  /// Emits a new registration token whenever FCM rotates it.
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  /// Messages delivered while the app is in the **foreground**.
  Stream<RemoteMessage> get onForegroundMessage => FirebaseMessaging.onMessage;

  /// User tapped a notification that opened the app from the background.
  Stream<RemoteMessage> get onMessageOpenedApp =>
      FirebaseMessaging.onMessageOpenedApp;

  // ── Configuration ───────────────────────────────────────────────────────────
  /// One-time runtime setup. Idempotent. Requests **no** permission — that is a
  /// deliberate product moment (see [requestPermission]). Initializes local
  /// notifications (used to DISPLAY foreground messages on Android), wires iOS
  /// foreground presentation, and the tap-to-open handlers (incl. cold start).
  Future<void> configure({void Function(RemoteMessage message)? onOpened}) async {
    if (_configured) return;
    _configured = true;

    // Local notifications render a real system notification when a message
    // arrives while the app is FOREGROUNDED (Android otherwise only fires
    // onMessage without showing anything).
    const androidInit = AndroidInitializationSettings('ic_stat_siyaq');
    const iosInit = DarwinInitializationSettings(
      requestAlertPermission: false,
      requestBadgePermission: false,
      requestSoundPermission: false,
    );
    await _local.initialize(
      settings: const InitializationSettings(android: androidInit, iOS: iosInit),
      onDidReceiveNotificationResponse: (resp) {
        if (kDebugMode) {
          debugPrint('[FCM] local notification tapped: payload=${resp.payload}');
        }
      },
    );
    await _local
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(_channel);

    // iOS: show alert/badge/sound while the app is foregrounded.
    await _fm.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    // Foreground messages → display a real notification + react in code.
    onForegroundMessage.listen(_onForeground);

    if (onOpened != null) {
      onMessageOpenedApp.listen(onOpened);
      // App launched from a terminated state by tapping a notification.
      final initial = await _fm.getInitialMessage();
      if (initial != null) onOpened(initial);
    }
  }

  void _onForeground(RemoteMessage message) {
    if (kDebugMode) {
      debugPrint(
        '[FCM] foreground message received: id=${message.messageId} '
        'hasNotification=${message.notification != null} '
        'data=${message.data.keys.toList()}',
      );
    }
    // iOS already shows the banner via presentation options; Android must post
    // a local notification to surface it while the app is open.
    if (defaultTargetPlatform == TargetPlatform.android) {
      showLocalNotification(message);
    }
  }

  /// Renders [message]'s notification block as a system notification. Used for
  /// foreground display; a no-op when the message carries no notification.
  Future<void> showLocalNotification(RemoteMessage message) async {
    final n = message.notification;
    if (n == null) return;
    await _local.show(
      id: n.hashCode,
      title: n.title,
      body: n.body,
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
        iOS: const DarwinNotificationDetails(),
      ),
      payload: message.messageId,
    );
  }

  // ── Permission ──────────────────────────────────────────────────────────────
  /// Current permission status without prompting. Android 13+ is read via
  /// `permission_handler` (the source of truth for `POST_NOTIFICATIONS`); iOS
  /// via FCM's notification settings (covers provisional).
  Future<PushPermissionStatus> permissionStatus() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return _mapPh(await ph.Permission.notification.status);
    }
    return _map((await _fm.getNotificationSettings()).authorizationStatus);
  }

  /// Explicitly request permission from a deliberate product moment. On Android
  /// 13+ this triggers the `POST_NOTIFICATIONS` runtime dialog via
  /// `permission_handler` (more reliable than FCM's own path); on iOS it shows
  /// the system dialog via FCM (which also registers for APNs).
  Future<PushPermissionStatus> requestPermission() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      final res = await ph.Permission.notification.request();
      // Keep FCM's own settings in sync (no extra prompt on Android).
      await _fm.requestPermission();
      return _mapPh(res);
    }
    final settings = await _fm.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    return _map(settings.authorizationStatus);
  }

  /// True when the OS won't show the prompt again (Android "Don't allow" twice /
  /// blocked in settings). The UI must then deep-link to system settings.
  Future<bool> isPermanentlyDenied() async {
    if (defaultTargetPlatform == TargetPlatform.android) {
      return ph.Permission.notification.isPermanentlyDenied;
    }
    return false;
  }

  /// Opens the OS app-settings page so the user can enable notifications when
  /// the in-app prompt can no longer be shown.
  Future<bool> openSystemSettings() => ph.openAppSettings();

  // ── Token ───────────────────────────────────────────────────────────────────
  /// Best-effort token fetch. On iOS, `getToken()` *triggers* APNs registration
  /// but throws `apns-token-not-set` until the OS delivers the APNs token — so
  /// we retry it (up to ~12s) while APNs propagates. Returns null if it never
  /// arrives (no permission / no network). Immediate on Android.
  Future<String?> token() async {
    for (var i = 0; i < 12; i++) {
      try {
        return await _fm.getToken();
      } catch (e) {
        if (!e.toString().contains('apns-token-not-set')) return null;
        await Future<void>.delayed(const Duration(seconds: 1));
      }
    }
    return null;
  }

  /// True once FCM can perform token/topic ops (iOS: APNs is set).
  Future<bool> _ready() async {
    if (defaultTargetPlatform != TargetPlatform.iOS &&
        defaultTargetPlatform != TargetPlatform.macOS) {
      return true;
    }
    return await token() != null;
  }

  /// Invalidate the current token (e.g. on sign-out / disabling notifications).
  Future<void> deleteToken() => _fm.deleteToken();

  // ── Topics ──────────────────────────────────────────────────────────────────
  Future<void> subscribeToTopic(String topic) async {
    try {
      if (!await _ready()) return; // iOS: skip until APNs is set
      await _fm.subscribeToTopic(topic);
    } catch (e) {
      debugPrint('[FCM] subscribeToTopic failed: $e');
    }
  }

  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      if (!await _ready()) return;
      await _fm.unsubscribeFromTopic(topic);
    } catch (e) {
      debugPrint('[FCM] unsubscribeFromTopic failed: $e');
    }
  }

  static PushPermissionStatus _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized => PushPermissionStatus.authorized,
    AuthorizationStatus.provisional => PushPermissionStatus.provisional,
    AuthorizationStatus.denied => PushPermissionStatus.denied,
    AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
  };

  static PushPermissionStatus _mapPh(ph.PermissionStatus s) {
    if (s.isGranted || s.isLimited) return PushPermissionStatus.authorized;
    if (s.isProvisional) return PushPermissionStatus.provisional;
    return PushPermissionStatus.denied;
  }

  /// A non-reversible fingerprint (never the token itself) — safe to log.
  static String fingerprint(String token) =>
      'len=${token.length} fp=${token.hashCode.toRadixString(16)}';
}

// ── Providers ─────────────────────────────────────────────────────────────────
final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final pushMessagingServiceProvider = Provider<PushMessagingService>(
  (ref) => PushMessagingService(ref.watch(firebaseMessagingProvider)),
);

/// Foreground messages as a stream — the app subscribes to show an in-app cue.
final foregroundMessageProvider = StreamProvider<RemoteMessage>(
  (ref) => ref.watch(pushMessagingServiceProvider).onForegroundMessage,
);

/// Debug-only proof that FCM is correctly installed: fetches a token and logs
/// only a redacted fingerprint (never the token). Also wires the refresh
/// listener. No-op in release; no permission prompt; no backend upload.
Future<void> verifyFcmInstallation(PushMessagingService push) async {
  if (!kDebugMode) return;
  push.onTokenRefresh.listen(
    (t) => debugPrint(
      '[FCM] token refreshed (${PushMessagingService.fingerprint(t)})',
    ),
  );
  final t = await push.token();
  debugPrint(
    t == null
        ? '[FCM] token not available yet on this platform/device'
        : '[FCM] registration token OK (${PushMessagingService.fingerprint(t)})',
  );
}
