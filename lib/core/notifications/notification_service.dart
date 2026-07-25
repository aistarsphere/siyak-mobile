import 'dart:convert';
import 'dart:developer';
import 'dart:io';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';

import '../../firebase_options.dart';

/// Firebase Cloud Messaging + local-notifications service.
///
/// Ported 1:1 from the working Tamweeniya-Agent setup. Singleton; call [init]
/// once after the first frame. Requests permission at init (no in-app toggle),
/// shows foreground messages via a local notification, and exposes the FCM token
/// to the app ([ensureToken]) so it can be sent to the backend on login and on
/// rotation ([onTokenRefreshed]); [unsubscribeFromAllTopics] clears it on logout.
class NotificationService {
  NotificationService._();

  static final NotificationService instance = NotificationService._();

  String token = "";

  /// Invoked with a fresh FCM token at init and whenever Firebase rotates it,
  /// so the app can (re)register the device with the backend.
  void Function(String token)? onTokenRefreshed;

  /// On iOS an FCM token can't be minted until Apple delivers the APNs device
  /// token, which arrives asynchronously shortly after launch — calling
  /// `getToken()` before that throws "APNS token has not been set yet". Polls
  /// briefly for it; false means it never arrived (e.g. a simulator).
  Future<bool> _waitForApnsToken() async {
    if (!Platform.isIOS) return true;
    final messaging = FirebaseMessaging.instance;
    for (var attempt = 0; attempt < 10; attempt++) {
      if (await messaging.getAPNSToken() != null) return true;
      await Future<void>.delayed(const Duration(milliseconds: 400));
    }
    return false;
  }

  /// Returns the current FCM token, fetching it if it hasn't resolved yet (e.g.
  /// login happens before [init] finishes). Sending a valid, current token on
  /// login is required so the backend subscribes the right device.
  Future<String> ensureToken() async {
    if (token.isNotEmpty) return token;
    try {
      if (!await _waitForApnsToken()) return token;
      token = await FirebaseMessaging.instance.getToken() ?? "";
    } catch (e) {
      log("Error getting FCM token: $e");
    }
    return token;
  }

  /// Deletes this device's registration token so it stops receiving any push
  /// for the account that just signed out; a fresh token is minted on the next
  /// [ensureToken] (i.e. next login).
  Future<void> unsubscribeFromAllTopics() async {
    try {
      await FirebaseMessaging.instance.deleteToken();
      token = "";
    } catch (e) {
      log("Error deleting FCM token: $e");
    }
  }

  final channel = const AndroidNotificationChannel(
    "high_importance_channel",
    "High Importance Notifications",
    description: "Siyaq",
    importance: Importance.max,
  );
  final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
      FlutterLocalNotificationsPlugin();

  Future<void> init() async {
    // On a hot restart the native Firebase SDK keeps its default app alive while
    // the Dart plugin registration resets, so re-initializing throws
    // "[core/duplicate-app]". Skip it then; a cold start has an empty app list.
    if (Firebase.apps.isEmpty) {
      await Firebase.initializeApp(
        options: DefaultFirebaseOptions.currentPlatform,
      );
    }
    final isPermissionAccepted =
        await flutterLocalNotificationsPlugin
            .resolvePlatformSpecificImplementation<
              AndroidFlutterLocalNotificationsPlugin
            >()
            ?.requestNotificationsPermission() ??
        true;
    if (isPermissionAccepted) await initForegroundNotifications();
    final messaging = FirebaseMessaging.instance;

    await messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    await messaging.setForegroundNotificationPresentationOptions(
      alert: true,
      badge: true,
      sound: true,
    );

    setOnReceiveFirebaseMessage();
    try {
      if (await _waitForApnsToken()) {
        token = await messaging.getToken() ?? "";
        log("firebasetoken: $token");
        if (token.isNotEmpty) onTokenRefreshed?.call(token);
      } else {
        log("APNs token unavailable — skipped FCM token fetch");
      }
    } catch (e) {
      log("Error getting FCM token: $e");
    }

    // Keep push working when Firebase rotates the token mid-session.
    messaging.onTokenRefresh.listen((newToken) {
      token = newToken;
      onTokenRefreshed?.call(newToken);
    });
  }

  Future<void> initForegroundNotifications() async {
    await flutterLocalNotificationsPlugin
        .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin
        >()
        ?.createNotificationChannel(channel);

    const initializationSettingsAndroid = AndroidInitializationSettings(
      'ic_stat_siyaq',
    );
    const initializationSettingsIOS = DarwinInitializationSettings();
    const initializationSettings = InitializationSettings(
      android: initializationSettingsAndroid,
      iOS: initializationSettingsIOS,
    );

    await flutterLocalNotificationsPlugin.initialize(
      settings: initializationSettings,
      onDidReceiveNotificationResponse: handelResponse,
      onDidReceiveBackgroundNotificationResponse: handelResponse,
    );
  }

  void setOnReceiveFirebaseMessage() {
    FirebaseMessaging.onMessage.listen((RemoteMessage message) {
      final RemoteNotification? notification = message.notification;
      final AndroidNotification? android = message.notification?.android;

      if (notification != null && android != null) {
        flutterLocalNotificationsPlugin.show(
          id: notification.hashCode,
          title: notification.title,
          body: notification.body,
          notificationDetails: NotificationDetails(
            android: AndroidNotificationDetails(
              channel.id,
              channel.name,
              channelDescription: channel.description,
            ),
          ),
          payload: json.encode(message.data),
        );
      }
    });
  }

  static void handelResponse(NotificationResponse details) async {
    if (details.payload != null) {
      // TODO: Handle notification tap (deep link).
    }
  }
}
