import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/installation_profile.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';

/// Profile: identity, stats, account link, appearance and language.
///
/// The identity block is **account-aware**: signed in → the account's public
/// name/avatar and stable `SYG-XXXXX` id (editable via `PATCH /account/me`);
/// guest → the anonymous installation profile (editable via `PATCH /profiles/me`).
/// Stats are real; the raw installation id stays hidden.
///
/// Built entirely from the Siyaq design system — no screen-local cards, pills,
/// selectors or text styles. Behaviour, providers and API calls are unchanged
/// from the pre-migration implementation.
class SiyagProfileScreen extends ConsumerWidget {
  const SiyagProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profileState = ref.watch(profileControllerProvider);
    final profile = profileState.value;
    final loc = ref.watch(localizationsProvider);

    return Directionality(
      textDirection: loc.direction,
      child: ListView(
        padding: const EdgeInsets.symmetric(
          horizontal: SiyaqSpacing.xxl,
          vertical: SiyaqSpacing.huge,
        ),
        children: [
          _IdentityHeader(profile: profile),
          const SizedBox(height: SiyaqSpacing.xxl),
          _StatsSection(profile: profile, loading: profileState.isLoading),
          const SizedBox(height: SiyaqSpacing.xxl),
          const _AccountSection(),
          const SizedBox(height: SiyaqSpacing.xxl),
          const _IdentityNote(),
          const SizedBox(height: SiyaqSpacing.xxxl),
          const _AppearanceSelector(),
          const SizedBox(height: SiyaqSpacing.xl),
          const _LanguageSelector(),
          const SizedBox(height: SiyaqSpacing.xl),
          const _FeedbackToggles(),
        ],
      ),
    );
  }
}

/// A labelled settings group: kicker + content.
class _Section extends StatelessWidget {
  const _Section({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      SiyaqText(
        label.toUpperCase(),
        role: SiyaqTextRole.labelSmall,
        script: SiyaqScript.mono,
        color: context.colors.textMuted,
      ),
      const SizedBox(height: SiyaqSpacing.smd),
      child,
    ],
  );
}

/// Avatar + name + edit action + (when signed in) the public `SYG-XXXXX` id.
class _IdentityHeader extends ConsumerWidget {
  const _IdentityHeader({required this.profile});
  final InstallationProfile? profile;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final account = ref.watch(sessionControllerProvider).asData?.value.account;
    final signedIn = account != null;

    final name = signedIn ? account.effectiveName : (profile?.label ?? '—');

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

    return Column(
      children: [
        SiyaqAvatar(
          name: name,
          imageUrl: signedIn ? account.avatarUrl : null,
          size: SiyaqAvatarSize.xlarge,
        ),
        const SizedBox(height: SiyaqSpacing.lg),
        SiyaqText(
          name,
          role: SiyaqTextRole.headingLarge,
          align: TextAlign.center,
        ),
        const SizedBox(height: SiyaqSpacing.xs),
        SiyaqButton(
          label: loc('editName'),
          icon: SiyaqIcons.edit,
          type: SiyaqButtonType.ghost,
          size: SiyaqButtonSize.medium,
          onPressed: onEdit,
        ),
        if (signedIn) ...[
          const SizedBox(height: SiyaqSpacing.sm),
          _PlayerIdChip(id: account.publicPlayerId),
        ],
      ],
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
    return SiyaqChip(
      label: id,
      numeric: true,
      icon: SiyaqIcons.playerId,
      trailingIcon: SiyaqIcons.copy,
      semanticLabel: '${loc('playerId')}: $id',
      semanticHint: loc('copyHint'),
      onTap: () async {
        await Clipboard.setData(ClipboardData(text: id));
        if (context.mounted) {
          ScaffoldMessenger.of(context)
            ..hideCurrentSnackBar()
            ..showSnackBar(SnackBar(content: Text(loc('idCopied'))));
        }
      },
    );
  }
}

/// Four real stats, laid out so they reflow rather than overflow.
class _StatsSection extends ConsumerWidget {
  const _StatsSection({required this.profile, required this.loading});

  final InstallationProfile? profile;
  final bool loading;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final best = profile?.weeklyBestPlacement;

