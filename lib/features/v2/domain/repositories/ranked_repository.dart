import '../entities/ranked.dart';

/// Ranked 1v1 PvP (contract §8). Server-authoritative; the client polls / or
/// applies realtime events (§11) and reconciles by `state_version`/`seq`.
abstract class RankedRepository {
  /// Available coin tiers (`GET /ranked-matches/tiers`).
  Future<List<RankedTier>> getTiers();

  /// The player's ranked standing (`GET /ranked/me`).
  Future<RankedStats> getStats();

  /// Join matchmaking for a tier — reserves the entry (`POST /matchmaking/join`).
  Future<MatchmakingTicket> joinMatchmaking({
    required String language,
    required String tierId,
  });

  /// Poll a ticket (`GET /matchmaking/tickets/{id}`) → searching → matched.
  Future<MatchmakingTicket> getTicket(String ticketId);

  /// The current live ticket, if any (`GET /matchmaking/active`).
  Future<MatchmakingTicket?> getActiveTicket();

  /// Cancel a searching ticket and refund the hold.
  Future<void> cancelTicket(String ticketId);

  /// Authoritative match snapshot.
  Future<RankedMatch> getMatch(String matchId);

  /// Ready-up in the preparing phase.
  Future<RankedMatch> ready(String matchId);

  /// Submit a guess on your turn (`X-Game-Language` sent).
  Future<RankedMatch> guess(String matchId, String word, {required String language});

  /// Forfeit the match.
  Future<RankedMatch> forfeit(String matchId);

  /// Re-attach after a disconnect within the reconnect window.
  Future<RankedMatch> reconnect(String matchId);
}
