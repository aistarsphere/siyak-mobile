/// Language availability and game-language selection.
///
/// Two separate concerns, kept apart on purpose:
///
/// - [languageCatalogueProvider] — what the *server* says is playable.
/// - [gameLanguageProvider] — what the *player* chose.
///
/// The contract's hardest rule lives in the seam between them: once the player
/// picks a language, availability may change underneath it and the selection
/// must not move. So the catalogue never writes into the selection; the
/// selection reads the catalogue only when it has nothing of its own.
library;

import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';

import '../../../../core/network/api_error.dart';
import '../../data/remote_language_availability_repository.dart';
import '../../domain/languages/game_start_failure.dart';
import '../../domain/languages/language_availability.dart';
import '../../domain/languages/language_availability_repository.dart';
import 'app_settings_controller.dart';
import 'providers.dart';

final languageAvailabilityRepositoryProvider =
    Provider<LanguageAvailabilityRepository>(
      (ref) => RemoteLanguageAvailabilityRepository(
        ref.watch(apiClientProvider),
        ref.watch(sharedPreferencesProvider),
      ),
    );

/// True while an explicit refresh is in flight.
final languageCatalogueRefreshingProvider = StateProvider<bool>((_) => false);

/// The server's language catalogue, refreshed at startup and on demand.
class LanguageCatalogueController extends AsyncNotifier<LanguageCatalogue> {
  LanguageAvailabilityRepository get _repo =>
      ref.read(languageAvailabilityRepositoryProvider);

  @override
  Future<LanguageCatalogue> build() async {
    // A cached catalogue makes the selector appear immediately instead of
    // flashing a spinner over a list that rarely changes. It is a starting
    // frame, not an answer: the fetch below still runs and still wins.
    final cached = _repo.readCached();
    if (cached != null) state = AsyncData(cached);
    return _repo.fetch();
  }

  /// Re-fetches.
  ///
  /// Deliberately does **not** pass through `AsyncLoading`: that would drop the
  /// current catalogue and empty the language selector mid-retry, which is the
  /// one thing the contract says must not happen. In-flight is signalled by
  /// [languageCatalogueRefreshingProvider] instead, so the list stays put and a
  /// spinner sits beside it.
  Future<void> refresh() async {
    final flag = ref.read(languageCatalogueRefreshingProvider.notifier);
    flag.state = true;
    try {
      state = await AsyncValue.guard(_repo.fetch);
    } finally {
      flag.state = false;
    }
  }

  /// Refreshes only when a failure says availability may have moved.
  Future<void> refreshAfter(GameStartFailure failure) async {
    if (failure.shouldRefreshAvailability) await refresh();
  }
}

final languageCatalogueProvider =
    AsyncNotifierProvider<LanguageCatalogueController, LanguageCatalogue>(
      LanguageCatalogueController.new,
    );

/// The chosen gameplay language, and whether the player chose it.
@immutable
class GameLanguageSelection {
  const GameLanguageSelection({required this.code, required this.isExplicit});

  final String code;

  /// True once the player has picked a language themselves. From that moment
  /// the app may never change it for them.
  final bool isExplicit;

  GameLanguageSelection copyWith({String? code, bool? isExplicit}) =>
      GameLanguageSelection(
        code: code ?? this.code,
        isExplicit: isExplicit ?? this.isExplicit,
      );

  @override
  bool operator ==(Object other) =>
      other is GameLanguageSelection &&
      other.code == code &&
      other.isExplicit == isExplicit;

  @override
  int get hashCode => Object.hash(code, isExplicit);
}

/// Owns the selected gameplay language.
class GameLanguageController extends Notifier<GameLanguageSelection> {
  static const _kCode = 'siyaq.gameLanguage';
  static const _kExplicit = 'siyaq.gameLanguage.explicit';

  @override
  GameLanguageSelection build() {
    final sp = ref.watch(sharedPreferencesProvider);
    final saved = sp.getString(_kCode);
    final explicit = sp.getBool(_kExplicit) ?? false;
    final catalogue = ref.watch(languageCatalogueProvider).value;

    // An explicit choice is final. Not re-validated against availability, not
    // re-derived — the player said Arabic, so it stays Arabic even with no
    // release, and they are shown why rather than moved elsewhere.
    if (explicit && saved != null) {
      return GameLanguageSelection(code: saved, isExplicit: true);
    }

    // Before the catalogue lands, hold the saved or UI language so the selector
    // has something coherent to render. This is provisional, never persisted.
    if (catalogue == null || catalogue.isEmpty) {
      return GameLanguageSelection(
        code: saved ?? ref.read(appSettingsProvider).lang,
        isExplicit: false,
      );
    }

    final resolved =
        catalogue.resolveInitial(saved: saved) ??
        saved ??
        ref.read(appSettingsProvider).lang;
    return GameLanguageSelection(code: resolved, isExplicit: false);
  }

