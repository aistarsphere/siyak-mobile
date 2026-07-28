import '../entities/release_visibility.dart';

/// Reads the release/version information the server chooses to expose.
///
/// One endpoint, `GET /api/v1/release-visibility`. Authentication is the
/// existing either/or rule the shared API client already applies: a session
/// bearer when the player has an account, `X-Installation-ID` otherwise. An
/// unidentified caller receives `{"visible": false}` — a normal response, not an
/// authentication error — so this can safely be called before the app knows who
/// the player is.
///
/// Implementations must **never** throw: every failure resolves to
/// [ReleaseVisibility.hidden], because a Profile screen must open whether or not
/// this endpoint is reachable.
abstract class ReleaseVisibilityRepository {
  /// [language] is optional; the server defaults it to the profile's
  /// `ui_language`. It is passed so the section matches the language the player
  /// is actually looking at.
  Future<ReleaseVisibility> fetch({String? language});
}
