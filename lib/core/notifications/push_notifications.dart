import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Observable notification-permission status (platform-neutral).
enum PushPermissionStatus { notDetermined, denied, authorized, provisional }

/// A clean seam for requesting notification permission **later**, from an
/// intentional product/onboarding screen — never automatically at launch.
/// (Phase FB-1 only prepares the interface; no permission UI is built yet.)
abstract class NotificationPermissionService {
  /// Current permission status without prompting the user.
  Future<PushPermissionStatus> status();

  /// Explicitly request permission. On iOS this shows the system dialog; on
  /// Android 13+ it triggers the `POST_NOTIFICATIONS` runtime request. Call
  /// this ONLY from a deliberate product moment.
  Future<PushPermissionStatus> request();
}

/// Thin, backend-agnostic wrapper over Firebase Cloud Messaging token handling.
/// Phase FB-1 scope: obtain a token to prove the SDK works and observe refreshes.
/// It does **not** upload tokens to the backend or subscribe to any topic.
class PushMessagingService {
  PushMessagingService(this._fm);
  final FirebaseMessaging _fm;

  /// Emits a new token whenever FCM rotates it.
  Stream<String> get onTokenRefresh => _fm.onTokenRefresh;

  /// Best-effort token fetch for local verification. Returns null when the
  /// platform can't provide one yet (e.g. iOS before APNs/permission).
  Future<String?> token() async {
    try {
      return await _fm.getToken();
    } catch (_) {
      return null;
    }
  }

  /// A non-reversible fingerprint (never the token itself) — safe to log.
  static String fingerprint(String token) =>
      'len=${token.length} fp=${token.hashCode.toRadixString(16)}';
}

class _FcmPermissionService implements NotificationPermissionService {
  _FcmPermissionService(this._fm);
  final FirebaseMessaging _fm;

  PushPermissionStatus _map(AuthorizationStatus s) => switch (s) {
    AuthorizationStatus.authorized => PushPermissionStatus.authorized,
    AuthorizationStatus.provisional => PushPermissionStatus.provisional,
    AuthorizationStatus.denied => PushPermissionStatus.denied,
    AuthorizationStatus.notDetermined => PushPermissionStatus.notDetermined,
  };

  @override
  Future<PushPermissionStatus> status() async =>
      _map((await _fm.getNotificationSettings()).authorizationStatus);

  @override
  Future<PushPermissionStatus> request() async {
    // firebase_messaging maps this to the iOS prompt and the Android 13+
    // POST_NOTIFICATIONS runtime permission.
    final settings = await _fm.requestPermission();
    return _map(settings.authorizationStatus);
  }
}

final firebaseMessagingProvider = Provider<FirebaseMessaging>(
  (ref) => FirebaseMessaging.instance,
);

final pushMessagingServiceProvider = Provider<PushMessagingService>(
  (ref) => PushMessagingService(ref.watch(firebaseMessagingProvider)),
);

final notificationPermissionServiceProvider =
    Provider<NotificationPermissionService>(
      (ref) => _FcmPermissionService(ref.watch(firebaseMessagingProvider)),
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
