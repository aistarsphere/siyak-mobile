// Ranked 1v1 PvP domain model (contract §8). Server-authoritative, turn-based,
// coin-staked. Both players share the same secret; they alternate turns; first
// to rank 1 wins the pot.

/// A coin-staked tier (`GET /ranked-matches/tiers`).
class RankedTier {
  const RankedTier({
    required this.id,
    required this.entryCost,
    required this.payout,
    this.playerCount = 2,
    this.platformFee = 0,
    this.currency = 'COIN',
    this.enabled = true,
  });

  final String id;
  final int entryCost;

  /// Coins the winner receives.
  final int payout;
  final int playerCount;
  final int platformFee;
  final String currency;
  final bool enabled;
}

enum MatchmakingStatus { searching, matched, cancelled, expired, failed, unknown }

/// A matchmaking ticket (`POST /matchmaking/join` → poll the ticket).
class MatchmakingTicket {
  const MatchmakingTicket({
    required this.id,
    required this.status,
    this.tierId,
    this.language,
    this.rating,
    this.matchId,
    this.reservedCoins = 0,
    this.availableBalance = 0,
    this.reservedBalance = 0,
    this.waitingSeconds = 0,
    this.match,
  });

  final String id;
  final MatchmakingStatus status;
  final String? tierId;
  final String? language;
  final int? rating;
  final String? matchId;
  final int reservedCoins;
  final int availableBalance;
  final int reservedBalance;
  final double waitingSeconds;
  final RankedMatch? match;

  bool get isSearching => status == MatchmakingStatus.searching;
  bool get isMatched => status == MatchmakingStatus.matched && matchId != null;
  bool get isTerminal =>
      status == MatchmakingStatus.cancelled ||
      status == MatchmakingStatus.expired ||
      status == MatchmakingStatus.failed;
}

/// One player's slot in a match.
class MatchPlayer {
  const MatchPlayer({
    required this.profileId,
    required this.slot,
    this.displayName,
    this.shortCode,
    this.ready = false,
    this.connectionState = 'connected',
    this.missedTurns = 0,
    this.isYou = false,
  });

  final String profileId;
  final int slot;
  final String? displayName;
  final String? shortCode;
  final bool ready;
  final String connectionState;
  final int missedTurns;
  final bool isYou;

  String get label =>
      (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!
      : (shortCode ?? '—');
}

/// A revealed guess in the shared match history.
class MatchGuess {
  const MatchGuess({
    required this.word,
    this.rank,
    this.profileId,
    this.turnNumber,
    this.isYou = false,
    this.createdAt,
  });

  final String word;
  final int? rank;
  final String? profileId;
  final int? turnNumber;
  final bool isYou;
  final DateTime? createdAt;
}

enum RankedMatchStatus {
  preparing,
  ready,
  active,
  paused,
  solved,
  forfeited,
  cancelled,
  settlementPending,
  settled,
  unknown,
}

/// Authoritative match snapshot (`GET /ranked-matches/{id}`).
class RankedMatch {
  const RankedMatch({
    required this.id,
    required this.status,
    this.tierId,
    this.entryCost = 0,
    this.payout = 0,
    this.language = 'ar',
    this.category,
    this.resolution,
    this.turnNumber = 0,
    this.currentTurn,
    this.turnDeadline,
    this.turnRemainingSeconds,
    this.readyDeadline,
    this.stateVersion = 0,
    this.seq = 0,
    this.players = const [],
    this.guesses = const [],
    this.winner,
    this.loserId,
    this.ratingDelta,
    this.secretWord,
    this.settled = false,
  });

  final String id;
  final RankedMatchStatus status;
  final String? tierId;
  final int entryCost;
  final int payout;
  final String language;
  final String? category;

  /// Why it ended (`solved`, `missed_turns`, `forfeit`, `disconnect`, …).
  final String? resolution;
  final int turnNumber;

  /// The `profile_id` whose turn it is (active only).
  final String? currentTurn;
  final DateTime? turnDeadline;
  final double? turnRemainingSeconds;
  final DateTime? readyDeadline;

  /// Monotonic ordering for realtime reconciliation (apply only if newer).
  final int stateVersion;
  final int seq;
  final List<MatchPlayer> players;
  final List<MatchGuess> guesses;

  /// Winner `profile_id`.
  final String? winner;
  final String? loserId;
  final int? ratingDelta;

  /// Revealed only after the match ends.
  final String? secretWord;
  final bool settled;

  MatchPlayer? get you {
    for (final p in players) {
      if (p.isYou) return p;
    }
    return null;
  }

  MatchPlayer? get opponent {
    for (final p in players) {
      if (!p.isYou) return p;
    }
    return null;
  }

  bool get isActive => status == RankedMatchStatus.active;
  bool get isPreparing =>
      status == RankedMatchStatus.preparing || status == RankedMatchStatus.ready;
  bool get isOver =>
      status == RankedMatchStatus.solved ||
      status == RankedMatchStatus.forfeited ||
      status == RankedMatchStatus.cancelled ||
      status == RankedMatchStatus.settled;
  bool get isMyTurn {
    final me = you;
    return isActive && me != null && currentTurn == me.profileId;
  }

  bool get didIWin => winner != null && you != null && winner == you!.profileId;
}

/// The player's ranked standing (`GET /ranked/me`).
class RankedStats {
  const RankedStats({
    this.rating = 1000,
    this.wins = 0,
    this.losses = 0,
    this.matchesPlayed = 0,
  });

  final int rating;
  final int wins;
  final int losses;
  final int matchesPlayed;
}
