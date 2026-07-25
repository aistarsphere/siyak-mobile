/// Anonymous, device-local installation profile (NOT a login account).
/// Registered idempotently with V2 using the `X-Installation-ID` header.
class InstallationProfile {
  const InstallationProfile({
    required this.installationId,
    required this.shortCode,
    this.profileId,
    this.displayName,
    this.gamesPlayed = 0,
    this.gamesSolved = 0,
    this.roomsJoined = 0,
    this.roomsWon = 0,
    this.weeklyBestPlacement,
  });

  /// UUID v4 held in secure storage — never shown in the normal UI.
  final String installationId;

  /// Server-assigned public id (`prof_…`), used to attribute rooms/leaderboard
  /// rows to "me". Never shown as the raw id in the UI.
  final String? profileId;

  /// Human-facing fallback identifier when no display name is set.
  final String shortCode;
  final String? displayName;

  final int gamesPlayed; // weekly_played
  final int gamesSolved; // weekly_solved
  final int roomsJoined;
  final int roomsWon;
  final int? weeklyBestPlacement;

  /// What to show for this profile in lists / the profile card.
  String get label => (displayName != null && displayName!.trim().isNotEmpty)
      ? displayName!.trim()
      : shortCode;

  bool get hasDisplayName =>
      displayName != null && displayName!.trim().isNotEmpty;

  InstallationProfile copyWith({
    String? profileId,
    String? displayName,
    int? gamesPlayed,
    int? gamesSolved,
    int? roomsJoined,
    int? roomsWon,
    int? weeklyBestPlacement,
  }) => InstallationProfile(
    installationId: installationId,
    profileId: profileId ?? this.profileId,
    shortCode: shortCode,
    displayName: displayName ?? this.displayName,
    gamesPlayed: gamesPlayed ?? this.gamesPlayed,
    gamesSolved: gamesSolved ?? this.gamesSolved,
    roomsJoined: roomsJoined ?? this.roomsJoined,
    roomsWon: roomsWon ?? this.roomsWon,
    weeklyBestPlacement: weeklyBestPlacement ?? this.weeklyBestPlacement,
  );
}