    return SiyaqStatGrid(
      children: [
        SiyaqStatCard(
          value: profile == null ? null : '${profile!.gamesPlayed}',
          label: loc('gamesPlayed'),
          loading: loading,
          semanticLabel: '${loc('gamesPlayed')}: ${profile?.gamesPlayed ?? 0}',
        ),
        SiyaqStatCard(
          value: profile == null ? null : '${profile!.gamesSolved}',
          label: loc('gamesSolved'),
          loading: loading,
          semanticLabel: '${loc('gamesSolved')}: ${profile?.gamesSolved ?? 0}',
        ),
        SiyaqStatCard(
          value: profile == null ? null : '${profile!.roomsWon}',
          label: loc('roomsWon'),
          loading: loading,
          semanticLabel: '${loc('roomsWon')}: ${profile?.roomsWon ?? 0}',
        ),
        SiyaqStatCard(
          value: best != null ? '#$best' : null,
          label: loc('bestLabel'),
          loading: loading,
          // A podium finish is the one stat worth accenting.
          accent: best != null && best <= 3 ? context.colors.primary : null,
          semanticLabel: best != null
              ? '${loc('bestLabel')}: $best'
              : loc('bestLabel'),
        ),
      ],
    );
  }
}

/// Account section: real Google/Apple sign-in (guest) or a linked/sign-out row
/// (signed in). Uses the existing [SessionController]; on a real authentication
/// failure it surfaces the error (never a silent guest fallback).
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
    final ok = await showSiyaqConfirm(
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

    if (!signedIn) {
      // ── Guest → offer Google (+ Apple on iOS) sign-in ─────────────────────
      return _Section(
        label: loc('account'),
        child: SiyaqSurface(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SiyaqText(
                loc('signInBenefit'),
                role: SiyaqTextRole.bodyMedium,
                color: context.colors.textSecondary,
              ),
              const SizedBox(height: SiyaqSpacing.md),
              SiyaqButton(
                label: loc('signInWithGoogle'),
                icon: SiyaqIcons.signIn,
                fullWidth: true,
                loading: signingIn,
                onPressed: () => _signIn(context, ref),
              ),
              if (appleSupported) ...[
                const SizedBox(height: SiyaqSpacing.sm),
                SiyaqButton(
                  label: loc('signInWithApple'),
                  icon: SiyaqIcons.apple,
                  // Apple's brand guidelines mandate this fill; the label colour
                  // is derived by measured contrast, not chosen here.
                  accent: SiyaqColors.graphiteDeep,
                  fullWidth: true,
                  loading: signingIn,
                  onPressed: () => _signInApple(context, ref),
                ),
              ],
            ],
          ),
        ),
      );
    }

    // ── Signed in → optional blocked banner + linked row + sign out ─────────
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (blocked) ...[
          SiyaqTintedSurface(
            tone: SiyaqTone.warning,
            child: Row(
              children: [
                Icon(
                  SiyaqIcons.warning,
                  size: SiyaqIconSize.md,
                  color: context.colors.warning,
                ),
                const SizedBox(width: SiyaqSpacing.sm),
                Expanded(
                  child: SiyaqText(
                    loc(switch (account.status) {
                      'suspended' => 'v2ErrAccountSuspended',
                      'banned' => 'v2ErrAccountBanned',
                      'verification_required' => 'v2ErrAccountVerification',
                      'deletion_pending' => 'v2ErrAccountDeletionPending',
                      'deleted' => 'v2ErrAccountDeleted',
                      _ => 'v2ErrAccountDisabled',
                    }),
                    role: SiyaqTextRole.bodySmall,
                    color: context.colors.warning,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: SiyaqSpacing.sm),
        ],
        SiyaqListRow(
          leadingIcon: SiyaqIcons.verified,
          leadingColor: context.colors.success,
          title: linkedApple ? loc('linkedApple') : loc('linkedGoogle'),
          trailing: SiyaqButton(
            label: loc('signOut'),
            type: SiyaqButtonType.secondary,
            size: SiyaqButtonSize.medium,
            onPressed: () => _signOut(context, ref),
          ),
        ),
      ],
    );
  }
}

/// Privacy/status footer: adapts to guest (anonymous, device-only) vs. signed-in
/// (progress syncs to the account).
class _IdentityNote extends ConsumerWidget {
  const _IdentityNote();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final signedIn =
        ref.watch(sessionControllerProvider).asData?.value.account != null;
    return SiyaqSurface(
      variant: SiyaqSurfaceVariant.outlined,
      child: Row(
        children: [
          Icon(
            signedIn ? SiyaqIcons.synced : SiyaqIcons.privacy,
            size: SiyaqIconSize.md,
            color: context.colors.textMuted,
          ),
          const SizedBox(width: SiyaqSpacing.smd),
          Expanded(
            child: SiyaqText(
              signedIn ? loc('signedInNote') : loc('guestIdentityNote'),
              role: SiyaqTextRole.bodySmall,
              color: context.colors.textMuted,
            ),
          ),
        ],
      ),
    );
  }
}

