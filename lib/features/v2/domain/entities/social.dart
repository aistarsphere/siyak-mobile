// Social directory, presence & invitations (contract §9–10). Account-only —
// every one of these needs an authenticated session; guests never see them.

/// Server-derived presence. Only [onlineAvailable]/[onlineAway]/[inLobby] are
/// client-settable via the heartbeat; the rest are set by the backend from
/// actual gameplay activity and decay to [offline] when heartbeats stop.
enum PresenceState {
  onlineAvailable,
  onlineAway,
  inLobby,
  inRoomGame,
  inRankedMatchmaking,
  inRankedMatch,
  reconnecting,
  offline;

  static PresenceState parse(String? s) => switch (s) {
    'online_available' => PresenceState.onlineAvailable,
    'online_away' => PresenceState.onlineAway,
    'in_lobby' => PresenceState.inLobby,
    'in_room_game' => PresenceState.inRoomGame,
    'in_ranked_matchmaking' => PresenceState.inRankedMatchmaking,
    'in_ranked_match' => PresenceState.inRankedMatch,
    'reconnecting' => PresenceState.reconnecting,
    _ => PresenceState.offline,
  };

  /// The wire value for the states a client is allowed to declare.
  String get wire => switch (this) {
    PresenceState.onlineAway => 'online_away',
    PresenceState.inLobby => 'in_lobby',
    _ => 'online_available',
  };

  bool get isOnline => this != PresenceState.offline;
}

/// A discoverable player from `GET /social/players` — public identity only,
/// never an internal profile id.
class SocialPlayer {
  const SocialPlayer({
    required this.publicPlayerId,
    required this.displayName,
    this.avatarUrl,
    this.presence = PresenceState.offline,
    this.availableForInvite = false,
    this.acceptsJoinRequests = false,
  });

  final String publicPlayerId;
  final String displayName;
  final String? avatarUrl;
  final PresenceState presence;
  final bool availableForInvite;
  final bool acceptsJoinRequests;
}

/// A page of the players directory (cursor-paginated).
class SocialDirectory {
  const SocialDirectory({
    this.players = const [],
    this.cursor,
    this.nextCursor,
  });

  final List<SocialPlayer> players;
  final int? cursor;
  final int? nextCursor;

  bool get hasMore => nextCursor != null;
}

/// The result of a presence heartbeat (`POST /social/presence/heartbeat`).
class PresenceInfo {
  const PresenceInfo({
    required this.state,
    required this.available,
    this.activity,
    this.lastHeartbeatAt,
  });

  final PresenceState state;
  final bool available;
  final String? activity;
  final DateTime? lastHeartbeatAt;
}

/// A party on an invitation (host or target) — public identity only.
class InvitationParty {
  const InvitationParty({
    required this.publicPlayerId,
    required this.displayName,
    this.avatarUrl,
  });

  final String publicPlayerId;
  final String displayName;
  final String? avatarUrl;
}

enum InvitationStatus {
  pending,
  accepted,
  declined,
  cancelled,
  expired,
  invalidated,
  roomFull,
  roomStarted;

  static InvitationStatus parse(String? s) => switch (s) {
    'pending' => InvitationStatus.pending,
    'accepted' => InvitationStatus.accepted,
    'declined' => InvitationStatus.declined,
    'cancelled' => InvitationStatus.cancelled,
    'expired' => InvitationStatus.expired,
    'room_full' => InvitationStatus.roomFull,
    'room_started' => InvitationStatus.roomStarted,
    _ => InvitationStatus.invalidated,
  };

  bool get isActionable => this == InvitationStatus.pending;
}

/// A room invitation addressed to the current player
/// (`GET /social/invitations`).
class RoomInvitation {
  const RoomInvitation({
    required this.invitationId,
    required this.roomId,
    required this.roomName,
    required this.language,
    required this.host,
    this.status = InvitationStatus.pending,
    this.createdAt,
    this.expiresAt,
  });

  final String invitationId;
  final String roomId;
  final String roomName;
  final String language;
  final InvitationParty host;
  final InvitationStatus status;
  final DateTime? createdAt;
  final DateTime? expiresAt;
}
