/// Typed failures from `POST /game/new-game`.
///
/// The point of typing these is that the two availability failures need
/// *different* answers from the UI, and an HTTP status cannot tell them apart in
/// a way that survives a backend refactor:
///
/// - `NO_ACTIVE_RELEASE` — the whole language has no words. Offer another
///   language, and re-check availability, because it just changed under us.
/// - `NO_PLAYABLE_SECRETS_FOR_CATEGORY` — the language is fine; this one
///   category is empty. Offer another category. Retrying is pointless.
///
/// Conflating them would tell a player "Arabic is unavailable" when in fact
/// English is playable and they merely picked an empty category.
library;

import 'package:flutter/foundation.dart';

import '../../../../core/network/api_error.dart';

enum GameStartFailureCode {
  noActiveRelease('NO_ACTIVE_RELEASE'),
  noPlayableSecretsForCategory('NO_PLAYABLE_SECRETS_FOR_CATEGORY'),
  languageRequired('LANGUAGE_REQUIRED'),

  /// Anything else — network trouble, validation, an unrecognised code. The UI
  /// falls back to its generic error copy rather than guessing.
  unknown('UNKNOWN');

  const GameStartFailureCode(this.code);

  final String code;

  static GameStartFailureCode fromCode(Object? raw) {
    final code = raw?.toString();
    if (code == null || code.isEmpty) return unknown;
    for (final c in values) {
      if (c.code == code) return c;
    }
    return unknown;
  }
}

@immutable
class GameStartFailure implements Exception {
  const GameStartFailure({
    required this.code,
    this.language,
    this.category,
    this.messageKey,
    this.retryable = false,
    this.availableLanguages = const <String>[],
    this.availableCategories = const <String>[],
    this.serverMessage,
  });

  final GameStartFailureCode code;
  final String? language;
  final String? category;

  /// The server's suggested message key. Advisory — localisation stays in the
  /// client, so an unknown key degrades to copy chosen from [code].
  final String? messageKey;

  /// Whether the server says trying again could work.
  final bool retryable;

  /// Languages the server says are playable right now. This is what makes
  /// "Choose English" a fact rather than an assumption.
  final List<String> availableLanguages;

  /// Categories with playable words, for the empty-category case.
  final List<String> availableCategories;

  final String? serverMessage;

  /// Whether the language catalogue should be re-fetched after this failure.
  ///
  /// A release appearing or vanishing is exactly the kind of change that makes
  /// cached availability wrong, so the contract requires a refresh here.
  bool get shouldRefreshAvailability =>
      code == GameStartFailureCode.noActiveRelease ||
      code == GameStartFailureCode.languageRequired;

  /// Reads a typed failure out of an error body.
  ///
  /// Fields are accepted at the top level *or* nested under `details`, because
  /// production sends several of them in both places and pinning to one shape
  /// would break on a harmless server change.
  static GameStartFailure? fromBody(Map<String, dynamic>? body) {
    if (body == null) return null;
    final details = body['details'];
    final nested = details is Map ? details : const {};

    Object? pick(String key) => body[key] ?? nested[key];

    final code = GameStartFailureCode.fromCode(body['code'] ?? nested['code']);
    if (code == GameStartFailureCode.unknown) return null;

    List<String> strings(String key) {
      final raw = pick(key);
      return raw is List ? [for (final v in raw) v.toString()] : const [];
    }

    return GameStartFailure(
      code: code,
      language: pick('language')?.toString(),
      category: pick('category')?.toString(),
      messageKey: pick('message_key')?.toString(),
      retryable: pick('retryable') == true,
      availableLanguages: strings('available_languages'),
      availableCategories: strings('available_categories'),
      serverMessage: body['message']?.toString(),
    );
  }

  /// Lifts an [ApiException] into a typed failure when it carries one.
  ///
  /// Returns null for ordinary transport failures, which stay [ApiException] so
  /// the existing offline handling keeps working untouched.
  static GameStartFailure? from(Object? error) {
    if (error is GameStartFailure) return error;
    if (error is ApiException) return fromBody(error.body);
    return null;
  }

  @override
  String toString() =>
      'GameStartFailure(${code.code}, language: $language, category: $category)';
}
