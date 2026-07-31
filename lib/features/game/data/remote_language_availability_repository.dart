/// `GET /api/v1/game/languages` — Language Availability Contract v1.
library;

import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../../../core/network/api_client.dart';
import '../domain/languages/language_availability.dart';
import '../domain/languages/language_availability_repository.dart';

class RemoteLanguageAvailabilityRepository
    implements LanguageAvailabilityRepository {
  RemoteLanguageAvailabilityRepository(this._client, this._prefs);

  final ApiClient _client;
  final SharedPreferences _prefs;

  /// The client's base URL already ends in `/api/v1/game`.
  static const path = '/languages';

  static const cacheKey = 'siyaq.languages.v1';

  @override
  Future<LanguageCatalogue> fetch() async {
    final catalogue = LanguageCatalogue.fromJson(await _client.getJson(path));
    // Only a catalogue with something in it is worth remembering; caching an
    // empty one would let a bad response silently blank the selector later.
    if (!catalogue.isEmpty) await writeCache(catalogue);
    return catalogue;
  }

  @override
  LanguageCatalogue? readCached() {
    final raw = _prefs.getString(cacheKey);
    if (raw == null || raw.isEmpty) return null;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return null;
      final catalogue = LanguageCatalogue.fromJson(decoded);
      return catalogue.isEmpty ? null : catalogue;
    } on FormatException {
      // A cache written by an older build is not worth a crash.
      return null;
    }
  }

  @override
  Future<void> writeCache(LanguageCatalogue catalogue) =>
      _prefs.setString(cacheKey, jsonEncode(catalogue.toJson()));
}
