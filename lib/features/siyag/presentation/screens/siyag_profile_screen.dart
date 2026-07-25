import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/notifications/notifications_controller.dart';
import '../../../../core/notifications/push_notifications.dart';
import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/controllers/installation_service.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/installation_profile.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';

/// Profile (profile.tsx): identity, stats grid, account link, appearance.
///
/// The identity block is **account-aware**: signed in → the account's public
/// name/avatar and stable `SYG-XXXXX` id (editable via `PATCH /account/me`);
/// guest → the anonymous installation profile (editable via `PATCH /profiles/me`).
/// No mock badges — stats are real; the raw installation id stays hidden.
class SiyagProfileScreen extends ConsumerWidget {
  const SiyagProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(profileControllerProvider).value;

    return Directionality(
      textDirection: TextDirection.rtl,
      child: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        children: [
          const SizedBox(height: 40),
          _IdentityHeader(profile: profile),
          const SizedBox(height: 24),
          Row(
            children: [
              _stat('${profile?.gamesPlayed ?? 0}', 'ألعاب'),
              const SizedBox(width: 8),
              _stat('${profile?.gamesSolved ?? 0}', 'حلول'),
              const SizedBox(width: 8),
              _stat('${profile?.roomsWon ?? 0}', 'غرف'),
              const SizedBox(width: 8),
              _stat(
                profile?.weeklyBestPlacement != null
                    ? '#${profile!.weeklyBestPlacement}'
                    : '—',
                'الأفضل',
              ),
            ],
          ),
          const SizedBox(height: 24),
          const _AccountSection(),
          const SizedBox(height: 24),
          const _IdentityNote(),
          const SizedBox(height: 28),
          _AppearanceSelector(),
          const SizedBox(height: 24),
          const _NotificationsSelector(),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  Widget _stat(String v, String l) => Expanded(
    child: Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text(v, style: ST.mono(20)),
          const SizedBox(height: 6),
          Text(l, style: ST.ar(9, color: SC.textMute)),
        ],
      ),
    ),
  );
}

/// Avatar + name + edit + (when signed in) the public `SYG-XXXXX` id chip.
class _IdentityHeader extends ConsumerWidget {
  const _IdentityHeader({required this.profile});
  final InstallationProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final account = ref.watch(sessionControllerProvider).asData?.value.account;
    final signedIn = account != null;

    final name = signedIn ? account.effectiveName : (profile?.label ?? '—');
    final letter = name.isNotEmpty ? name.characters.first : 'س';

    VoidCallback? onEdit;
    if (signedIn) {
      onEdit = () => _showNameSheet(
        context,
        ref,
        title: loc('editName'),
        initial: account.displayName ?? '',
        onSave: (n) => ref
            .read(sessionControllerProvider.notifier)
            .updateAccountProfile(displayName: n),
      );
    } else if (profile != null) {
      onEdit = () => _showNameSheet(
        context,
        ref,
        title: loc('editName'),
        initial: profile!.displayName ?? '',
        onSave: (n) => ref
            .read(profileControllerProvider.notifier)
            .updateDisplayName(n),
      );
    }

    return Center(
      child: Column(
        children: [
          SiyagAvatar(
            letter: letter,
            imageUrl: signedIn ? account.avatarUrl : null,
            size: 80,
            active: true,
          ),
          const SizedBox(height: 16),
          Text(name, style: ST.ar(22, weight: FontWeight.w600)),
          const SizedBox(height: 6),
          SiyagTap(
            onTap: onEdit,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.edit_rounded, size: 13, color: SC.coral),
                const SizedBox(width: 6),
                Text(loc('editName'), style: ST.ar(13, color: SC.coral)),
              ],
            ),
          ),
          if (signedIn) ...[
            const SizedBox(height: 10),
            _PlayerIdChip(id: account.publicPlayerId),
          ],
        ],
      ),
    );
  }
}

/// The stable public player id (`SYG-XXXXX`) — safe to display; tap to copy.
class _PlayerIdChip extends ConsumerWidget {
  const _PlayerIdChip({required this.id});
  final String id;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    return SiyagTap(
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: id));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(loc('idCopied'))));
        }
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
        decoration: BoxDecoration(
          color: SC.surface,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: SC.line),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.badge_outlined, size: 13, color: SC.textMute),
            const SizedBox(width: 6),
            Text(id, style: ST.mono(12, color: SC.textDim)),
            const SizedBox(width: 6),
            Icon(Icons.copy_rounded, size: 12, color: SC.textMute),
          ],
        ),
      ),
    );
  }
}

/// Account section: real Google sign-in (guest) or a compact linked/sign-out
/// row (signed in). Uses the existing [SessionController]; on a real
/// authentication failure it surfaces the error (never a silent guest fallback).
class _AccountSection extends ConsumerWidget {
  const _AccountSection();

