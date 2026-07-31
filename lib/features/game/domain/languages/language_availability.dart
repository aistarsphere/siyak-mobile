/// Siyaq Language Availability Contract v1 — client model.
///
/// The governing idea: **availability is per language, and an unavailable
/// language is still a language.** Arabic having no word release must not hide
/// Arabic, must not switch the player to English behind their back, and must not
/// make the game look broken. So nothing here can express "this language is
/// gone" — only "this language is not ready, and here is why".
///
/// [available] is readiness; [state] is the reason. They are separate because a
/// client that only knows *not ready* can only say something vague, whereas one
/// that knows `NO_ACTIVE_RELEASE` can say what is actually wrong.
library;

import 'package:flutter/foundation.dart';

/// Why a language is or is not playable, as the server names it.
///
/// Unknown values decode to [unknown] rather than throwing: the backend may add
/// a state before this build knows about it, and a new reason must never crash
/// the language selector.
enum LanguageAvailabilityState {
  activeManaged('ACTIVE_MANAGED'),
  legacyFallbackActive('LEGACY_FALLBACK_ACTIVE'),
  noActiveRelease('NO_ACTIVE_RELEASE'),
  runtimeUnavailable('RUNTIME_UNAVAILABLE'),
  releaseLoading('RELEASE_LOADING'),
  maintenance('MAINTENANCE'),

  /// The server sent a state this build does not recognise, or sent none.
  unknown('UNKNOWN');

  const LanguageAvailabilityState(this.code);

  final String code;

  static LanguageAvailabilityState fromCode(Object? raw) {
    final code = raw?.toString();
    if (code == null || code.isEmpty) return unknown;
    for (final s in values) {
      if (s.code == code) return s;
    }
    return unknown;
  }

  /// Whether waiting is likely to help. Drives whether a retry is offered.
  bool get isTransient =>
      this == releaseLoading || this == runtimeUnavailable || this == unknown;
}

/// The word-data release backing a language, when there is one.
///
/// Every field is optional because the client treats a release as an **opaque**
/// fact about the server, not as something to reason about. It is shown for
/// support and diagnostics, never used to gate play — [LanguageAvailability
/// .available] is the only readiness signal.
@immutable
class ActiveRelease {
  const ActiveRelease({
    required this.releaseId,
    this.displayName,
    this.rankingMode,
    this.wordCount,
    this.secretCount,
    this.runtimeLoaded,
  });

  final String releaseId;
  final String? displayName;
  final String? rankingMode;
  final int? wordCount;
  final int? secretCount;
  final bool? runtimeLoaded;

  static ActiveRelease? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final id = raw['release_id']?.toString();
    if (id == null || id.isEmpty) return null;
    int? asInt(Object? v) => v is num ? v.toInt() : null;
    return ActiveRelease(
      releaseId: id,
      displayName: raw['display_name']?.toString(),
      rankingMode: raw['ranking_mode']?.toString(),
      wordCount: asInt(raw['word_count']),
      secretCount: asInt(raw['secret_count']),
      runtimeLoaded: raw['runtime_loaded'] is bool
          ? raw['runtime_loaded'] as bool
          : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'release_id': releaseId,
    if (displayName != null) 'display_name': displayName,
    if (rankingMode != null) 'ranking_mode': rankingMode,
    if (wordCount != null) 'word_count': wordCount,
    if (secretCount != null) 'secret_count': secretCount,
    if (runtimeLoaded != null) 'runtime_loaded': runtimeLoaded,
  };

  @override
  bool operator ==(Object other) =>
      other is ActiveRelease && other.releaseId == releaseId;

  @override
  int get hashCode => releaseId.hashCode;
}

/// One supported language and its current readiness.
@immutable
class LanguageAvailability {
  const LanguageAvailability({
    required this.code,
    required this.displayName,
    required this.supported,
    required this.available,
    required this.state,
    this.messageKey,
    this.activeRelease,
    this.availableCategoryCount,
    this.availableCategories = const <String>[],
    this.direction,
  });

  /// `ar` / `en`.
  final String code;

  /// The language's own name for itself — `العربية`, `English`. Rendered as-is;
  /// a language is never labelled in a language other than its own.
  final String displayName;

  /// Whether the product supports this language at all. A supported language
  /// stays visible even when [available] is false — that is the whole point of
  /// the contract.
  final bool supported;

  /// **The** readiness flag. Nothing else may be used to decide playability.
  final bool available;

  final LanguageAvailabilityState state;

  /// Server-side hint at which message to show. Advisory: the client owns its
  /// own copy and falls back to [state] when this is absent or unrecognised.
  final String? messageKey;

  final ActiveRelease? activeRelease;

  /// How many categories currently have playable words, when the server says.
  /// Null means "not reported", which is different from zero.
  final int? availableCategoryCount;

  /// Category codes that currently have playable words.
  final List<String> availableCategories;

  /// `rtl` / `ltr`, when reported. Not part of contract v1; carried because the
  /// endpoint still sends it and it is genuinely useful.
  final String? direction;

  bool get isArabic => code == 'ar';

  /// Whether offering a retry makes sense for this language's current state.
  bool get retryable => !available && state.isTransient;

