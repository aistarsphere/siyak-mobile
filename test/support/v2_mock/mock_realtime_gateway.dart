import 'dart:async';

import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/domain/entities/room_event.dart';
import 'package:context_game/features/v2/domain/repositories/v2_repositories.dart';

import 'mock_fixtures.dart';

/// PLACEHOLDER realtime gateway. Emits a scripted, ordered event sequence that
/// deliberately INCLUDES A GAP (skips seq 3) so the reconnect/snapshot-recovery
/// logic in the controller can be exercised deterministically. TEST-ONLY.
class MockRealtimeGateway implements RealtimeGateway {
  StreamController<RoomEvent>? _controller;

  /// Set of scripted events; seq intentionally jumps 2 → 4 (gap at 3).
  List<RoomEvent> scriptedEvents(String roomId) => [
    RoomEvent(
      id: 'e1',
      seq: 1,
      type: RoomEventType.participantJoined,
      participant: const RoomParticipant(
        participantId: 'p-friend',
        label: 'صديق',
        isHost: false,
      ),
    ),
    RoomEvent(
      id: 'e2',
      seq: 2,
      type: RoomEventType.guessAccepted,
      sharedGuess: SharedGuess(
        guess: MockFixtures.scored('شبكة'),
        byParticipantId: 'p-friend',
        byLabel: 'صديق',
      ),
    ),
    // seq 3 intentionally missing → gap → snapshot recovery expected.
    RoomEvent(
      id: 'e4',
      seq: 4,
      type: RoomEventType.guessAccepted,
      sharedGuess: SharedGuess(
        guess: MockFixtures.scored('حاسوب'),
        byParticipantId: 'p-me',
        byLabel: 'أنت',
        isMine: true,
      ),
    ),
  ];

  @override
  Stream<RoomEvent> connect({
    required String roomId,
    required String installationId,
  }) {
    _controller = StreamController<RoomEvent>();
    // Emit synchronously-scheduled events; tests pump the microtask queue.
    Future(() async {
      for (final e in scriptedEvents(roomId)) {
        if (_controller?.isClosed ?? true) return;
        _controller!.add(e);
      }
    });
    return _controller!.stream;
  }

  /// Test hook: push an arbitrary event (e.g. a duplicate id, or roomSolved).
  void emit(RoomEvent e) {
    if (!(_controller?.isClosed ?? true)) _controller!.add(e);
  }

  @override
  void sendPing() {
    /* mock: no-op */
  }

  @override
  Future<void> disconnect() async {
    await _controller?.close();
    _controller = null;
  }
}