  Future<void> _signIn(BuildContext context, WidgetRef ref) async {
    final loc = ref.read(localizationsProvider);
    try {
      final notifier = ref.read(sessionControllerProvider.notifier);
      final ok = await notifier.signInWithGoogle();
      if (!ok) return; // user cancelled — stay guest silently, no error
      // Brand-new account → offer the one-shot welcome name setup.
      final s = ref.read(sessionControllerProvider).asData?.value;
      if (s != null && s.justCreated && context.mounted) {
        await _showNameSheet(
          context,
          ref,
          title: loc('welcomeTitle'),
          body: loc('welcomeBody'),
          initial: s.suggestedDisplayName ?? '',
          showSkip: true,
          onSkip: notifier.consumeJustCreated,
          onSave: (n) => notifier.updateAccountProfile(
            displayName: n,
            avatarUrl: s.suggestedAvatarUrl,
          ),
        );
      }
    } catch (e) {
      final msg = e is GoogleAuthException && e.isConfiguration
          ? loc('signInConfigError')
          : loc.errorMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _signOut(WidgetRef ref) =>
      ref.read(sessionControllerProvider.notifier).logout();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final session = ref.watch(sessionControllerProvider);
    final state = session.asData?.value;
    final signedIn = state?.account != null;
    final signingIn = state?.signingIn ?? false;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SC.line),
      ),
      child: signedIn
          // ── Signed in → compact linked + sign out (identity is in the header)
          ? Row(
              children: [
                Icon(Icons.verified_rounded, size: 16, color: SC.emerald),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    loc('linkedGoogle'),
                    style: ST.ar(13, color: SC.emerald),
                  ),
                ),
                SiyagTap(
                  onTap: () => _signOut(ref),
                  child: Padding(
                    padding: const EdgeInsets.all(4),
                    child: Text(
                      loc('signOut'),
                      style: ST.ar(13, color: SC.textDim),
                    ),
                  ),
                ),
              ],
            )
          // ── Guest → offer Google sign-in ──────────────────────────────────
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Kicker(loc('account')),
                const SizedBox(height: 6),
                Text(loc('signInBenefit'), style: ST.ar(13, color: SC.textDim)),
                const SizedBox(height: 12),
                SiyagPrimaryButton(
                  label: loc('signInWithGoogle'),
                  icon: Icons.login_rounded,
                  busy: signingIn,
                  onTap: () => _signIn(context, ref),
                ),
              ],
            ),
    );
  }
}

