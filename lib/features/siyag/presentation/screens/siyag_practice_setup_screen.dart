/// Solo Practice setup — game language, category and difficulty.
///
/// Implements the Siyaq Language Availability Contract v1 on the client side.
/// The rules that shape this screen:
///
/// - Both supported languages are always visible, available or not.
/// - An explicit choice is never overridden, even when it stops being playable.
/// - "This language has no words" and "this category has no words" are
///   different problems with different answers, so they get different screens.
/// - Play never appears to do nothing: it is disabled with a stated reason, or
///   it runs with a spinner, or it fails with a typed message and an action.
library;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/design/siyaq_design.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../game/domain/languages/game_start_failure.dart';
import '../../../game/domain/languages/language_availability.dart';
import '../../../game/presentation/controllers/app_settings_controller.dart';
import '../../../game/presentation/controllers/game_controller.dart';
import '../../../game/presentation/controllers/language_availability_controller.dart';
import '../../../game/presentation/controllers/providers.dart';
import '../siyag_route.dart';
import 'siyag_practice_game_screen.dart';

final _practiceCatProvider = StateProvider<String?>((ref) => null);
final _practiceDiffProvider = StateProvider<String>((ref) => 'medium');

/// Whether the start call is in flight — a provider rather than a local flag so
/// it cannot be reset by a parent rebuild and double-fire the start action.
final _practiceStartingProvider = StateProvider<bool>((ref) => false);

/// The last typed start failure, or null. Cleared on any change the player makes
/// that could plausibly fix it.
final _practiceFailureProvider = StateProvider<GameStartFailure?>(
  (ref) => null,
);

/// A start failure that was not typed — network trouble and the like.
final _practiceGenericErrorProvider = StateProvider<bool>((ref) => false);

class SiyagPracticeSetupScreen extends ConsumerWidget {
  const SiyagPracticeSetupScreen({super.key});

  void _clearErrors(WidgetRef ref) {
    ref.read(_practiceFailureProvider.notifier).state = null;
    ref.read(_practiceGenericErrorProvider.notifier).state = false;
  }

  void _selectLanguage(WidgetRef ref, String code) {
    ref.read(gameLanguageProvider.notifier).select(code);
    // Categories belong to a language; carrying a selection across would offer
    // an Arabic category code to an English game.
    ref.read(_practiceCatProvider.notifier).state = null;
    _clearErrors(ref);
  }

  Future<void> _refresh(WidgetRef ref) async {
    _clearErrors(ref);
    await ref.read(languageCatalogueProvider.notifier).refresh();
  }

