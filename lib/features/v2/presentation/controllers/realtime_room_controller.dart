import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/entities/room.dart';
import '../../domain/entities/room_event.dart';
import '../../domain/realtime/reconnect_policy.dart';
import '../../domain/realtime/sequence_tracker.dart';
import '../../domain/repositories/v2_repositories.dart';
import 'v2_providers.dart';

enum RoomConnStatus {
  idle,
  connecting,
  connected,
  recovering, // fetching a REST snapshot after a gap
  reconnecting, // socket dropped; backing off
  closed,
}

class RoomConnState {
  const RoomConnState({
    this.room,
    this.status = RoomConnStatus.idle,
    this.lastSeq,
    this.reconnectAttempt = 0,
  });

  final Room? room;
  final RoomConnStatus status;
  final int? lastSeq;
  final int reconnectAttempt;

  bool get isLive => status == RoomConnStatus.connected;

  RoomConnState copyWith({
    Room? room,
    RoomConnStatus? status,
    int? lastSeq,
    int? reconnectAttempt,
  }) => RoomConnState(
    room: room ?? this.room,
    status: status ?? this.status,
    lastSeq: lastSeq ?? this.lastSeq,
    reconnectAttempt: reconnectAttempt ?? this.reconnectAttempt,
  );
}

/// Drives one room's realtime connection: applies ordered events, deduplicates,
/// detects gaps → recovers from the REST snapshot (source of truth), and
/// reconnects with exponential backoff. Survives app resume / process restart
/// by re-fetching the snapshot on (re)connect.
class RealtimeRoomController extends Notifier<RoomConnState> {
  static const _policy = ReconnectPolicy();

  RealtimeGateway? _gateway;
  StreamSubscription<RoomEvent>? _sub;
  SequenceTracker _tracker = SequenceTracker();
  Timer? _reconnectTimer;
  String? _roomId;
  String? _installationId;
  bool _intentionalClose = false;

  @override
  RoomConnState build() {
    ref.onDispose(_teardown);
    return const RoomConnState();
  }

  RoomRepository get _rooms => ref.read(roomRepositoryProvider);

  /// Begin (or resume) a realtime session for [room]. Seeds state with the
  /// REST snapshot as the source of truth, then attaches the event stream.
  Future<void> connect(Room room, String installationId) async {
    _intentionalClose = false;
    _roomId = room.roomId;
    _installationId = installationId;
    _tracker = SequenceTracker();
    state = RoomConnState(room: room, status: RoomConnStatus.connecting);
    await _openSocket();
  }

  Future<void> _openSocket() async {
    await _sub?.cancel();
    await _gateway?.disconnect();
    _gateway = ref.read(realtimeGatewayProvider);
    // Refresh authoritative state on every (re)connect.
    try {
      final snap = await _rooms.snapshot(roomId: _roomId!);
      state = state.copyWith(room: snap, status: RoomConnStatus.connected);
    } catch (_) {
      // Keep whatever room we had; stream may still recover it.
    }
    final stream = _gateway!.connect(
      roomId: _roomId!,
      installationId: _installationId!,
    );
    _sub = stream.listen(
      _onEvent,
      onError: (_) => _scheduleReconnect(),
      onDone: () {
        if (!_intentionalClose) _scheduleReconnect();
      },
    );
    if (state.status != RoomConnStatus.connected) {
      state = state.copyWith(
        status: RoomConnStatus.connected,
        reconnectAttempt: 0,
      );
    } else {
      state = state.copyWith(reconnectAttempt: 0);
    }
  }

  Future<void> _onEvent(RoomEvent e) async {
    final verdict = _tracker.offer(id: e.id, seq: e.seq);
    switch (verdict) {
      case EventVerdict.duplicate:
      case EventVerdict.stale:
        return; // ignore
      case EventVerdict.gap:
        await _recoverFromSnapshot(e);
        return;
      case EventVerdict.ok:
        _apply(e);
        state = state.copyWith(lastSeq: _tracker.lastSeq);
        return;
    }
  }

  /// A gap was detected → the REST snapshot is the source of truth.
  Future<void> _recoverFromSnapshot(RoomEvent trigger) async {
    state = state.copyWith(status: RoomConnStatus.recovering);
    try {
      final snap = await _rooms.snapshot(roomId: _roomId!);
      // Apply the triggering event on top of the fresh snapshot, then accept
      // its seq as the new baseline.
      var room = snap;
      state = state.copyWith(room: room, status: RoomConnStatus.connected);
      _tracker.reconcile(id: trigger.id, seq: trigger.seq);
      room = _applied(room, trigger);
      state = state.copyWith(room: room, lastSeq: _tracker.lastSeq);
    } catch (_) {
      state = state.copyWith(status: RoomConnStatus.connected);
    }
  }

