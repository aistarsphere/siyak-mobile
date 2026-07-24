/// Hint mode chosen before a session. `adaptive` improves the hint based on
/// the player's own best-reached word (`best_user_generated_rank`).
enum HintMode {
  standard,
  adaptive;

  String get code => name;

  static HintMode fromCode(String? code) =>
      code == 'adaptive' ? HintMode.adaptive : HintMode.standard;

  /// Localization key for the mode label.
  String get labelKey =>
      this == HintMode.adaptive ? 'hintAdaptive' : 'hintStandard';

  /// Localization key for the one-line explanation.
  String get explanationKey =>
      this == HintMode.adaptive ? 'hintAdaptiveExplain' : 'hintStandardExplain';
}
