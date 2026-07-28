/// Result of capability detection. When [available] is false the app keeps V1
/// solo gameplay and shows friendly "unavailable" states for V2 features.
class V2Capabilities {
  const V2Capabilities({
    required this.available,
    this.weeklyEnabled = false,
    this.multiplayerEnabled = false,
    this.adaptiveHintsEnabled = false,
    this.translationAssistantLanguages = const <String>{},
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

  /// The state used whenever V2 cannot be reached or is not deployed.
  static const unavailable = V2Capabilities(available: false);

  V2Capabilities copyWith({bool? available}) => V2Capabilities(
    available: available ?? this.available,
    weeklyEnabled: weeklyEnabled,
    multiplayerEnabled: multiplayerEnabled,
    adaptiveHintsEnabled: adaptiveHintsEnabled,
    translationAssistantLanguages: translationAssistantLanguages,
    apiVersion: apiVersion,
  );
}
