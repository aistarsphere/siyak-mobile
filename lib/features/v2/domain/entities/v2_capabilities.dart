/// Result of capability detection. When [available] is false the app keeps V1
/// solo gameplay and shows friendly "unavailable" states for V2 features.
class V2Capabilities {
  const V2Capabilities({
    required this.available,
    this.weeklyEnabled = false,
    this.multiplayerEnabled = false,
    this.adaptiveHintsEnabled = false,
    this.translationEnabled = false,
    this.apiVersion,
  });

  final bool available;
  final bool weeklyEnabled;
  final bool multiplayerEnabled;
  final bool adaptiveHintsEnabled;

  /// Gameplay translation assistant (`features.translation`). No backend ships
  /// this yet — fail-closed like every flag, so the feature stays invisible
  /// until the contract in docs/TRANSLATION_CONTRACT.md is implemented.
  final bool translationEnabled;
  final String? apiVersion;

  /// The state used whenever V2 cannot be reached or is not deployed.
  static const unavailable = V2Capabilities(available: false);

  V2Capabilities copyWith({bool? available}) => V2Capabilities(
    available: available ?? this.available,
    weeklyEnabled: weeklyEnabled,
    multiplayerEnabled: multiplayerEnabled,
    adaptiveHintsEnabled: adaptiveHintsEnabled,
    translationEnabled: translationEnabled,
    apiVersion: apiVersion,
  );
}