  void _apply(RoomEvent e) {
    final room = state.room;
    if (room == null) return;
    state = state.copyWith(room: _applied(room, e));
  }

  /// Pure-ish reducer: fold an event into a Room.
  Room _applied(Room room, RoomEvent e) {
    switch (e.type) {
      case RoomEventType.guessAccepted:
        final sg = e.sharedGuess;
        if (sg == null) return room;
        // Shared-duplicate guard: same canonical concept already present.
        final exists = room.sharedHistory.any(
          (s) => s.guess.word == sg.guess.word,
        );
        if (exists) return room;
        return room.copyWith(sharedHistory: [...room.sharedHistory, sg]);
      case RoomEventType.sharedDuplicate:
        return room; // surfaced as a transient message by the UI, no row
      case RoomEventType.participantJoined:
        final p = e.participant;
        if (p == null ||
            room.participants.any((x) => x.participantId == p.participantId)) {
          return room;
        }
        return room.copyWith(participants: [...room.participants, p]);
      case RoomEventType.participantLeft:
        final p = e.participant;
        if (p == null) return room;
        return room.copyWith(
          participants: [
            for (final x in room.participants)
              if (x.participantId == p.participantId)
                x.copyWith(connected: false)
              else
                x,
          ],
        );
      case RoomEventType.hostChanged:
        final p = e.participant;
        if (p == null) return room;
        return room.copyWith(
          hostId: p.participantId,
          participants: [
            for (final x in room.participants)
              RoomParticipant(
                participantId: x.participantId,
                label: x.label,
                isHost: x.participantId == p.participantId,
                connected: x.connected,
                isMe: x.isMe,
              ),
          ],
        );
      case RoomEventType.roomSolved:
        return room.copyWith(
          state: RoomState.solved,
          winner: e.winner,
          secretWord: e.snapshot?.secretWord ?? room.secretWord,
        );
      case RoomEventType.roomExpired:
        return room.copyWith(state: RoomState.expired);
      case RoomEventType.roomStarted:
        return room.copyWith(state: RoomState.playing);
      case RoomEventType.hintRevealed:
        // System hint → a distinct shared-history row (never a user guess).
        final sg = e.sharedGuess;
        if (sg == null) return room;
        return room.copyWith(sharedHistory: [...room.sharedHistory, sg]);
      case RoomEventType.snapshot:
        return e.snapshot ?? room;
      case RoomEventType.pong:
      case RoomEventType.unknown:
        return room;
    }
  }

  void _scheduleReconnect() {
    if (_intentionalClose) return;
    final attempt = state.reconnectAttempt;
    if (!_policy.shouldRetry(attempt)) {
      state = state.copyWith(status: RoomConnStatus.closed);
      return;
    }
    state = state.copyWith(
      status: RoomConnStatus.reconnecting,
      reconnectAttempt: attempt + 1,
    );
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(_policy.delayFor(attempt), () {
      if (!_intentionalClose) _openSocket();
    });
  }

  /// Append a guess the SERVER already accepted (not optimistic). Deduplicates
  /// on the canonical word so a shared concept never yields two rows.
  void addAcceptedGuess(SharedGuess sg) {
    final room = state.room;
    if (room == null) return;
    if (room.sharedHistory.any((s) => s.guess.word == sg.guess.word)) return;
    state = state.copyWith(
      room: room.copyWith(sharedHistory: [...room.sharedHistory, sg]),
    );
  }

  /// Mark the room solved (server-confirmed win).
  void markSolved({RoomParticipant? winner, String? secret}) {
    final room = state.room;
    if (room == null) return;
    state = state.copyWith(
      room: room.copyWith(
        state: RoomState.solved,
        winner: winner,
        secretWord: secret,
      ),
    );
  }

  /// Called on app resume / manual retry — re-fetch snapshot + resubscribe.
  Future<void> resume() async {
    if (_roomId == null || _installationId == null) return;
    await _openSocket();
  }

  Future<void> leave() async {
    _intentionalClose = true;
    await _teardown();
    state = const RoomConnState(status: RoomConnStatus.closed);
  }

  Future<void> _teardown() async {
    _reconnectTimer?.cancel();
    await _sub?.cancel();
    await _gateway?.disconnect();
    _sub = null;
    _gateway = null;
  }
}

final realtimeRoomControllerProvider =
    NotifierProvider<RealtimeRoomController, RoomConnState>(
      RealtimeRoomController.new,
    );
