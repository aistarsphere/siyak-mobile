import '../../domain/entities/ranked.dart';
import '../../domain/repositories/ranked_repository.dart';
import 'v2_api_client.dart';

/// Live [RankedRepository] over the V2 REST client (contract §8).
class RemoteRankedRepository implements RankedRepository {
  RemoteRankedRepository(this._api);
  final V2ApiClient _api;

  @override
  Future<List<RankedTier>> getTiers() async {
    final res = await _api.get('/ranked-matches/tiers');
    final list = res['tiers'];
    if (list is! List) return const [];
    return list
        .whereType<Map>()
        .map((e) => _tier(e.cast<String, dynamic>()))
        .toList();
  }

  @override
  Future<RankedStats> getStats() async {
    final j = await _api.get('/ranked/me');
    return RankedStats(
      rating: (j['rating'] as num?)?.toInt() ?? 1000,
      wins: (j['wins'] as num?)?.toInt() ?? 0,
      losses: (j['losses'] as num?)?.toInt() ?? 0,
      matchesPlayed:
          (j['matches_played'] as num?)?.toInt() ??
          (j['games_played'] as num?)?.toInt() ??
          0,
    );
  }

  @override
  Future<MatchmakingTicket> joinMatchmaking({
    required String language,
    required String tierId,
  }) async {
    final res = await _api.post(
      '/matchmaking/join',
      body: {'language': language, 'tier_id': tierId},
    );
    return _ticket(res);
  }

  @override
  Future<MatchmakingTicket> getTicket(String ticketId) async =>
      _ticket(await _api.get('/matchmaking/tickets/$ticketId'));

  @override
  Future<MatchmakingTicket?> getActiveTicket() async {
    final res = await _api.get('/matchmaking/active');
    if (res['ticket_id'] == null && res['ticket'] == null) return null;
    final t = res['ticket'];
    return _ticket(t is Map ? t.cast<String, dynamic>() : res);
  }

  @override
  Future<void> cancelTicket(String ticketId) =>
      _api.post('/matchmaking/tickets/$ticketId/cancel');

  @override
  Future<RankedMatch> getMatch(String matchId) async =>
      _match(await _api.get('/ranked-matches/$matchId'));

  @override
  Future<RankedMatch> ready(String matchId) =>
      _act('$matchId/ready', matchId, () => _api.post('/ranked-matches/$matchId/ready'));

  @override
  Future<RankedMatch> guess(
    String matchId,
    String word, {
    required String language,
  }) => _act(
    '$matchId/guess',
    matchId,
    () => _api.post(
      '/ranked-matches/$matchId/guess',
      body: {'guess': word},
      gameLanguage: language,
    ),
  );

  @override
  Future<RankedMatch> forfeit(String matchId) => _act(
    '$matchId/forfeit',
    matchId,
    () => _api.post('/ranked-matches/$matchId/forfeit'),
  );

  @override
  Future<RankedMatch> reconnect(String matchId) => _act(
    '$matchId/reconnect',
    matchId,
    () => _api.post('/ranked-matches/$matchId/reconnect'),
  );

  /// Runs a match action, returning the updated snapshot from the response when
  /// present, otherwise re-fetching the authoritative match.
  Future<RankedMatch> _act(
    String _,
    String matchId,
    Future<Map<String, dynamic>> Function() run,
  ) async {
    final res = await run();
    final nested = res['match'];
    if (nested is Map) return _match(nested.cast<String, dynamic>());
    if (res['players'] is List || res['status'] != null && res['match_id'] != null) {
      return _match(res);
    }
    return getMatch(matchId);
  }

  // ── Mappers ─────────────────────────────────────────────────────────────────
  static RankedTier _tier(Map<String, dynamic> j) => RankedTier(
    id: (j['tier_id'] ?? '').toString(),
    entryCost: (j['entry_cost'] as num?)?.toInt() ?? 0,
    payout: (j['payout'] as num?)?.toInt() ?? 0,
    playerCount: (j['player_count'] as num?)?.toInt() ?? 2,
    platformFee: (j['platform_fee'] as num?)?.toInt() ?? 0,
    currency: (j['currency'] ?? 'COIN').toString(),
    enabled: j['enabled'] != false,
  );

