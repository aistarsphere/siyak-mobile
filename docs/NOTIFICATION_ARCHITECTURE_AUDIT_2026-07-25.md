# Notification Architecture Audit — 2026-07-25

This audit captures the notification-related architecture before the rebuild.

## Existing startup flow

1. `main()` calls `initializeFirebase()`.
2. `main()` registers `FirebaseMessaging.onBackgroundMessage(...)`.
3. `main()` manually constructs `PushMessagingService(FirebaseMessaging.instance)`.
4. `main()` calls `push.configure(...)`.
5. `main()` optionally calls `verifyFcmInstallation(push)` in debug.
6. `runApp(ProviderScope(...))`.
7. `SiyagShell.initState()` calls:
   - `installationServiceProvider.bootstrap()`
   - `notificationsControllerProvider.notifier.maybePromptOnFirstRun()`
8. `NotificationsController.build()` also schedules a `Future.microtask(_reconcile)`.

Result: notification startup is split across `main()`, a widget lifecycle hook,
and a controller-side microtask.

## Existing ownership

- Firebase bootstrap: `lib/core/firebase/firebase_bootstrap.dart`
- Push runtime/configuration: `lib/core/notifications/push_notifications.dart`
- UI state + permission flow: `lib/core/notifications/notifications_controller.dart`
- Backend token sync + installation registration: `lib/features/auth/presentation/controllers/installation_service.dart`
- Account attach/detach hooks: `lib/features/auth/presentation/controllers/session_controller.dart`
- Product trigger for first-run prompt: `lib/features/siyag/presentation/siyag_shell.dart`
- UI toggle/copy-token action: `lib/features/siyag/presentation/screens/siyag_profile_screen.dart`

## Existing native configuration

### Android

- `android/app/src/main/AndroidManifest.xml`
  - `POST_NOTIFICATIONS`
  - default FCM channel/icon/color metadata
- `android/app/src/main/kotlin/com/kaher/siyak/MainActivity.kt`
  - no notification business logic

### iOS

- `ios/Runner/AppDelegate.swift`
  - imports `flutter_local_notifications`
  - sets `FlutterLocalNotificationsPlugin.setPluginRegistrantCallback(...)`
- `ios/Runner/Info.plist`
  - `UIBackgroundModes = [fetch, remote-notification]`
- `ios/Runner/Runner.entitlements`
  - `aps-environment = development`

## Exact failure causes in the old architecture

1. Multiple startup owners:
   - `main()`
   - `SiyagShell.initState()`
   - `NotificationsController.build()`

2. `PushMessagingService.token()` used retry polling around `getToken()`.

3. `NotificationsController` persisted `enabled = true` after a granted
   permission flow even when APNs/FCM/backend sync had not completed.

4. Topic operations could no-op silently when APNs/FCM was not ready.

5. Backend registration and topic synchronization were split across:
   - notification controller
   - installation service
   - debug verification path

6. `verifyFcmInstallation()` added another token/listener path in debug builds.

7. `onTokenRefresh` ownership lived in installation service rather than one
   application-level notification runtime.

8. Logout path invalidated push tokens as part of normal account transitions,
   which is incorrect for a persistent installation identity.

9. The app treated "user enabled notifications" too close to "device is fully
   registered and ready".

10. Direct Firebase topic subscription was used as an application flow instead
    of being isolated behind one notification runtime boundary.

## Contract surface currently available in-repo

From `docs/AUTH_FOUNDATION_CONTRACT.md` and the bundled OpenAPI:

- `POST /installations/register`
- `POST /installations/attach`
- `POST /installations/detach`
- `POST /installations/push/register`
- `POST /installations/push/invalidate`

No documented backend notification settings endpoint or backend topic-intent
endpoint exists in the current repository contract bundle.
