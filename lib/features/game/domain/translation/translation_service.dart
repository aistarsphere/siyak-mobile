import 'package:flutter/foundation.dart';

import '../../../v2/domain/entities/gameplay_language.dart';

/// One translation suggestion in the gameplay language.
@immutable
class TranslationCandidate {
  const TranslationCandidate({required this.word, required this.source});

  /// The candidate word, in the *target* (gameplay) language.
  final String word;

  /// Where this candidate came from (`dev-fixture`, later `server`). Kept so
  /// the UI and logs can always distinguish a development suggestion from a
  /// production one.
  final String source;

  @override
  bool operator ==(Object other) =>
      other is TranslationCandidate &&
      other.word == word &&
      other.source == source;

  @override
  int get hashCode => Object.hash(word, source);
}

/// Boundary for the gameplay translation assistant.
///
/// The player picked one gameplay language but may *think* in another; this
/// service maps their input into candidates in the gameplay language. The
/// player always chooses explicitly — nothing here submits anything, and the
/// selected word still goes through the normal guess path where the **server**
/// validates it against the vocabulary.
///
/// Language pairs are open-ended by design: [suggest] takes `from`/`to` codes,
/// so adding a pair later is an adapter concern, not an interface change.
///
/// ## Production status
///
/// **The backend has no translation capability yet** (verified against
/// `GET /capabilities`). The only adapter that exists is
/// [DevTranslationAdapter], a deterministic fixture used in debug builds and
/// tests. The required backend contract is documented in
/// `docs/TRANSLATION_CONTRACT.md`; a remote adapter plugs in here once it
/// ships, gated by the `translation` capability flag.
abstract class TranslationService {
  /// Candidates for [text] translated from [from] into [to]. Empty when
  /// nothing is known — the UI states that rather than guessing.
  Future<List<TranslationCandidate>> suggest({
    required String text,
    required GameplayLanguage from,
    required GameplayLanguage to,
  });
}

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

/// True when [text] is written entirely in the *other* supported script from
/// the game's — the moment the assistant has something to offer. Mixed or
/// script-less input (digits, punctuation) never triggers.
bool isLikelyOtherLanguage(String text, GameplayLanguage gameLanguage) {
  final t = text.trim();
  if (t.length < 2) return false;
  return switch (detectScript(t)) {
    DetectedScript.arabic => !gameLanguage.isArabic,
    DetectedScript.latin => gameLanguage.isArabic,
    _ => false,
  };
}

/// Deterministic fixture translator for development and tests.
///
/// **Never a production translator** — the dictionary is a small fixed table so
/// the whole assist flow (detection → candidates → explicit pick → normal
/// server-validated submit) can be built and QA'd before the backend ships.
/// Clearly named, clearly sourced (`source: 'dev-fixture'`), and only reachable
/// in debug builds.
class DevTranslationAdapter implements TranslationService {
  const DevTranslationAdapter();

  /// Arabic → English candidates. English → Arabic is served by inverting.
  static const Map<String, List<String>> _arToEn = {
    'سيارة': ['car', 'vehicle', 'automobile'],
    'كتاب': ['book'],
    'ماء': ['water'],
    'بيت': ['house', 'home'],
    'قطة': ['cat'],
    'كلب': ['dog'],
    'شمس': ['sun'],
    'قمر': ['moon'],
    'بحر': ['sea', 'ocean'],
    'جبل': ['mountain'],
    'مدرسة': ['school'],
    'مدينة': ['city', 'town'],
    'طعام': ['food'],
    'خبز': ['bread'],
    'شجرة': ['tree'],
    'زهرة': ['flower'],
    'طائر': ['bird'],
    'سمكة': ['fish'],
    'نار': ['fire'],
    'ثلج': ['snow', 'ice'],
    'مطر': ['rain'],
    'ريح': ['wind'],
    'ليل': ['night'],
    'نهار': ['day', 'daytime'],
    'قلب': ['heart'],
    'يد': ['hand'],
    'عين': ['eye'],
    'باب': ['door'],
    'نافذة': ['window'],
    'مكتبة': ['library', 'bookshop'],
  };

  static final Map<String, List<String>> _enToAr = _invert(_arToEn);

  static Map<String, List<String>> _invert(Map<String, List<String>> m) {
    final out = <String, List<String>>{};
    m.forEach((ar, ens) {
      for (final en in ens) {
        out.putIfAbsent(en, () => []).add(ar);
      }
    });
    return out;
  }

  @override
  Future<List<TranslationCandidate>> suggest({
    required String text,
    required GameplayLanguage from,
    required GameplayLanguage to,
  }) async {
    final key = text.trim();
    final table = from.isArabic ? _arToEn : _enToAr;
    final hits = table[key] ?? table[key.toLowerCase()] ?? const <String>[];
    return [
      for (final w in hits)
        TranslationCandidate(word: w, source: 'dev-fixture'),
    ];
  }
}
