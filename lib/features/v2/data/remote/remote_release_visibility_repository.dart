import '../../domain/entities/release_visibility.dart';
import '../../domain/repositories/release_visibility_repository.dart';
import 'v2_api_client.dart';
import 'v2_mappers.dart';

/// Live implementation over the shared [V2ApiClient].
///
/// The client already injects `X-Installation-ID` and, when a session exists,
/// `Authorization: Bearer …` — which is exactly the either/or rule this endpoint
/// expects, so there is no bespoke auth handling here.
class RemoteReleaseVisibilityRepository implements ReleaseVisibilityRepository {
  RemoteReleaseVisibilityRepository(this._client);

  /// The one path this feature is allowed to call. No `/admin/*` route is
  /// reachable from the client: admin policy lives behind an admin session the
  /// app never holds.
  static const path = '/release-visibility';

  final V2ApiClient _client;

  @override
  Future<ReleaseVisibility> fetch({String? language}) async {
    try {
      final json = await _client.get(
        path,
        query: (language == null || language.isEmpty)
            ? null
            : <String, dynamic>{'language': language},
      );
      return V2Mappers.releaseVisibility(json);
    } catch (_) {
      // Request failure *and* decode failure collapse to the same hidden value
      // the server sends for a hidden policy. The section simply does not exist;
      // no error card, no toast, no retry prompt.
      return ReleaseVisibility.hidden;
    }
  }
}
