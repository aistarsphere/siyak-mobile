/// Why a language has no usable word-data release, as the server names it.
///
/// Unknown reasons decode to [unknown] rather than throwing, so a new backend
/// reason cannot break the app.
enum ReleaseUnavailableReason {
  /// `NO_ACTIVE_RELEASE` — nothing is activated for this language right now.
  noActiveRelease,

  /// A reason this build does not recognise.
  unknown;

  static ReleaseUnavailableReason? fromCode(Object? raw) {
    final code = raw?.toString();
    if (code == null || code.isEmpty) return null;
    return code == 'NO_ACTIVE_RELEASE' ? noActiveRelease : unknown;
  }
}

/// Per-language release state from `capabilities_contract.languages.<code>`.
///
/// The backend resolves Arabic by locale and composes Iraq from `ar-MSA` +
/// `ar-IQ`; [releaseId] is whatever it decided, and the client treats it as an
/// **opaque** identifier. Production currently returns a composed id for Arabic
/// (`siyak-ar-msa-…+siyak-ar-iq-…`) and a plain one for English
/// (`siyak-en-2026-07-26-v001`), so no format may be assumed.
class LanguageReleaseState {
  const LanguageReleaseState({
    this.releaseId,
    this.engineReady = false,
    this.unavailableReason,
    this.translationAssistant = false,
    this.semantic = false,
  });

  /// Null when the server reports no release for this language. Never inferred
  /// from another language or from a cached value.
  final String? releaseId;

  final bool engineReady;

  /// Set when [releaseId] is absent; typed so callers need not match strings.
  final ReleaseUnavailableReason? unavailableReason;

  final bool translationAssistant;
  final bool semantic;

  /// Whether this language has a release the server is willing to name.
  bool get hasRelease => (releaseId ?? '').isNotEmpty;
}

/// Result of capability detection. When [available] is false the app keeps V1
/// solo gameplay and shows friendly "unavailable" states for V2 features.
class V2Capabilities {
  const V2Capabilities({
    required this.available,
    this.weeklyEnabled = false,
    this.multiplayerEnabled = false,
    this.adaptiveHintsEnabled = false,
    this.translationAssistantLanguages = const <String>{},
    this.languageReleases = const <String, LanguageReleaseState>{},
    this.apiVersion,
  });

  final bool available;
  final bool weeklyEnabled;
  final bool multiplayerEnabled;
  final bool adaptiveHintsEnabled;

  /// Gameplay-language codes for which the server reports a working translation
  /// assistant, from `capabilities_contract.languages.<code>.translation_assistant`.
  ///
  /// **Per language, not global.** The live contract carries this flag inside each
  /// language entry, and the backend states plainly why it is currently off:
  /// `capabilities_contract.unimplemented.translation_assistant` reads "no
  /// translation service is wired into gameplay".
  ///
  /// This previously read a top-level `features.translation` key, which does not
  /// exist in the contract — so the flag could never have turned on, and the
  /// assistant would have stayed dark even after the backend shipped one.
  /// Fail-closed: an unknown or missing entry means disabled.
  final Set<String> translationAssistantLanguages;
  final String? apiVersion;

  /// Whether the assistant is available for [languageCode] (`ar` / `en`).
  bool translationAssistantFor(String languageCode) =>
      translationAssistantLanguages.contains(languageCode);

  /// Per-language release state, keyed by language code.
  ///
  /// **Deliberately not used to gate gameplay.** Production currently reports
  /// `en` as `NO_ACTIVE_RELEASE` while `/game/languages` marks English ready and
  /// `POST /game/new-game` serves an English release successfully — the two
  /// surfaces disagree. Blocking play on this flag would break a working mode,
  /// so it is exposed for diagnostics and left out of the gameplay path until
  /// the backend reconciles them.
  final Map<String, LanguageReleaseState> languageReleases;

  LanguageReleaseState? releaseFor(String languageCode) =>
      languageReleases[languageCode];

  /// The state used whenever V2 cannot be reached or is not deployed.
  static const unavailable = V2Capabilities(available: false);

  V2Capabilities copyWith({bool? available}) => V2Capabilities(
    available: available ?? this.available,
    weeklyEnabled: weeklyEnabled,
    multiplayerEnabled: multiplayerEnabled,
    adaptiveHintsEnabled: adaptiveHintsEnabled,
    translationAssistantLanguages: translationAssistantLanguages,
    languageReleases: languageReleases,
    apiVersion: apiVersion,
  );
}