  Future<void> _start(BuildContext context, WidgetRef ref) async {
    if (ref.read(_practiceStartingProvider)) return;

    final setup = ref.read(languageSetupStateProvider);
    if (!setup.canPlay) return;
    final lang = setup.selected;

    final info = ref.read(modesByLanguageProvider(lang)).value;
    if (info == null || info.playable.isEmpty) return;

    final code = ref.read(_practiceCatProvider) ?? info.playable.first.code;
    final cat = info.playable.firstWhere(
      (c) => c.code == code,
      orElse: () => info.playable.first,
    );

    _clearErrors(ref);
    ref.read(_practiceStartingProvider.notifier).state = true;
    try {
      await ref
          .read(gameControllerProvider.notifier)
          .startNewGame(
            // Always explicit. The server would resolve a default if this were
            // omitted, and the player's choice must not depend on that.
            language: lang,
            category: cat.code,
            categoryLabel: cat.labelFor(ref.read(appSettingsProvider).lang),
            difficulty: ref.read(_practiceDiffProvider),
          );
      if (context.mounted) {
        Navigator.of(
          context,
        ).pushReplacement(siyagRoute(const SiyagPracticeGameScreen()));
      }
    } catch (error) {
      // Previously there was no catch at all: a failed start left the button
      // spinning down and nothing else — exactly "Play appears to do nothing".
      final failure = GameStartFailure.from(error);
      if (failure != null) {
        ref.read(_practiceFailureProvider.notifier).state = failure;
        // Availability just contradicted what we had cached, so re-read it
        // rather than leave the screen asserting something the server denies.
        await ref
            .read(languageCatalogueProvider.notifier)
            .refreshAfter(failure);
      } else {
        ref.read(_practiceGenericErrorProvider.notifier).state = true;
      }
    } finally {
      ref.read(_practiceStartingProvider.notifier).state = false;
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final setup = ref.watch(languageSetupStateProvider);
    final starting = ref.watch(_practiceStartingProvider);
    final failure = ref.watch(_practiceFailureProvider);

    return Directionality(
      textDirection: loc.direction,
      child: Scaffold(
        backgroundColor: c.background,
        body: SafeArea(
          bottom: false,
          child: Column(
            children: [
              SiyaqScreenHeader(
                kicker: loc('modeSolo'),
                accent: c.info,
                onBack: () => Navigator.of(context).maybePop(),
                backLabel: loc('back'),
                padding: const EdgeInsets.fromLTRB(
                  SiyaqSpacing.xl,
                  SiyaqSpacing.md,
                  SiyaqSpacing.xl,
                  SiyaqSpacing.sm,
                ),
              ),
              // The selector lives outside every async body. A language that
              // cannot be played is still a language you can select, and the
              // control that switches away from it must never be the thing that
              // disappears when something goes wrong.
              _LanguageSelector(
                setup: setup,
                onSelect: (code) => _selectLanguage(ref, code),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: context.motion.summaryIn,
                  child: _body(ref, loc, c, setup, failure),
                ),
              ),
              _PlayBar(
                setup: setup,
                starting: starting,
                onStart: () => _start(context, ref),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _body(
    WidgetRef ref,
    AppLocalizations loc,
    SiyaqColors c,
    LanguageSetupState setup,
    GameStartFailure? failure,
  ) {
    // A typed failure is the most specific thing we know, so it outranks the
    // catalogue's own view of the world.
    if (failure?.code == GameStartFailureCode.noPlayableSecretsForCategory) {
      return _CategoryEmpty(
        key: const ValueKey('category-empty'),
        onPickAnother: () {
          ref.read(_practiceCatProvider.notifier).state = null;
          _clearErrors(ref);
        },
      );
    }

    switch (setup.status) {
      case LanguageSetupStatus.loading:
        return SiyaqLoader(
          key: const ValueKey('loading'),
          semanticLabel: loc('loading'),
        );

      case LanguageSetupStatus.networkError:
        return SiyaqEmptyState.error(
          key: const ValueKey('network'),
          title: loc('somethingWrong'),
          body: loc('errNetwork'),
          actionLabel: loc('retry'),
          onAction: () => _refresh(ref),
        );

      case LanguageSetupStatus.allLanguagesUnavailable:
        return SiyaqEmptyState(
          key: const ValueKey('all-unavailable'),
          title: loc('langAllUnavailable'),
          body: loc('langAllUnavailableBody'),
          icon: SiyaqIcons.offline,
          actionLabel: loc('retry'),
          onAction: () => _refresh(ref),
        );

      case LanguageSetupStatus.selectedLanguageUnavailable:
        return _LanguageUnavailable(
          key: ValueKey('unavailable-${setup.selected}'),
          setup: setup,
          onChoose: (code) => _selectLanguage(ref, code),
          onRetry: () => _refresh(ref),
        );

      case LanguageSetupStatus.ready:
        return _CategoryAndDifficulty(
          key: ValueKey('ready-${setup.selected}'),
          language: setup.selected,
          onDismissError: () => _clearErrors(ref),
        );
    }
  }
}

/// Always-visible language control, with each option's state attached.
class _LanguageSelector extends ConsumerWidget {
  const _LanguageSelector({required this.setup, required this.onSelect});

  final LanguageSetupState setup;
  final ValueChanged<String> onSelect;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final languages = setup.catalogue.supported;
    if (languages.isEmpty) return const SizedBox.shrink();

    String stateLabel(LanguageAvailability l) {
      if (setup.isRefreshing) return loc('langCheckingAvailability');
      return l.available ? loc('langAvailable') : loc('langTempUnavailable');
    }

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SiyaqSpacing.xl,
        SiyaqSpacing.sm,
        SiyaqSpacing.xl,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: SiyaqText(
                  loc('chooseGameLang'),
                  role: SiyaqTextRole.labelMedium,
                  color: c.textMuted,
                ),
              ),
              if (setup.isRefreshing)
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: c.textMuted,
                  ),
                ),
            ],
          ),
          const SizedBox(height: SiyaqSpacing.sm),
          SiyaqSegmentedControl<String>(
            value: setup.selected,
            accent: c.info,
            onChanged: onSelect,
            segments: [
              for (final l in languages)
                SiyaqSegment(
                  value: l.code,
                  // The language names itself. Never translated.
                  label: l.displayName,
                  // An unavailable option stays selectable — it is marked, not
                  // removed, so the player can inspect why.
                  icon: l.available ? null : SiyaqIcons.offline,
                  semanticLabel: loc.fill('langSelectorA11y', {
                    'lang': l.displayName,
                    'state': stateLabel(l),
                  }),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// The selected language has no words. Keep it selected; explain; offer a way out.
class _LanguageUnavailable extends ConsumerWidget {
  const _LanguageUnavailable({
    super.key,
    required this.setup,
    required this.onChoose,
    required this.onRetry,
  });

  final LanguageSetupState setup;
  final ValueChanged<String> onChoose;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final language = setup.selectedLanguage;
    final key = language == null
        ? 'langTemporarilyUnavailable'
        : unavailableMessageKeyFor(language);

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(
        SiyaqSpacing.xl,
        SiyaqSpacing.xl,
        SiyaqSpacing.xl,
        SiyaqSpacing.xxl,
      ),
      child: Column(
        children: [
          const SizedBox(height: SiyaqSpacing.lg),
          SiyaqIcon.decorative(
            SiyaqIcons.offline,
            size: SiyaqIconSize.lg,
            color: c.textDisabled,
          ),
          const SizedBox(height: SiyaqSpacing.lg),
          SiyaqText(
            loc(key),
            role: SiyaqTextRole.headingSmall,
            color: c.textPrimary,
            align: TextAlign.center,
          ),
          const SizedBox(height: SiyaqSpacing.sm),
          SiyaqText(
            loc('${key}Body'),
            role: SiyaqTextRole.bodyMedium,
            color: c.textMuted,
            align: TextAlign.center,
          ),
          const SizedBox(height: SiyaqSpacing.xl),
          // Switching is an explicit action the player takes, never something
          // the app does for them.
          for (final alt in setup.alternatives) ...[
            SiyaqButton(
              label: loc.fill('chooseLanguageAction', {
                'lang': alt.displayName,
              }),
              accent: c.info,
              fullWidth: true,
              onPressed: () => onChoose(alt.code),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
          ],
          SiyaqButton(
            label: loc('retry'),
            type: SiyaqButtonType.ghost,
            fullWidth: true,
            loading: setup.isRefreshing,
            onPressed: setup.isRefreshing ? null : onRetry,
          ),
        ],
      ),
    );
  }
}

/// The language is fine; this one category has no words.
class _CategoryEmpty extends ConsumerWidget {
  const _CategoryEmpty({super.key, required this.onPickAnother});

  final VoidCallback onPickAnother;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    return SiyaqEmptyState(
      title: loc('catNoWords'),
      body: loc('catNoWordsBody'),
      icon: SiyaqIcons.catGeneral,
      actionLabel: loc('catPickAnother'),
      onAction: onPickAnother,
    );
  }
}

/// Category and difficulty for a language that *is* playable.
class _CategoryAndDifficulty extends ConsumerWidget {
  const _CategoryAndDifficulty({
    super.key,
    required this.language,
    required this.onDismissError,
  });

  /// Category lists are per language — never shared, never reused.
  final String language;
  final VoidCallback onDismissError;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final modes = ref.watch(modesByLanguageProvider(language));
    final genericError = ref.watch(_practiceGenericErrorProvider);

    return modes.when(
      loading: () => SiyaqLoader(semanticLabel: loc('loading')),
      error: (e, _) => SiyaqEmptyState.error(
        title: loc('somethingWrong'),
        body: loc('errNetwork'),
        actionLabel: loc('retry'),
        onAction: () => ref.invalidate(modesByLanguageProvider(language)),
      ),
      data: (info) {
        final cats = info.playable;
        if (cats.isEmpty) {
          // The catalogue says the language is playable but no category is —
          // rare, and still the category story rather than the language one.
          return SiyaqEmptyState(
            title: loc('catNoWords'),
            body: loc('catNoWordsBody'),
            icon: SiyaqIcons.catGeneral,
          );
        }
        final selCat = ref.watch(_practiceCatProvider) ?? cats.first.code;
        final selDiff = ref.watch(_practiceDiffProvider);
        final uiLang = ref.watch(appSettingsProvider.select((s) => s.lang));

        return ListView(
          padding: const EdgeInsets.fromLTRB(
            SiyaqSpacing.xl,
            SiyaqSpacing.lg,
            SiyaqSpacing.xl,
            SiyaqSpacing.xxl,
          ),
          children: [
            if (genericError) ...[
              SiyaqTintedSurface(
                tone: SiyaqTone.error,
                child: Row(
                  children: [
                    Expanded(
                      child: SiyaqText(
                        loc('errNetwork'),
                        role: SiyaqTextRole.bodySmall,
                        color: c.textPrimary,
                      ),
                    ),
                    SiyaqButton(
                      label: loc('retry'),
                      type: SiyaqButtonType.ghost,
                      onPressed: onDismissError,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: SiyaqSpacing.lg),
            ],
            _Label(loc('category')),
            const SizedBox(height: SiyaqSpacing.sm),
            Wrap(
              spacing: SiyaqSpacing.md,
              runSpacing: SiyaqSpacing.md,
              children: [
                for (final cat in cats)
                  SiyaqSelectTile(
                    icon: SiyaqIcons.category(cat.code),
                    label: cat.labelFor(uiLang),
                    selected: cat.code == selCat,
                    accent: c.info,
                    onTap: () => ref.read(_practiceCatProvider.notifier).state =
                        cat.code,
                  ),
              ],
            ),
            const SizedBox(height: SiyaqSpacing.xl),
            _Label(loc('difficulty')),
            const SizedBox(height: SiyaqSpacing.sm),
            SiyaqSegmentedControl<String>(
              value: selDiff,
              accent: c.info,
              onChanged: (d) =>
                  ref.read(_practiceDiffProvider.notifier).state = d,
              segments: [
                SiyaqSegment(value: 'easy', label: loc('diffEasy')),
                SiyaqSegment(value: 'medium', label: loc('diffMedium')),
                SiyaqSegment(value: 'hard', label: loc('diffHard')),
              ],
            ),
          ],
        );
      },
    );
  }
}

/// Start button, plus the reason when it is disabled.
class _PlayBar extends ConsumerWidget {
  const _PlayBar({
    required this.setup,
    required this.starting,
    required this.onStart,
  });

  final LanguageSetupState setup;
  final bool starting;
  final VoidCallback onStart;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final loc = ref.watch(localizationsProvider);
    final c = context.colors;
    final blocked =
        setup.status == LanguageSetupStatus.selectedLanguageUnavailable ||
        setup.status == LanguageSetupStatus.allLanguagesUnavailable;
    final name = setup.selectedLanguage?.displayName ?? setup.selected;

    return Padding(
      padding: const EdgeInsets.fromLTRB(
        SiyaqSpacing.xl,
        SiyaqSpacing.sm,
        SiyaqSpacing.xl,
        SiyaqSpacing.xxl,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // A disabled button with no explanation is indistinguishable from a
          // broken one, so the reason sits right next to it.
          if (blocked) ...[
            Semantics(
              liveRegion: true,
              child: SiyaqText(
                loc.fill('playDisabledReason', {'lang': name}),
                role: SiyaqTextRole.bodySmall,
                color: c.textMuted,
                align: TextAlign.center,
              ),
            ),
            const SizedBox(height: SiyaqSpacing.sm),
          ],
          SiyaqButton(
            label: loc('startGame'),
            icon: SiyaqIcons.play,
            accent: c.info,
            fullWidth: true,
            loading: starting,
            // Disabled while starting: the guard in `_start` stops a double
            // submit, and this stops it from ever being attempted.
            onPressed: setup.canPlay && !starting ? onStart : null,
          ),
        ],
      ),
    );
  }
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => SiyaqText(
    text,
    role: SiyaqTextRole.labelMedium,
    color: context.colors.textMuted,
  );
}
