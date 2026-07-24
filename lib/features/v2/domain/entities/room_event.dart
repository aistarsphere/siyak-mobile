import 'room.dart';

/// The kinds of realtime room events the UI reacts to. The concrete wire
/// mapping is deferred to the realtime gateway once the V2 WebSocket contract
/// is known; controllers work only against this domain enum.
enum RoomEventType {
  guessAccepted,
  sharedDuplicate,
  participantJoined,
  participantLeft,
  hostChanged,
  hintRevealed,
  roomStarted,
  roomSolved,
  roomExpired,
  snapshot,
  pong,
  unknown,
}

/// A single ordered realtime event. [id] deduplicates; [seq] is monotonic and
/// used to detect gaps (→ REST snapshot recovery).
class RoomEvent {
  const RoomEvent({
    required this.id,
    required this.seq,
    required this.type,
    this.sharedGuess,
    this.participant,
    this.snapshot,
    this.winner,
    this.raw,
  });

  final String id;
  final int seq;
  final RoomEventType type;

  final SharedGuess? sharedGuess;
  final RoomParticipant? participant;
  final Room? snapshot;
  final RoomParticipant? winner;

  /// Original decoded payload, retained for forward-compatibility/logging.
  final Map<String, dynamic>? raw;
}
