import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../auth/domain/repositories/auth_repository.dart';
import '../../../auth/presentation/controllers/auth_providers.dart';
import '../../../auth/presentation/controllers/session_controller.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../v2/domain/entities/installation_profile.dart';
import '../../../game/presentation/controllers/game_controller.dart';
import '../../../v2/presentation/controllers/profile_controller.dart';
import '../../../v2/presentation/controllers/release_visibility_controller.dart';
import '../siyag_shell.dart';

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
          // Informational metadata, deliberately last: it is absent most of the
          // time, and placing it after the settings means its appearance can
          // never reflow anything above it.
          const _ReleaseInfoSection(),
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

/// Index of the Profile destination in the shell's `IndexedStack`.
///
/// The shell keeps every tab alive, so nothing remounts when the player switches
/// destinations — "Profile opened" has to be observed from the tab index rather
/// than from `initState`.
const _profileTabIndex = 2;

/// Release/version information, shown only when the backend says so.
///
/// Everything about this section is fail-closed. It renders when — and only
/// when — `GET /release-visibility` returns `visible: true` with something to
/// draw. While loading, on `visible: false`, on a request failure and on a decode
/// failure it occupies **zero height**: no error card, no toast, no retry prompt,
/// no empty section, no spinner. A player who is not eligible cannot tell the
/// feature exists.
///
/// Eligibility is never inferred locally — not from the build type, not from the
/// presence of a session. The server decides and the client obeys.
class _ReleaseInfoSection extends ConsumerWidget {
  const _ReleaseInfoSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Opening Profile re-asks, so an admin policy change lands without an app
    // restart. Invalidating outside the build phase keeps this out of the
    // provider's own dependency cycle.
    ref.listen<int>(siyagTabProvider, (previous, next) {
      if (next == _profileTabIndex && previous != next) {
        ref.invalidate(releaseVisibilityProvider);
      }
    });

    final info = ref.watch(releaseVisibilityProvider).value;
    if (info == null || !info.hasAnythingToShow) return const SizedBox.shrink();

    final loc = ref.watch(localizationsProvider);
    final resolved = info.resolvedRelease;
    final current = info.currentGameRelease;
    final changed = info.releaseChangedForNewGames;

    // Effective release of the running session, straight from the gameplay
    // response. Independent of the visibility payload: a game can be in progress
    // while the policy reports nothing about releases at all.
    final game = ref.watch(gameControllerProvider);
    final sessionRelease = game.releaseId;
    final sessionChanged = game.releaseChanged;

    final rows = <Widget>[
      // Primary row. Documented fallback: display_name, else release_id, else
      // no row at all — never a placeholder.
      if (resolved?.label != null)
        _ReleaseDataRow(
          label: loc('wordDataVersionLabel'),
          value: resolved!.label!,
          emphasise: true,
          mono: resolved.displayName == null,
        ),

      // Optional rows, each rendered only when the server both sent the key and
      // gave it a value. A key omitted by policy and a key that is present-null
      // on a legacy release both render nothing, so neither case reveals itself.
      if (resolved?.datasetVersion.hasValue ?? false)
        _ReleaseDataRow(
          label: loc('datasetVersionLabel'),
          value: resolved!.datasetVersion.value!,
          mono: true,
        ),
      if (resolved?.pack.hasValue ?? false)
        _ReleaseDataRow(
          label: loc('languagePackLabel'),
          value: resolved!.pack.value!,
          mono: true,
        ),
      if (resolved?.releaseId.hasValue ?? false)
        _ReleaseDataRow(
          label: loc('releaseIdLabel'),
          value: resolved!.releaseId.value!,
          mono: true,
        ),
      if (resolved?.sourceCommit.hasValue ?? false)
        _ReleaseDataRow(
          label: loc('sourceCommitLabel'),
          value: resolved!.sourceCommit.value!,
          mono: true,
        ),

      // Only worth naming the new-games release separately once it differs from
      // what the current game is pinned to; otherwise it repeats the row above.
      if (changed && resolved?.label != null)
        _ReleaseDataRow(
          label: loc('newGamesReleaseLabel'),
          value: resolved!.label!,
          mono: resolved.displayName == null,
        ),

      // Components of a composed identity, named for diagnostics. Empty for a
      // plain id, so English (still `siyak-en-…-v001`) shows no extra row.
      for (final part in resolved?.components ?? const <String>[])
        _ReleaseDataRow(
          label: loc('releaseComponentsLabel'),
          value: part,
          mono: true,
        ),

      if (current != null)
        _ReleaseDataRow(
          label: loc('currentGameReleaseLabel'),
          // A game created before release pinning has no recorded release. Say
          // so neutrally — never substitute the resolved release, which would
          // claim the game is on a version it is not.
          value: current.isUnknownLegacy
              ? loc('legacyUnknownReleaseLabel')
              : current.label!,
          mono: !current.isUnknownLegacy && current.displayName == null,
          badge: current.pinned ? loc('currentGamePinnedLabel') : null,
        ),

      // The release the *live gameplay session* is actually pinned to, read from
      // the game controller rather than the policy payload — this is the value
      // that determines the words in front of the player right now. Shown only
      // when a session exists, and still inside the policy-gated section so it
      // cannot leak to an ineligible player.
      if (sessionRelease != null)
        _ReleaseDataRow(
          label: loc('sessionReleaseLabel'),
          value: sessionRelease,
          mono: true,
          badge: sessionChanged ? loc('currentGamePinnedLabel') : null,
        ),

      if (info.lastUpdated != null)
        _ReleaseDataRow(
          label: loc('releaseUpdatedLabel'),
          value: info.lastUpdated!,
          mono: true,
        ),
    ];

