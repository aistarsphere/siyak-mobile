/// ─── Arabic → English guess translation ──────────────────────────────────────
///
/// Helps a player who is playing an **English** game but thinks of a word in
/// Arabic. It never guesses for them: it offers candidates, the player picks one,
/// and only that English word enters the normal guess flow.
///
/// Ambiguity is the point. `ذهب` is *gold* and *went* and *go*; presenting one
/// translation would quietly make a semantic choice on the player's behalf, so
/// the model carries several senses and the UI shows them.
library;

import 'package:flutter/foundation.dart';

import '../../../v2/domain/entities/gameplay_language.dart';
import 'translation_service.dart' show DetectedScript, detectScript;

/// One candidate English word for an Arabic source.
///
/// Only [text] is required. Everything else is optional because the client must
/// work against a backend that returns nothing but a list of strings — the
/// richer fields are used when present and ignored when absent.
@immutable
class TranslationSuggestion {
  const TranslationSuggestion({
    required this.text,
    this.sense,
    this.confidence,
    this.label,
    this.inActiveVocabulary,
  });

  /// The English word to submit. One word wherever possible.
  final String text;

  /// Part of speech, e.g. `noun` / `verb`. Display hint only.
  final String? sense;

  /// 0–1 backend confidence. Used for ordering when the server does not already
  /// order, never shown as a number.
  final double? confidence;

  /// Short Arabic gloss distinguishing this sense, e.g. `ذهب كمعدن`. Rendered
  /// RTL beside the LTR English word.
  final String? label;

  /// Whether the word exists in the active gameplay vocabulary.
  ///
  /// Sent by the live backend as `in_active_vocabulary`. A translation the game
  /// will reject is a worse suggestion than one it accepts, so this orders the
  /// list — it never hides anything, because the player may still want the word
  /// they meant. Null when the backend does not say.
  final bool? inActiveVocabulary;

  /// Decodes one suggestion.
  ///
  /// Accepts both spellings of the optional fields. The deployed backend sends
  /// `part_of_speech` and `sense_label`; the drafted contract used `sense` and
  /// `label`. Reading either means neither side has to break to agree, and a
  /// mismatch degrades to a bare word rather than silently dropping the sense.
  factory TranslationSuggestion.fromJson(Map<String, dynamic> json) {
    String? str(String a, String b) =>
        (json[a] as Object?)?.toString() ?? (json[b] as Object?)?.toString();
    return TranslationSuggestion(
      text: (json['text'] ?? '').toString().trim(),
      sense: str('part_of_speech', 'sense'),
      confidence: switch (json['confidence']) {
        final num n => n.toDouble(),
        _ => null,
      },
      label: str('sense_label', 'label'),
      inActiveVocabulary: switch (json['in_active_vocabulary']) {
        final bool b => b,
        _ => null,
      },
    );
  }

  bool get isUsable => text.isNotEmpty;

  @override
  bool operator ==(Object other) =>
      other is TranslationSuggestion &&
      other.text == text &&
      other.sense == sense &&
      other.confidence == confidence &&
      other.label == label &&
      other.inActiveVocabulary == inActiveVocabulary;

  @override
  int get hashCode =>
      Object.hash(text, sense, confidence, label, inActiveVocabulary);

  @override
  String toString() => 'TranslationSuggestion($text)';
}

/// Where a set of suggestions is in its lifecycle.
enum TranslationPhase {
  /// Nothing to do: not an English game, no Arabic typed, or the field is empty.
  idle,

  /// Arabic seen; waiting out the debounce before asking.
  debouncing,

  /// A request is in flight.
  loading,

  /// Suggestions arrived and there is at least one.
  success,

  /// The request succeeded but the backend knows no translation.
  empty,

  /// The request failed or timed out.
  error,

  /// The player closed the panel for this exact input.
  dismissed,
}

/// Immutable state of the suggestion panel.
@immutable
class TranslationSuggestionState {
  const TranslationSuggestionState({
    this.phase = TranslationPhase.idle,
    this.sourceText = '',
    this.suggestions = const [],
    this.expanded = false,
  });

  static const initial = TranslationSuggestionState();

  final TranslationPhase phase;

  /// The Arabic text these suggestions belong to, exactly as typed.
  final String sourceText;

  final List<TranslationSuggestion> suggestions;

  /// Whether "more translations" has been opened.
  final bool expanded;

  /// How many chips the panel shows before the expansion.
  static const collapsedCount = 6;

