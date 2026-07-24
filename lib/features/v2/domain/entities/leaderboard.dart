/// One leaderboard row. Never carries an installation ID.
class LeaderboardEntry {
  const LeaderboardEntry({
    required this.placement,
    required this.label,
    required this.solved,
    required this.attempts,
    required this.hintsUsed,
    this.elapsed,
    this.isCurrentProfile = false,
  });

  final int placement;

  /// Display name, or a fallback short code — resolved by the data layer.
  final String label;
  final bool solved;
  final int attempts;
  final int hintsUsed;
  final Duration? elapsed;
  final bool isCurrentProfile;
}

/// A paginated slice of the weekly leaderboard.
class LeaderboardPage {
  const LeaderboardPage({
    required this.entries,
    required this.page,
    required this.hasMore,
    this.currentPlacement,
  });

  final List<LeaderboardEntry> entries;
  final int page;
  final bool hasMore;
  final int? currentPlacement;
}
