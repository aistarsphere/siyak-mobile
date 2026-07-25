import '../entities/social.dart';

/// Social directory, presence & invitations (contract §9–10). All calls require
/// an authenticated session; a guest session will get `AUTHENTICATION_REQUIRED`.
abstract class SocialRepository {
  /// Browse discoverable players (`GET /social/players`). [availableOnly] limits
  /// to players open to invites; [q] filters by display name / short code.
  Future<SocialDirectory> listPlayers({
    int limit,
    int? cursor,
    String? q,
    String? language,
    bool availableOnly,
  });

  /// A single player's public card (`GET /social/players/{public_player_id}`).
  Future<SocialPlayer> getPlayer(String publicPlayerId);

  /// Report liveness (`POST /social/presence/heartbeat`). The server clamps
  /// [state] to the client-settable set and derives gameplay states itself.
  Future<PresenceInfo> heartbeat({PresenceState? state, String? activity});

  /// Room invitations addressed to me (`GET /social/invitations`).
  Future<List<RoomInvitation>> incomingInvitations();

  /// Accept an invitation — joins the room (`POST /social/invitations/{id}/accept`).
  /// Returns the room id to open.
  Future<String> acceptInvitation(String invitationId);

  /// Decline an invitation (`POST /social/invitations/{id}/decline`).
  Future<void> declineInvitation(String invitationId);

  /// As a room host, invite a discoverable player
  /// (`POST /rooms/{room_id}/invitations` `{target_public_player_id}`).
  Future<void> inviteToRoom({
    required String roomId,
    required String targetPublicPlayerId,
  });
}
