/// Script detection for gameplay input.
///
/// The translation feature itself lives in `translation_suggestion.dart`,
/// `translation_suggestion_repository.dart` and the controller; this file keeps
/// only the character-range detection they share, so there is one answer to
/// "what script is this?" rather than two.
library;

/// Script detection for the assist trigger.
///
/// Deliberately dumb and deterministic: the question is only "is this input
/// written in the other supported script?", which character ranges answer
/// without any network or model.
enum DetectedScript { arabic, latin, mixed, none }

DetectedScript detectScript(String text) {
  var arabic = false;
  var latin = false;
  for (final rune in text.runes) {
    // Arabic *letters* only — the block also holds punctuation (U+061F ؟) and
    // Eastern digits, which must not classify "42؟" as an Arabic word.
    if ((rune >= 0x0621 && rune <= 0x064A) || // core letters
        (rune >= 0x0671 && rune <= 0x06D3) || // extended letters
        (rune >= 0x0750 && rune <= 0x077F) || // supplement
        (rune >= 0x08A0 && rune <= 0x08FF) || // extended-A
        (rune >= 0xFB50 && rune <= 0xFDFF) || // presentation forms A
        (rune >= 0xFE70 && rune <= 0xFEFF)) {
      // presentation forms B
      arabic = true;
    } else if ((rune >= 0x41 && rune <= 0x5A) ||
        (rune >= 0x61 && rune <= 0x7A)) {
      latin = true;
    }
    if (arabic && latin) return DetectedScript.mixed;
  }
  if (arabic) return DetectedScript.arabic;
  if (latin) return DetectedScript.latin;
  return DetectedScript.none;
}
