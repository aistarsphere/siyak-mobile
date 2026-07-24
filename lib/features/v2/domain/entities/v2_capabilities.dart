/// Result of capability detection. When [available] is false the app keeps V1
/// solo gameplay and shows friendly "unavailable" states for V2 features.
class V2Capabilities {
  const V2Capabilities({
    required this.available,
    this.weeklyEnabled = false,
    this.multiplayerEnabled = false,
    this.adaptiveHintsEnabled = false,
    this.apiVersion,
  });

  final bool available;
  final bool weeklyEnabled;
  final bool multiplayerEnabled;
  final bool adaptiveHintsEnabled;
  final String? apiVersion;

  /// The state used whenever V2 cannot be reached or is not deployed.
  static const unavailable = V2Capabilities(available: false);

  V2Capabilities copyWith({bool? available}) => V2Capabilities(
    available: available ?? this.available,
    weeklyEnabled: weeklyEnabled,
    multiplayerEnabled: multiplayerEnabled,
    adaptiveHintsEnabled: adaptiveHintsEnabled,
    apiVersion: apiVersion,
  );
}