  /// The player picked a language. Persisted, and honoured from now on.
  void select(String code) {
    if (state.code == code && state.isExplicit) return;
    final sp = ref.read(sharedPreferencesProvider);
    sp.setString(_kCode, code);
    sp.setBool(_kExplicit, true);
    state = GameLanguageSelection(code: code, isExplicit: true);
  }

  /// Clears the choice so automatic selection applies again. Not wired to any
  /// UI today; exists so "reset" has one correct implementation if it is ever
  /// needed, rather than three approximate ones.
  Future<void> clearExplicit() async {
    final sp = ref.read(sharedPreferencesProvider);
    await sp.remove(_kExplicit);
    ref.invalidateSelf();
  }
}

final gameLanguageProvider =
    NotifierProvider<GameLanguageController, GameLanguageSelection>(
      GameLanguageController.new,
    );

/// What the setup screen should be showing.
///
/// One case per situation the player can actually be in. A single generic empty
/// state was what made "Arabic has no words" indistinguishable from "the network
/// is down" and from "this category is empty" — three problems with three
/// different answers.
enum LanguageSetupStatus {
  /// First load, nothing cached.
  loading,

  /// The selected language is playable.
  ready,

  /// The selected language is supported but has no active release.
  selectedLanguageUnavailable,

  /// Every supported language is unavailable.
  allLanguagesUnavailable,

  /// The catalogue could not be fetched and nothing was cached.
  networkError,
}

@immutable
class LanguageSetupState {
  const LanguageSetupState({
    required this.status,
    required this.catalogue,
    required this.selected,
    this.selectedLanguage,
    this.isRefreshing = false,
  });

  final LanguageSetupStatus status;
  final LanguageCatalogue catalogue;

  /// The selected language code — always populated, even when unavailable.
  final String selected;

  /// The catalogue entry for [selected], when the catalogue knows it.
  final LanguageAvailability? selectedLanguage;

  final bool isRefreshing;

  bool get canPlay => status == LanguageSetupStatus.ready;

  /// Languages other than the selected one that can be played right now — the
  /// basis for a "Choose English" action.
  List<LanguageAvailability> get alternatives => [
    for (final l in catalogue.availableLanguages)
      if (l.code != selected) l,
  ];
}

/// Derives the screen state from the catalogue and the selection.
final languageSetupStateProvider = Provider<LanguageSetupState>((ref) {
  final async = ref.watch(languageCatalogueProvider);
  final selection = ref.watch(gameLanguageProvider);
  final catalogue = async.value ?? LanguageCatalogue.empty;
  final selected = catalogue.byCode(selection.code);

  final status = switch (async) {
    // A hard failure with nothing cached is the only true network error; if a
    // cached catalogue survived, the player can still choose and play.
    AsyncError() when catalogue.isEmpty => LanguageSetupStatus.networkError,
    AsyncLoading() when catalogue.isEmpty => LanguageSetupStatus.loading,
    _ when catalogue.isEmpty => LanguageSetupStatus.loading,
    _ when catalogue.allUnavailable =>
      LanguageSetupStatus.allLanguagesUnavailable,
    _ when selected?.available == true => LanguageSetupStatus.ready,
    _ => LanguageSetupStatus.selectedLanguageUnavailable,
  };

  return LanguageSetupState(
    status: status,
    catalogue: catalogue,
    selected: selection.code,
    selectedLanguage: selected,
    isRefreshing:
        ref.watch(languageCatalogueRefreshingProvider) ||
        (async.isLoading && !catalogue.isEmpty),
  );
});

/// Localisation key for a language's unavailability, chosen from its state.
///
/// The server's `message_key` is deliberately *not* used to index client copy —
/// it names a server-side string, and honouring it would let the backend decide
/// what the app says. It is carried in the model for logging and support.
String unavailableMessageKeyFor(LanguageAvailability language) =>
    switch (language.state) {
      LanguageAvailabilityState.noActiveRelease =>
        language.isArabic ? 'langUnavailableAr' : 'langUnavailableEn',
      LanguageAvailabilityState.releaseLoading => 'langLoadingRelease',
      LanguageAvailabilityState.maintenance => 'langMaintenance',
      LanguageAvailabilityState.runtimeUnavailable => 'langRuntimeUnavailable',
      _ => 'langTemporarilyUnavailable',
    };

/// Whether an error is a transport failure rather than a typed contract one.
bool isTransportFailure(Object? error) =>
    error is ApiException && GameStartFailure.from(error) == null;
