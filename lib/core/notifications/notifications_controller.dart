import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../features/game/presentation/controllers/app_settings_controller.dart'
    show sharedPreferencesProvider;
import 'push_notifications.dart';

/// UI-facing notification state: the user's opt-in preference, the live system
/// permission, and a redacted token fingerprint for support.
class NotificationsState {
  const NotificationsState({
    this.enabled = false,
    this.permission = PushPermissionStatus.notDetermined,
    this.permanentlyDenied = false,
    this.busy = false,
    this.tokenFingerprint,
  });

  /// The user's persisted opt-in choice.
  final bool enabled;

  /// Live OS permission (may diverge from [enabled] if revoked in settings).
  final PushPermissionStatus permission;

  /// The OS will no longer show the prompt — only system settings can grant it.
  final bool permanentlyDenied;
  final bool busy;

  /// Redacted `len=… fp=…` (never the token) — shown for debugging/support.
  final String? tokenFingerprint;

  /// Notifications can't be delivered until the user fixes the OS permission.
  bool get blockedBySystem =>
      permanentlyDenied ||
      (enabled && !permission.isGranted);

  NotificationsState copyWith({
    bool? enabled,
    PushPermissionStatus? permission,
    bool? permanentlyDenied,
    bool? busy,
    String? tokenFingerprint,
  }) => NotificationsState(
    enabled: enabled ?? this.enabled,
    permission: permission ?? this.permission,
    permanentlyDenied: permanentlyDenied ?? this.permanentlyDenied,
    busy: busy ?? this.busy,
    tokenFingerprint: tokenFingerprint ?? this.tokenFingerprint,
  );
}

/// Owns the notification opt-in lifecycle: request permission, subscribe /
/// unsubscribe the broadcast topic, and persist the preference. The system
/// permission prompt is only ever triggered here (a deliberate product moment).
class NotificationsController extends Notifier<NotificationsState> {
  static const _kEnabled = 'siyaq.notifications.enabled';
  static const _kPrompted = 'siyaq.notifications.prompted';

  PushMessagingService get _push => ref.read(pushMessagingServiceProvider);
  SharedPreferences get _sp => ref.read(sharedPreferencesProvider);

  @override
  NotificationsState build() {
    final enabled = _sp.getBool(_kEnabled) ?? false;
    // Reconcile with the live OS permission (and re-assert the subscription)
    // without blocking first paint.
    Future.microtask(_reconcile);
    return NotificationsState(enabled: enabled);
  }

  Future<void> _reconcile() async {
    final perm = await _push.permissionStatus();
    final permanent = await _push.isPermanentlyDenied();
    state = state.copyWith(permission: perm, permanentlyDenied: permanent);
    if (state.enabled && perm.isGranted) {
      // Idempotent — keeps the topic subscription alive across reinstalls/token
      // rotation.
      await _push.subscribeToTopic(PushMessagingService.broadcastTopic);
    }
  }

  /// Ask for permission exactly once on first launch (a fresh install has never
  /// seen the prompt). If already granted or permanently denied, it does not
  /// prompt. Safe to call on every startup — it self-guards via a stored flag.
  Future<void> maybePromptOnFirstRun() async {
    if (_sp.getBool(_kPrompted) ?? false) return;
    await _sp.setBool(_kPrompted, true);
    final perm = await _push.permissionStatus();
    if (perm.isGranted) {
      await _subscribeAndPersist(perm);
      return;
    }
    if (await _push.isPermanentlyDenied()) {
      state = state.copyWith(permission: perm, permanentlyDenied: true);
      return;
    }
    await enable();
  }

  /// Turn notifications on: request permission, then subscribe to the broadcast
  /// topic. When the OS has permanently denied it, deep-link to system settings
  /// (the prompt can no longer appear). Returns the resulting permission.
  Future<PushPermissionStatus> enable() async {
    if (await _push.isPermanentlyDenied()) {
      state = state.copyWith(permanentlyDenied: true, busy: false);
      await _push.openSystemSettings();
      return PushPermissionStatus.denied;
    }
    state = state.copyWith(busy: true);
    final perm = await _push.requestPermission();
    if (perm.isGranted) {
      await _subscribeAndPersist(perm);
    } else {
      final permanent = await _push.isPermanentlyDenied();
      await _sp.setBool(_kEnabled, false);
      state = state.copyWith(
        enabled: false,
        permission: perm,
        permanentlyDenied: permanent,
        busy: false,
      );
    }
    return perm;
  }

  Future<void> _subscribeAndPersist(PushPermissionStatus perm) async {
    await _push.subscribeToTopic(PushMessagingService.broadcastTopic);
    await _sp.setBool(_kEnabled, true);
    state = state.copyWith(
      enabled: true,
      permission: perm,
      permanentlyDenied: false,
      busy: false,
    );
  }

  /// Open the OS settings page (for when notifications are blocked in settings).
  Future<void> openSettings() => _push.openSystemSettings();

  /// Turn notifications off: unsubscribe and persist the choice (the OS
  /// permission itself is not revoked — that lives in system settings).
  Future<void> disable() async {
    state = state.copyWith(busy: true);
    await _push.unsubscribeFromTopic(PushMessagingService.broadcastTopic);
    await _sp.setBool(_kEnabled, false);
    state = state.copyWith(enabled: false, busy: false);
  }

  /// Toggle helper. Returns the permission when enabling (for UI feedback).
  Future<PushPermissionStatus?> toggle(bool value) async {
    if (value) return enable();
    await disable();
    return null;
  }

  /// Subscribe/unsubscribe an arbitrary topic (e.g. per-room channels).
  Future<void> subscribe(String topic) => _push.subscribeToTopic(topic);
  Future<void> unsubscribe(String topic) => _push.unsubscribeFromTopic(topic);

  /// Fetch the current token. Stashes only its redacted fingerprint in state;
  /// returns the full token to the caller (e.g. copy-to-clipboard for testing).
  Future<String?> fetchToken() async {
    final t = await _push.token();
    state = state.copyWith(
      tokenFingerprint: t == null
          ? null
          : PushMessagingService.fingerprint(t),
    );
    return t;
  }
}

final notificationsControllerProvider =
    NotifierProvider<NotificationsController, NotificationsState>(
      NotificationsController.new,
    );