  factory LanguageAvailability.fromJson(Map<String, dynamic> json) {
    // `ready` is the pre-contract field. Read only as a fallback so an older
    // server still yields a usable catalogue; `available` wins when present.
    final available = switch (json['available']) {
      final bool b => b,
      _ => json['ready'] == true,
    };
    final categories = json['categories'];
    final catCount = categories is Map && categories['available_count'] is num
        ? (categories['available_count'] as num).toInt()
        : null;
    final catCodes = categories is Map && categories['available'] is List
        ? [for (final c in categories['available'] as List) c.toString()]
        : const <String>[];
    final code = json['code']?.toString() ?? '';
    return LanguageAvailability(
      code: code,
      displayName:
          json['display_name']?.toString() ??
          json['native_name']?.toString() ??
          json['name']?.toString() ??
          code,
      // Absent `supported` means the server listed it, so it is supported.
      supported: switch (json['supported']) {
        final bool b => b,
        _ => true,
      },
      available: available,
      // Never infer a reason. An older server that only says `ready:false`
      // leaves the state unknown, and the UI says so rather than inventing
      // "no active release".
      state: LanguageAvailabilityState.fromCode(json['state']),
      messageKey: json['message_key']?.toString(),
      activeRelease: ActiveRelease.fromJson(json['active_release']),
      availableCategoryCount: catCount,
      availableCategories: catCodes,
      direction: json['dir']?.toString(),
    );
  }

  Map<String, dynamic> toJson() => {
    'code': code,
    'display_name': displayName,
    'supported': supported,
    'available': available,
    'state': state.code,
    if (messageKey != null) 'message_key': messageKey,
    'active_release': activeRelease?.toJson(),
    'categories': {
      if (availableCategoryCount != null)
        'available_count': availableCategoryCount,
      'available': availableCategories,
    },
    if (direction != null) 'dir': direction,
  };

  @override
  bool operator ==(Object other) =>
      other is LanguageAvailability &&
      other.code == code &&
      other.displayName == displayName &&
      other.supported == supported &&
      other.available == available &&
      other.state == state &&
      other.messageKey == messageKey &&
      other.activeRelease == activeRelease &&
      other.availableCategoryCount == availableCategoryCount &&
      listEquals(other.availableCategories, availableCategories);

  @override
  int get hashCode => Object.hash(
    code,
    displayName,
    supported,
    available,
    state,
    messageKey,
    activeRelease,
    availableCategoryCount,
    Object.hashAll(availableCategories),
  );

  @override
  String toString() =>
      'LanguageAvailability($code, available: $available, ${state.code})';
}

/// The full set of supported languages and the server's default.
@immutable
class LanguageCatalogue {
  const LanguageCatalogue({
    required this.languages,
    this.contractVersion,
    this.defaultLanguage,
  });

  /// Every language the server supports — including unavailable ones, which is
  /// the contract's central requirement.
  final List<LanguageAvailability> languages;

  final String? contractVersion;

  /// The server's configured default. Consulted only for the *initial*
  /// selection, never to override a choice the player has made.
  final String? defaultLanguage;

  /// An empty catalogue. Distinguishable from a loaded one by [isEmpty], so a
  /// caller cannot mistake "nothing fetched yet" for "nothing supported".
  static const empty = LanguageCatalogue(languages: []);

  bool get isEmpty => languages.isEmpty;

  /// Supported languages, in server order. This is what the selector renders —
  /// it is deliberately **not** filtered by availability.
  List<LanguageAvailability> get supported =>
      languages.where((l) => l.supported).toList();

  LanguageAvailability? byCode(String? code) {
    if (code == null) return null;
    for (final l in languages) {
      if (l.code == code) return l;
    }
    return null;
  }

  bool isAvailable(String code) => byCode(code)?.available ?? false;

  List<LanguageAvailability> get availableLanguages =>
      supported.where((l) => l.available).toList();

  /// True when every supported language is unavailable — the only situation in
  /// which a global "unavailable" message is honest.
  bool get allUnavailable => supported.isNotEmpty && availableLanguages.isEmpty;

  /// Which language to select when the player has not chosen one.
  ///
  /// Order per the contract: a saved choice that is still supported, then the
  /// server default when it is available, then the first available language,
  /// and finally the default (or first supported) so the selection is always
  /// deterministic even when nothing can be played.
  ///
  /// Note the asymmetry: a **saved** language is honoured even when it is
  /// currently unavailable, because it was the player's choice once and the
  /// contract forbids silently replacing it. The rest of the chain only runs
  /// when there is nothing to honour.
  String? resolveInitial({String? saved}) {
    if (saved != null && byCode(saved)?.supported == true) return saved;
    final fallbackDefault = byCode(defaultLanguage);
    if (fallbackDefault?.available == true) return fallbackDefault!.code;
    final firstAvailable = availableLanguages.firstOrNull;
    if (firstAvailable != null) return firstAvailable.code;
    return fallbackDefault?.code ?? supported.firstOrNull?.code;
  }

  factory LanguageCatalogue.fromJson(Map<String, dynamic> json) =>
      LanguageCatalogue(
        languages: [
          for (final raw in (json['languages'] as List<dynamic>? ?? const []))
            if (raw is Map<String, dynamic>) LanguageAvailability.fromJson(raw),
        ],
        contractVersion: json['contract_version']?.toString(),
        defaultLanguage: json['default_language']?.toString(),
      );

  Map<String, dynamic> toJson() => {
    if (contractVersion != null) 'contract_version': contractVersion,
    if (defaultLanguage != null) 'default_language': defaultLanguage,
    'languages': [for (final l in languages) l.toJson()],
  };

  @override
  bool operator ==(Object other) =>
      other is LanguageCatalogue &&
      other.contractVersion == contractVersion &&
      other.defaultLanguage == defaultLanguage &&
      listEquals(other.languages, languages);

  @override
  int get hashCode =>
      Object.hash(contractVersion, defaultLanguage, Object.hashAll(languages));
}
