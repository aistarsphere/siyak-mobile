import '../entities/adaptive_hint.dart';
import '../entities/gameplay_language.dart';
import '../entities/hint_mode.dart';
import '../entities/installation_profile.dart';
import '../entities/leaderboard.dart';
import '../entities/room.dart';
import '../entities/room_event.dart';
import '../entities/v2_capabilities.dart';
import '../entities/weekly.dart';

/// Guess outcome shared by weekly + room flows. Mirrors V1 semantics
/// (accepted / duplicate-canonical / unknown) without a frozen wire schema.
class V2GuessOutcome {
  const V2GuessOutcome({
    required this.accepted,
    required this.duplicate,
    required this.unknown,
    this.canonicalWord,
    this.originalWord,
    this.rank,
    this.proximity,
    this.heatLevel,
    this.solved = false,
    this.secretWord,
    this.firstByLabel,
    this.suggestions = const [],
  });

  final bool accepted;
  final bool duplicate;
  final bool unknown;
  final String? canonicalWord;
  final String? originalWord;
  final int? rank;
  final double? proximity;
  final String? heatLevel;
  final bool solved;
  final String? secretWord;

  /// For a shared/canonical duplicate: who reached the concept first.
  final String? firstByLabel;
  final List<String> suggestions;
}

/// Capability detection — decides whether V2 features are offered at all.
abstract class CapabilitiesRepository {
  Future<V2Capabilities> detect();
}

/// Anonymous installation profile (idempotent registration).
abstract class ProfileRepository {
  Future<InstallationProfile> register({
    required String installationId,
    String? displayName,
  });

  Future<InstallationProfile> updateDisplayName({
    required String installationId,
    required String displayName,
  });
}

/// Weekly challenge lifecycle + leaderboard.
abstract class WeeklyRepository {
  Future<WeeklyChallenge> current({required GameplayLanguage language});

  Future<WeeklyRun> startRun({
    required String weekId,
    required GameplayLanguage language,
    HintMode hintMode,
  });

  Future<WeeklyRun> resumeRun({required String runId});

  Future<({WeeklyRun run, V2GuessOutcome outcome})> guess({
    required String runId,
    required String word,
  });

  Future<AdaptiveHint> hint({required String runId, required HintMode mode});

  Future<LeaderboardPage> leaderboard({
    required String weekId,
    int page,
    int pageSize,
  });
}

/// Multiplayer rooms (REST side; realtime is [RealtimeGateway]).
abstract class RoomRepository {
  Future<Room> create({
    required GameplayLanguage language,
    required String category,
    HintMode hintMode,
    int? maxPlayers,
  });

  Future<Room> join({required String joinCode});

  /// REST snapshot — the recovery source of truth after a gap/reconnect.
  Future<Room> snapshot({required String roomId});

  /// Host-only: begin the game.
  Future<Room> start({required String roomId});

  Future<V2GuessOutcome> guess({required String roomId, required String word});

  Future<AdaptiveHint> hint({
    required String roomId,
    HintMode mode,
    String difficulty,
  });

  Future<void> leave({required String roomId});
}

/// Realtime room event stream. Concrete wire handling (auth, ping/pong frames,
/// JSON envelope) lives in the implementation; controllers consume [RoomEvent]s.
abstract class RealtimeGateway {
  /// Ordered event stream for a room. Emits until [disconnect] or socket close.
  Stream<RoomEvent> connect({
    required String roomId,
    required String installationId,
  });

  /// Application-level keepalive.
  void sendPing();

  Future<void> disconnect();
}