    if (rows.isEmpty) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(top: SiyaqSpacing.xl),
      child: _Section(
        label: loc('releaseInfoSectionTitle'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SiyaqSurface(
              padding: const EdgeInsets.symmetric(
                horizontal: SiyaqSpacing.lg,
                vertical: SiyaqSpacing.smd,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: rows,
              ),
            ),
            if (changed) ...[
              const SizedBox(height: SiyaqSpacing.smd),
              // Informational, not a warning: nothing is wrong and nothing was
              // migrated. The current game simply keeps the version it was
              // created with, which is the documented pinning guarantee.
              SiyaqTintedSurface(
                tone: SiyaqTone.info,
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    SiyaqIcon.decorative(
                      SiyaqIcons.info,
                      size: SiyaqIconSize.sm,
                      color: context.colors.info,
                    ),
                    const SizedBox(width: SiyaqSpacing.sm),
                    Expanded(
                      child: SiyaqText(
                        loc('releaseChangedForNewGamesMessage'),
                        role: SiyaqTextRole.bodySmall,
                        color: context.colors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

/// One `label — value` line of release metadata.
///
/// Machine-readable values (ids, dataset versions, packs, commits) render in the
/// mono face so they stay legible in both scripts and never reflow with the
/// surrounding Arabic or Latin text.
class _ReleaseDataRow extends StatelessWidget {
  const _ReleaseDataRow({
    required this.label,
    required this.value,
    this.mono = false,
    this.emphasise = false,
    this.badge,
  });

  final String label;
  final String value;
  final bool mono;
  final bool emphasise;

  /// Small trailing tag, e.g. the pinned marker on the current-game row.
  final String? badge;

  @override
  Widget build(BuildContext context) {
    final c = context.colors;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: SiyaqSpacing.xs),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            flex: 4,
            child: SiyaqText(
              label,
              role: SiyaqTextRole.bodySmall,
              color: c.textMuted,
            ),
          ),
          const SizedBox(width: SiyaqSpacing.sm),
          Expanded(
            flex: 6,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                mono
                    ? SiyaqText.numeric(
                        value,
                        role: SiyaqTextRole.bodySmall,
                        color: emphasise ? c.textPrimary : c.textSecondary,
                        align: TextAlign.end,
                        maxLines: 2,
                      )
                    : SiyaqText(
                        value,
                        role: emphasise
                            ? SiyaqTextRole.bodyMedium
                            : SiyaqTextRole.bodySmall,
                        weight: emphasise ? FontWeight.w600 : null,
                        color: emphasise ? c.textPrimary : c.textSecondary,
                        align: TextAlign.end,
                        maxLines: 2,
                      ),
                if (badge != null) ...[
                  const SizedBox(height: SiyaqSpacing.xxs),
                  SiyaqText(
                    badge!,
                    role: SiyaqTextRole.labelSmall,
                    color: c.textMuted,
                    align: TextAlign.end,
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}