/// Shared sheet for editing a display name (guest profile, account edit, and the
/// one-shot welcome setup). [onSave] performs the actual persistence.
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
  await SiyaqSheet.show<void>(
    context: context,
    direction: loc.direction,
    builder: (ctx) {
      var saving = false;
      return StatefulBuilder(
        builder: (ctx, setSheet) => SiyaqSheet(
          title: title,
          body: body,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SiyaqTextField(
                controller: controller,
                hint: loc('nameHint'),
                maxLength: 24,
                autofocus: true,
                textInputAction: TextInputAction.done,
              ),
              const SizedBox(height: SiyaqSpacing.md),
              SiyaqButton(
                label: loc('save'),
                icon: SiyaqIcons.correct,
                fullWidth: true,
                loading: saving,
                onPressed: () async {
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
                const SizedBox(height: SiyaqSpacing.sm),
                SiyaqButton(
                  label: loc('skip'),
                  type: SiyaqButtonType.ghost,
                  fullWidth: true,
                  onPressed: () {
                    onSkip?.call();
                    Navigator.of(ctx).pop();
                  },
                ),
              ],
            ],
          ),
        ),
      );
    },
  );
}

/// System / Light / Dark selector. Persists via [AppSettings] and applies
/// immediately (no restart).
class _AppearanceSelector extends ConsumerWidget {
  const _AppearanceSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final mode = ref.watch(appSettingsProvider.select((s) => s.themeMode));
    return _Section(
      label: loc('appearance'),
      child: SiyaqSegmentedControl<ThemeMode>(
        value: mode,
        onChanged: ref.read(appSettingsProvider.notifier).setThemeMode,
        segments: [
          SiyaqSegment(
            value: ThemeMode.system,
            label: loc('themeSystem'),
            icon: SiyaqIcons.themeSystem,
          ),
          SiyaqSegment(
            value: ThemeMode.light,
            label: loc('themeLight'),
            icon: SiyaqIcons.themeLight,
          ),
          SiyaqSegment(
            value: ThemeMode.dark,
            label: loc('themeDark'),
            icon: SiyaqIcons.themeDark,
          ),
        ],
      ),
    );
  }
}

/// Sound and haptic feedback preferences.
///
/// The settings themselves have existed (persisted) since the first release;
/// they were never *rendered*, which made the sound preference dead and the
/// haptics one uncontrollable. Both gate the whole feedback pipeline via
/// [SiyaqFeedbackScope] and [FeedbackService].
class _FeedbackToggles extends ConsumerWidget {
  const _FeedbackToggles();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final sound = ref.watch(appSettingsProvider.select((s) => s.sound));
    final haptics = ref.watch(appSettingsProvider.select((s) => s.haptics));
    final notifier = ref.read(appSettingsProvider.notifier);

    SiyaqSegmentedControl<bool> toggle(
      bool value,
      ValueChanged<bool> onChanged,
    ) => SiyaqSegmentedControl<bool>(
      value: value,
      onChanged: onChanged,
      segments: [
        SiyaqSegment(value: true, label: loc('settingOn')),
        SiyaqSegment(value: false, label: loc('settingOff')),
      ],
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _Section(label: loc('sound'), child: toggle(sound, notifier.setSound)),
        const SizedBox(height: SiyaqSpacing.xl),
        _Section(
          label: loc('haptics'),
          child: toggle(haptics, notifier.setHaptics),
        ),
      ],
    );
  }
}

/// App-language selector (Arabic / English) — the only control that switches the
/// whole UI between the two complete localized experiences.
class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final lang = ref.watch(appSettingsProvider.select((s) => s.lang));
    return _Section(
      label: loc('languageLabel'),
      child: SiyaqSegmentedControl<String>(
        value: lang,
        onChanged: ref.read(appSettingsProvider.notifier).setLang,
        segments: [
          SiyaqSegment(value: 'ar', label: loc('langArabic')),
          SiyaqSegment(value: 'en', label: loc('langEnglish')),
        ],
      ),
    );
  }
}