  static MatchmakingTicket _ticket(Map<String, dynamic> j) {
    final m = j['match'];
    return MatchmakingTicket(
      id: (j['ticket_id'] ?? '').toString(),
      status: _mmStatus(j['status']?.toString()),
      tierId: j['tier_id'] as String?,
      language: j['language'] as String?,
      rating: (j['rating'] as num?)?.toInt(),
      matchId: j['match_id'] as String?,
      reservedCoins: (j['reserved_coins'] as num?)?.toInt() ?? 0,
      availableBalance: (j['available_balance'] as num?)?.toInt() ?? 0,
      reservedBalance: (j['reserved_balance'] as num?)?.toInt() ?? 0,
      waitingSeconds: (j['waiting_seconds'] as num?)?.toDouble() ?? 0,
      match: m is Map ? _match(m.cast<String, dynamic>()) : null,
    );
  }

  static RankedMatch _match(Map<String, dynamic> j) => RankedMatch(
    id: (j['match_id'] ?? '').toString(),
    status: _matchStatus(j['status']?.toString()),
    tierId: j['tier_id'] as String?,
    entryCost: (j['entry_cost'] as num?)?.toInt() ?? 0,
    payout: (j['payout'] as num?)?.toInt() ?? 0,
    language: (j['language'] ?? 'ar').toString(),
    category: j['category'] as String?,
    resolution: j['resolution'] as String?,
    turnNumber: (j['turn_number'] as num?)?.toInt() ?? 0,
    currentTurn: j['current_turn'] as String?,
    turnDeadline: _date(j['turn_deadline']),
    turnRemainingSeconds: (j['turn_remaining_seconds'] as num?)?.toDouble(),
    readyDeadline: _date(j['ready_deadline']),
    stateVersion: (j['state_version'] as num?)?.toInt() ?? 0,
    seq: (j['seq'] as num?)?.toInt() ?? 0,
    players: _players(j['players']),
    guesses: _guesses(j['guesses']),
    winner: j['winner'] as String?,
    loserId: j['loser_id'] as String?,
    ratingDelta: (j['rating_delta'] as num?)?.toInt(),
    secretWord: j['secret_word'] as String?,
    settled: j['settled'] == true,
  );

  static List<MatchPlayer> _players(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final j = e.cast<String, dynamic>();
      return MatchPlayer(
        profileId: (j['profile_id'] ?? '').toString(),
        slot: (j['slot'] as num?)?.toInt() ?? 0,
        displayName: j['display_name'] as String?,
        shortCode: j['short_code'] as String?,
        ready: j['ready'] == true,
        connectionState: (j['connection_state'] ?? 'connected').toString(),
        missedTurns: (j['missed_turns'] as num?)?.toInt() ?? 0,
        isYou: j['is_you'] == true,
      );
    }).toList();
  }

  static List<MatchGuess> _guesses(Object? raw) {
    if (raw is! List) return const [];
    return raw.whereType<Map>().map((e) {
      final j = e.cast<String, dynamic>();
      return MatchGuess(
        word: (j['word'] ?? j['guess'] ?? '').toString(),
        rank: (j['rank'] as num?)?.toInt(),
        profileId: j['profile_id'] as String?,
        turnNumber: (j['turn_number'] as num?)?.toInt(),
        isYou: j['is_you'] == true,
        createdAt: _date(j['created_at']),
      );
    }).toList();
  }

  static MatchmakingStatus _mmStatus(String? s) => switch (s) {
    'searching' => MatchmakingStatus.searching,
    'matched' => MatchmakingStatus.matched,
    'cancelled' => MatchmakingStatus.cancelled,
    'expired' => MatchmakingStatus.expired,
    'failed' => MatchmakingStatus.failed,
    _ => MatchmakingStatus.unknown,
  };

  static RankedMatchStatus _matchStatus(String? s) => switch (s) {
    'preparing' => RankedMatchStatus.preparing,
    'ready' => RankedMatchStatus.ready,
    'active' => RankedMatchStatus.active,
    'paused' => RankedMatchStatus.paused,
    'solved' => RankedMatchStatus.solved,
    'forfeited' => RankedMatchStatus.forfeited,
    'cancelled' => RankedMatchStatus.cancelled,
    'settlement_pending' => RankedMatchStatus.settlementPending,
    'settled' => RankedMatchStatus.settled,
    _ => RankedMatchStatus.unknown,
  };

  static DateTime? _date(Object? v) =>
      v is String ? DateTime.tryParse(v)?.toUtc() : null;
}
