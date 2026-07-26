import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/siyag_theme.dart';
import '../../../../core/widgets/siyag/siyag_common.dart';
import '../../../../core/widgets/siyag/siyag_tap.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
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
        onSave: (n) =>
            ref.read(profileControllerProvider.notifier).updateDisplayName(n),
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

  Future<void> _signIn(BuildContext context, WidgetRef ref) =>
      _runSignIn(context, ref, (n) => n.signInWithGoogle());

  Future<void> _signInApple(BuildContext context, WidgetRef ref) =>
      _runSignIn(context, ref, (n) => n.signInWithApple());

  /// Shared sign-in flow (Google/Apple): run the provider, then offer the
  /// one-shot welcome name setup for a brand-new account; surface real errors.
  Future<void> _runSignIn(
    BuildContext context,
    WidgetRef ref,
    Future<bool> Function(SessionController) run,
  ) async {
    final loc = ref.read(localizationsProvider);
    try {
      final notifier = ref.read(sessionControllerProvider.notifier);
      final ok = await run(notifier);
      if (!ok) return; // user cancelled — stay guest silently, no error
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
      final isConfig =
          (e is GoogleAuthException && e.isConfiguration) ||
          (e is AppleAuthException && e.isConfiguration);
      final msg = isConfig ? loc('signInConfigError') : loc.errorMessage(e);
      if (context.mounted) {
        ScaffoldMessenger.of(context)
          ..hideCurrentSnackBar()
          ..showSnackBar(SnackBar(content: Text(msg)));
      }
    }
  }

  Future<void> _signOut(BuildContext context, WidgetRef ref) async {
    final loc = ref.read(localizationsProvider);
    final ok = await showSiyagConfirm(
      context,
      direction: loc.direction,
      title: loc('confirmLogoutTitle'),
      body: loc('confirmLogoutBody'),
      confirmLabel: loc('signOut'),
      cancelLabel: loc('cancel'),
    );
    if (ok) await ref.read(sessionControllerProvider.notifier).logout();
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final session = ref.watch(sessionControllerProvider);
    final state = session.asData?.value;
    final account = state?.account;
    final signedIn = account != null;
    final signingIn = state?.signingIn ?? false;
    final appleSupported = ref.watch(appleAuthGatewayProvider).isSupported;
    final linkedApple = account?.linkedProviders.contains('apple') ?? false;
    final blocked = signedIn && !account.isActive;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: SC.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: SC.line),
      ),
      child: signedIn
          // ── Signed in → optional blocked banner + provider-aware linked row
          ? Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (blocked) ...[
                  Row(
                    children: [
                      Icon(
                        Icons.report_gmailerrorred_rounded,
                        size: 16,
                        color: SC.coral,
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          loc(switch (account.status) {
                            'suspended' => 'v2ErrAccountSuspended',
                            'banned' => 'v2ErrAccountBanned',
                            'verification_required' =>
                              'v2ErrAccountVerification',
                            'deletion_pending' => 'v2ErrAccountDeletionPending',
                            'deleted' => 'v2ErrAccountDeleted',
                            _ => 'v2ErrAccountDisabled',
                          }),
                          style: ST.ar(12, color: SC.coral),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Divider(height: 1, color: SC.line),
                  const SizedBox(height: 12),
                ],
                Row(
                  children: [
                    Icon(Icons.verified_rounded, size: 16, color: SC.emerald),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        linkedApple ? loc('linkedApple') : loc('linkedGoogle'),
                        style: ST.ar(13, color: SC.emerald),
                      ),
                    ),
                    SiyagTap(
                      onTap: () => _signOut(context, ref),
                      child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(
                          loc('signOut'),
                          style: ST.ar(13, color: SC.textDim),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            )
          // ── Guest → offer Google (+ Apple on iOS) sign-in ─────────────────
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
                if (appleSupported) ...[
                  const SizedBox(height: 8),
                  SiyagPrimaryButton(
                    label: loc('signInWithApple'),
                    icon: Icons.apple,
                    color: const Color(0xFF1B1D22),
                    busy: signingIn,
                    onTap: () => _signInApple(context, ref),
                  ),
                ],
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
            padding: EdgeInsets.only(
              bottom: MediaQuery.viewInsetsOf(ctx).bottom,
            ),
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
