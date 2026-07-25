import '../../domain/entities/social.dart';
import '../../domain/repositories/social_repository.dart';
import 'v2_api_client.dart';

/// Live [SocialRepository] over the V2 REST client (contract §9–10).
class RemoteSocialRepository implements SocialRepository {
  RemoteSocialRepository(this._api);
  final V2ApiClient _api;

  @override
  Future<SocialDirectory> listPlayers({
    int limit = 20,
    int? cursor,
    String? q,
    String? language,
    bool availableOnly = false,
  }) async {
    final res = await _api.get(
      '/social/players',
      query: {
        'limit': limit,
        'cursor': ?cursor,
        if (q != null && q.isNotEmpty) 'q': q,
        'language': ?language,
        if (availableOnly) 'available_only': true,
      },
    );
    final list = res['players'];
    return SocialDirectory(
      players: list is List
          ? list
                .whereType<Map>()
                .map((e) => _player(e.cast<String, dynamic>()))
                .toList()
          : const [],
      cursor: (res['cursor'] as num?)?.toInt(),
      nextCursor: (res['next_cursor'] as num?)?.toInt(),
    );
  }

  @override
  Future<SocialPlayer> getPlayer(String publicPlayerId) async =>
      _player(await _api.get('/social/players/$publicPlayerId'));

  @override
  Future<PresenceInfo> heartbeat({
    PresenceState? state,
    String? activity,
  }) async {
    final res = await _api.post(
      '/social/presence/heartbeat',
      body: {
        if (state != null) 'state': state.wire,
        'activity': ?activity,
      },
    );
    return PresenceInfo(
      state: PresenceState.parse(res['state']?.toString()),
      available: res['available'] == true,
      activity: res['activity'] as String?,
      lastHeartbeatAt: _date(res['last_heartbeat_at']),
    );
  }

  @override
  Future<List<RoomInvitation>> incomingInvitations() async {
    final res = await _api.get('/social/invitations');
    final list = res['invitations'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => _invitation(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<String> acceptInvitation(String invitationId) async {
    final res = await _api.post('/social/invitations/$invitationId/accept');
    return (res['room_id'] ?? '').toString();
  }

  @override
  Future<void> declineInvitation(String invitationId) =>
      _api.post('/social/invitations/$invitationId/decline');

  @override
  Future<void> inviteToRoom({
    required String roomId,
    required String targetPublicPlayerId,
  }) => _api.post(
    '/rooms/$roomId/invitations',
    body: {'target_public_player_id': targetPublicPlayerId},
  );

  // ── Mappers ─────────────────────────────────────────────────────────────────
  static SocialPlayer _player(Map<String, dynamic> j) => SocialPlayer(
    publicPlayerId: (j['public_player_id'] ?? '').toString(),
    displayName: (j['display_name'] ?? '').toString(),
    avatarUrl: j['avatar_url'] as String?,
    presence: PresenceState.parse(j['presence']?.toString()),
    availableForInvite: j['available_for_invite'] == true,
    acceptsJoinRequests: j['accepts_join_requests'] == true,
  );

  static RoomInvitation _invitation(Map<String, dynamic> j) {
    final host = j['host'];
    return RoomInvitation(
      invitationId: (j['invitation_id'] ?? '').toString(),
      roomId: (j['room_id'] ?? '').toString(),
      roomName: (j['room_name'] ?? '').toString(),
      language: (j['language'] ?? 'ar').toString(),
      host: _party(host is Map ? host.cast<String, dynamic>() : const {}),
      status: InvitationStatus.parse(j['status']?.toString()),
      createdAt: _date(j['created_at']),
      expiresAt: _date(j['expires_at']),
    );
  }

  static InvitationParty _party(Map<String, dynamic> j) => InvitationParty(
    publicPlayerId: (j['public_player_id'] ?? '').toString(),
    displayName: (j['display_name'] ?? '').toString(),
    avatarUrl: j['avatar_url'] as String?,
  );

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;
}