/// Privacy/status footer: adapts to guest (anonymous, device-only) vs. signed-in
/// (progress syncs via Google).
class _IdentityNote extends ConsumerWidget {
  const _IdentityNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final signedIn =
        ref.watch(sessionControllerProvider).asData?.value.account != null;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          Icon(
            signedIn ? Icons.cloud_done_outlined : Icons.shield_outlined,
            size: 16,
            color: SC.textMute,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              signedIn ? loc('signedInNote') : loc('guestIdentityNote'),
              style: ST.ar(12, color: SC.textMute),
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared bottom sheet for editing a display name (guest profile, account edit,
/// and the one-shot welcome setup). [onSave] performs the actual persistence.
Future<void> _showNameSheet(
  BuildContext context,
  WidgetRef ref, {
  required String title,
  String? body,
  required String initial,
  required Future<void> Function(String name) onSave,
  bool showSkip = false,
  VoidCallback? onSkip,
}) async {
  final loc = ref.read(localizationsProvider);
  final controller = TextEditingController(text: initial);
  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (ctx) {
      var saving = false;
      return StatefulBuilder(
        builder: (ctx, setSheet) => Directionality(
          textDirection: TextDirection.rtl,
          child: Padding(
            padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(ctx).bottom),
            child: Container(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
              decoration: BoxDecoration(
                color: SC.surface,
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(24),
                ),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: SC.textFaint,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                  ),
                  Text(title, style: ST.ar(18, weight: FontWeight.w600)),
                  if (body != null) ...[
                    const SizedBox(height: 6),
                    Text(body, style: ST.ar(13, color: SC.textDim)),
                  ],
                  const SizedBox(height: 12),
                  TextField(
                    controller: controller,
                    maxLength: 24,
                    style: ST.ar(18),
                    decoration: InputDecoration(
                      hintText: loc('nameHint'),
                      hintStyle: ST.ar(18, color: SC.textFaint),
                      filled: true,
                      fillColor: SC.surfaceHi,
                      counterStyle: ST.mono(10, color: SC.textMute),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide.none,
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: SC.coral, width: 2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SiyagPrimaryButton(
                    label: loc('save'),
                    icon: Icons.check_rounded,
                    busy: saving,
                    onTap: () async {
                      final name = controller.text.trim();
                      if (name.isEmpty) {
                        Navigator.of(ctx).pop();
                        return;
                      }
                      setSheet(() => saving = true);
                      try {
                        await onSave(name);
                      } finally {
                        if (ctx.mounted) Navigator.of(ctx).pop();
                      }
                    },
                  ),
                  if (showSkip) ...[
                    const SizedBox(height: 8),
                    SiyagTap(
                      onTap: () {
                        onSkip?.call();
                        Navigator.of(ctx).pop();
                      },
                      child: Center(
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Text(
                            loc('skip'),
                            style: ST.ar(13, color: SC.textDim),
                          ),
                        ),
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      );
    },
  );
}

/// Notifications opt-in: a single toggle that requests permission + subscribes
/// (the deliberate product moment for the OS prompt), plus a copy-token action
/// for testing. Reflects the live OS permission (e.g. blocked in settings).
class _NotificationsSelector extends ConsumerWidget {
  const _NotificationsSelector();

  Future<void> _copyToken(BuildContext context, WidgetRef ref) async {
    final loc = ref.read(localizationsProvider);
    final token = await ref
        .read(notificationsControllerProvider.notifier)
        .fetchToken();
    if (!context.mounted) return;
    final messenger = ScaffoldMessenger.of(context)..hideCurrentSnackBar();
    if (token == null) {
      messenger.showSnackBar(SnackBar(content: Text(loc('tokenUnavailable'))));
      return;
    }
    await Clipboard.setData(ClipboardData(text: token));
    if (context.mounted) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(SnackBar(content: Text(loc('tokenCopied'))));
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final state = ref.watch(notificationsControllerProvider);
    final ctrl = ref.read(notificationsControllerProvider.notifier);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(loc('notifications')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SC.line),
          ),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(
                    Icons.notifications_active_outlined,
                    size: 18,
                    color: SC.textMute,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          loc('notifications'),
                          style: ST.ar(14, weight: FontWeight.w600),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          state.blockedBySystem
                              ? loc('notificationsBlocked')
                              : loc('notificationsHint'),
                          style: ST.ar(
                            11,
                            color: state.blockedBySystem
                                ? SC.coral
                                : SC.textMute,
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (state.busy)
                    SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: SC.gold,
                      ),
                    )
                  else
                    Switch(
                      value: state.enabled,
                      activeThumbColor: SC.onGold,
                      activeTrackColor: SC.gold,
                      onChanged: (v) async {
                        final perm = await ctrl.toggle(v);
                        if (v && perm != null && perm.isGranted) {
                          // Permission just granted → a token is now available.
                          ref
                              .read(installationServiceProvider)
                              .syncPushToken();
                        }
                        if (v &&
                            perm != null &&
                            !perm.isGranted &&
                            context.mounted) {
                          ScaffoldMessenger.of(context)
                            ..hideCurrentSnackBar()
                            ..showSnackBar(
                              SnackBar(
                                content: Text(loc('notificationsDenied')),
                                action: SnackBarAction(
                                  label: loc('openSettings'),
                                  onPressed: ctrl.openSettings,
                                ),
                              ),
                            );
                        }
                      },
                    ),
                ],
              ),
              if (state.enabled) ...[
                const SizedBox(height: 14),
                Divider(height: 1, color: SC.line),
                const SizedBox(height: 14),
                SiyagTap(
                  onTap: () => _copyToken(context, ref),
                  child: Row(
                    children: [
                      Icon(Icons.vpn_key_outlined, size: 14, color: SC.textMute),
                      const SizedBox(width: 8),
                      Text(loc('copyToken'), style: ST.ar(12, color: SC.textDim)),
                      const Spacer(),
                      Icon(Icons.copy_rounded, size: 12, color: SC.textMute),
                    ],
                  ),
                ),
              ],
            ],
          ),
        ),
      ],
    );
  }
}

/// System / Light / Dark segmented selector. Persists via [AppSettings] and
/// applies immediately (no restart). The selected segment uses the restrained
/// gold accent as a "selected indicator".
class _AppearanceSelector extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    const options = [
      (ThemeMode.system, 'themeSystem', Icons.brightness_auto_rounded),
      (ThemeMode.light, 'themeLight', Icons.light_mode_rounded),
      (ThemeMode.dark, 'themeDark', Icons.dark_mode_rounded),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Kicker(loc('appearance')),
        const SizedBox(height: 10),
        Container(
          padding: const EdgeInsets.all(4),
          decoration: BoxDecoration(
            color: SC.surface,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: SC.line),
          ),
          child: Row(
            children: [
              for (final (m, key, icon) in options)
                Expanded(
                  child: SiyagTap(
                    onTap: () =>
                        ref.read(appSettingsProvider.notifier).setThemeMode(m),
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 160),
                      padding: const EdgeInsets.symmetric(vertical: 10),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: m == mode ? SC.gold : Colors.transparent,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            icon,
                            size: 15,
                            color: m == mode ? SC.onGold : SC.textMute,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            loc(key),
                            style: ST.ar(
                              13,
                              weight: FontWeight.w500,
                              color: m == mode ? SC.onGold : SC.textDim,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}
