/// Source of language availability.
library;

import 'language_availability.dart';

abstract class LanguageAvailabilityRepository {
  /// Fetches the current catalogue from the server.
  Future<LanguageCatalogue> fetch();

  /// The last catalogue that was successfully fetched, if any.
  ///
  /// Read only to keep the selector populated while a refresh is in flight or
  /// after it fails. It must never overwrite a fresh result — availability is
  /// precisely the thing that goes stale.
  LanguageCatalogue? readCached();

  Future<void> writeCache(LanguageCatalogue catalogue);
}