  /// Suggestions to render right now.
  List<TranslationSuggestion> get visible =>
      expanded || suggestions.length <= collapsedCount
      ? suggestions
      : suggestions.take(collapsedCount).toList();

  /// Whether a "more translations" affordance is warranted.
  bool get hasMore => !expanded && suggestions.length > collapsedCount;

  /// Whether the panel should occupy any space at all.
  ///
  /// [TranslationPhase.debouncing] deliberately renders nothing: showing a
  /// spinner between keystrokes makes the field feel busy while the player is
  /// still typing.
  bool get isVisible => switch (phase) {
    TranslationPhase.idle ||
    TranslationPhase.dismissed ||
    TranslationPhase.debouncing => false,
    _ => true,
  };

  TranslationSuggestionState copyWith({
    TranslationPhase? phase,
    String? sourceText,
    List<TranslationSuggestion>? suggestions,
    bool? expanded,
  }) => TranslationSuggestionState(
    phase: phase ?? this.phase,
    sourceText: sourceText ?? this.sourceText,
    suggestions: suggestions ?? this.suggestions,
    expanded: expanded ?? this.expanded,
  );
}

/// Pure rules for when the assistant may run and what it may ask about.
abstract final class TranslationGate {
  /// Longest input worth translating.
  ///
  /// A guess is one word; the cap stops a paste of prose becoming a translation
  /// request, which is both useless and the obvious abuse vector.
  static const maxSourceLength = 32;

  /// Most words accepted — a short expression at most.
  static const maxWords = 3;

  /// Whether the assistant applies at all.
  ///
  /// **English games only.** The reverse direction (Latin typed into an Arabic
  /// game) is deliberately excluded: an Arabic game must not sprout an English
  /// panel, and this feature is scoped to helping an Arabic speaker play in
  /// English.
  static bool appliesTo({
    required GameplayLanguage gameLanguage,
    required String text,
  }) {
    if (gameLanguage != GameplayLanguage.english) return false;
    final trimmed = text.trim();
    if (trimmed.isEmpty) return false;
    if (!isWithinLimits(trimmed)) return false;
    // Mixed or Latin input is the player typing English already.
    return detectScript(trimmed) == DetectedScript.arabic;
  }

  /// Whether [text] is short enough to be a guess rather than a document.
  static bool isWithinLimits(String text) {
    final trimmed = text.trim();
    if (trimmed.length > maxSourceLength) return false;
    return trimmed.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).length <=
        maxWords;
  }

  /// Cache/request key for an Arabic source.
  ///
  /// Folds the orthographic variation that does not change meaning, so `أستاذ`
  /// and `استاذ` are one request rather than two. Mirrors the normalisation the
  /// design prototype applies before comparing Arabic words.
  static String normalize(String text) {
    var s = text.trim();
    // Harakat and dagger alef.
    s = s.replaceAll(RegExp('[ً-ْٰ]'), '');
    s = s.replaceAll(RegExp('[أإآ]'), 'ا');
    s = s.replaceAll('ى', 'ي');
    s = s.replaceAll('ة', 'ه');
    // Tatweel, and collapse internal whitespace.
    s = s.replaceAll('ـ', '');
    s = s.replaceAll(RegExp(r'\s+'), ' ');
    return s;
  }

  /// Orders and trims a raw suggestion list.
  ///
  /// De-duplicates case-insensitively, drops empties, and sorts by confidence
  /// **only when the backend supplied it** — otherwise the server's own order is
  /// authoritative, since it knows which sense is most common.
  static List<TranslationSuggestion> refine(
    List<TranslationSuggestion> raw, {
    int limit = 12,
  }) {
    final seen = <String>{};
    final out = <TranslationSuggestion>[];
    for (final s in raw) {
      if (!s.isUsable) continue;
      if (!seen.add(s.text.toLowerCase())) continue;
      out.add(s);
    }
    final scored = out.where((s) => s.confidence != null).length;
    if (scored == out.length && out.length > 1) {
      out.sort((a, b) => b.confidence!.compareTo(a.confidence!));
    }
    // A word the game does not know would be rejected on submit, so it sinks
    // below the playable ones. Stable, so the ranking above survives within each
    // group, and nothing is removed — the player may still mean that word.
    final known = out.where((s) => s.inActiveVocabulary != false).toList();
    final unknown = out.where((s) => s.inActiveVocabulary == false).toList();
    final ordered = [...known, ...unknown];
    return ordered.length > limit ? ordered.sublist(0, limit) : ordered;
  }
}
