import 'dart:async';

import '../../support/v2_mock/mock_fixtures.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/adaptive_hint.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/domain/entities/room_event.dart';
import 'package:context_game/features/v2/domain/repositories/v2_repositories.dart';
import 'package:context_game/features/v2/presentation/controllers/realtime_room_controller.dart';
import 'package:context_game/features/v2/presentation/controllers/v2_providers.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// A gateway the test drives frame-by-frame.
class _ControllableGateway implements RealtimeGateway {
  final _c = StreamController<RoomEvent>.broadcast();
  int pings = 0;
  bool closed = false;

  @override
  Stream<RoomEvent> connect({
    required String roomId,
    required String installationId,
  }) => _c.stream;

  void push(RoomEvent e) => _c.add(e);

  @override
  void sendPing() => pings++;

  @override
  Future<void> disconnect() async {
    closed = true;
    await _c.close();
  }
}

/// A room repo whose REST snapshot is the recovery source of truth (settable).
class _FakeRoomRepo implements RoomRepository {
  _FakeRoomRepo(this.room);
  Room room;

  @override
  Future<Room> snapshot({required String roomId}) async => room;

  @override
  Future<Room> create({
    required GameplayLanguage language,
    required String category,
    HintMode hintMode = HintMode.standard,
    int? maxPlayers,
  }) async => room;
  @override
  Future<Room> join({required String joinCode}) async => room;
  @override
  Future<V2GuessOutcome> guess({
    required String roomId,
    required String word,
  }) async =>
      const V2GuessOutcome(accepted: true, duplicate: false, unknown: false);
  @override
  Future<Room> start({required String roomId}) async =>
      room.copyWith(state: RoomState.playing);
  @override
  Future<AdaptiveHint> hint({
    required String roomId,
    HintMode mode = HintMode.adaptive,
    String difficulty = 'medium',
  }) async =>
      const AdaptiveHint(
          number: 1, word: 'x', semanticRank: 50, hintsRemaining: 4);
  @override
  Future<void> leave({required String roomId}) async {}
}

Room _baseRoom({List<SharedGuess> history = const []}) => Room(
  roomId: 'r1',
  joinCode: MockFixtures.roomJoinCode,
  language: GameplayLanguage.arabic,
  category: 'technology',
  categoryLabelAr: 'التقنية',
  categoryLabelEn: 'Technology',
  hintMode: HintMode.standard,
  state: RoomState.playing,
  participants: const [
    RoomParticipant(
      participantId: 'p-me',
      label: 'أنت',
      isHost: true,
      isMe: true,
    ),
  ],
  sharedHistory: history,
  totalWords: 22548,
  hostId: 'p-me',
);

SharedGuess _sg(String word, {bool mine = false, String by = 'صديق'}) =>
    SharedGuess(
      guess: MockFixtures.scored(word),
      byParticipantId: mine ? 'p-me' : 'p-friend',
      byLabel: mine ? 'أنت' : by,
      isMine: mine,
    );

Future<void> settle() async {
  for (var i = 0; i < 8; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  ProviderContainer make(_ControllableGateway gw, _FakeRoomRepo repo) =>
      ProviderContainer(
        overrides: [
          realtimeGatewayProvider.overrideWithValue(gw),
          roomRepositoryProvider.overrideWithValue(repo),
        ],
      );

  test('applies in-order guess events to shared history', () async {
    final gw = _ControllableGateway();
    final repo = _FakeRoomRepo(_baseRoom());
    final c = make(gw, repo);
    addTearDown(c.dispose);

    await c
        .read(realtimeRoomControllerProvider.notifier)
        .connect(_baseRoom(), 'inst-1');
    await settle();

    gw.push(
      RoomEvent(
        id: 'e1',
        seq: 1,
        type: RoomEventType.guessAccepted,
        sharedGuess: _sg('شبكة'),
      ),
    );
    await settle();
    gw.push(
      RoomEvent(
        id: 'e2',
        seq: 2,
        type: RoomEventType.guessAccepted,
        sharedGuess: _sg('حرب'),
      ),
    );
    await settle();

    final room = c.read(realtimeRoomControllerProvider).room!;
    expect(room.sharedHistory.map((s) => s.guess.word), ['شبكة', 'حرب']);
    expect(c.read(realtimeRoomControllerProvider).lastSeq, 2);
  });

  test('deduplicates a repeated event id', () async {
    final gw = _ControllableGateway();
    final c = make(gw, _FakeRoomRepo(_baseRoom()));
    addTearDown(c.dispose);
    await c
        .read(realtimeRoomControllerProvider.notifier)
        .connect(_baseRoom(), 'i');
    await settle();

    final e = RoomEvent(
      id: 'dup',
      seq: 1,
      type: RoomEventType.guessAccepted,
      sharedGuess: _sg('شبكة'),
    );
    gw.push(e);
    await settle();
    gw.push(e); // same id
    await settle();

    expect(
      c.read(realtimeRoomControllerProvider).room!.sharedHistory,
      hasLength(1),
    );
  });

  test(
    'sequence gap → recovers from REST snapshot (source of truth)',
    () async {
      final gw = _ControllableGateway();
      // Server truth already contains شبكة (the event that filled the gap).
      final repo = _FakeRoomRepo(_baseRoom(history: [_sg('شبكة'), _sg('حرب')]));
      final c = make(gw, repo);
      addTearDown(c.dispose);
      await c
          .read(realtimeRoomControllerProvider.notifier)
          .connect(_baseRoom(), 'i');
      await settle();

      gw.push(
        RoomEvent(
          id: 'e1',
          seq: 1,
          type: RoomEventType.guessAccepted,
          sharedGuess: _sg('شبكة'),
        ),
      );
      await settle();
      // Jump to seq 4 → gap at 2,3 → snapshot recovery.
      gw.push(
        RoomEvent(
          id: 'e4',
          seq: 4,
          type: RoomEventType.guessAccepted,
          sharedGuess: _sg('حاسوب', mine: true),
        ),
      );
      await settle();

      final st = c.read(realtimeRoomControllerProvider);
      // Snapshot restored شبكة + حرب; the triggering e4 (حاسوب) applied on top.
      final words = st.room!.sharedHistory.map((s) => s.guess.word).toSet();
      expect(words.containsAll(['شبكة', 'حرب', 'حاسوب']), isTrue);
      expect(st.lastSeq, 4);
    },
  );

  test('room solved event stops the game and records the winner', () async {
    final gw = _ControllableGateway();
    final c = make(gw, _FakeRoomRepo(_baseRoom()));
    addTearDown(c.dispose);
    await c
        .read(realtimeRoomControllerProvider.notifier)
        .connect(_baseRoom(), 'i');
    await settle();

    gw.push(
      RoomEvent(
        id: 'win',
        seq: 1,
        type: RoomEventType.roomSolved,
        winner: const RoomParticipant(
          participantId: 'p-friend',
          label: 'صديق',
          isHost: false,
        ),
      ),
    );
    await settle();

    final room = c.read(realtimeRoomControllerProvider).room!;
    expect(room.isSolved, isTrue);
    expect(room.winner?.label, 'صديق');
  });

  test('participant join/leave updates the roster', () async {
    final gw = _ControllableGateway();
    final c = make(gw, _FakeRoomRepo(_baseRoom()));
    addTearDown(c.dispose);
    await c
        .read(realtimeRoomControllerProvider.notifier)
        .connect(_baseRoom(), 'i');
    await settle();

    gw.push(
      const RoomEvent(
        id: 'j',
        seq: 1,
        type: RoomEventType.participantJoined,
        participant: RoomParticipant(
          participantId: 'p2',
          label: 'لاعب٢',
          isHost: false,
        ),
      ),
    );
    await settle();
    expect(
      c.read(realtimeRoomControllerProvider).room!.participants,
      hasLength(2),
    );

    gw.push(
      const RoomEvent(
        id: 'l',
        seq: 2,
        type: RoomEventType.participantLeft,
        participant: RoomParticipant(
          participantId: 'p2',
          label: 'لاعب٢',
          isHost: false,
        ),
      ),
    );
    await settle();
    final p2 = c
        .read(realtimeRoomControllerProvider)
        .room!
        .participants
        .firstWhere((p) => p.participantId == 'p2');
    expect(p2.connected, isFalse);
  });

  test('leave tears down the socket', () async {
    final gw = _ControllableGateway();
    final c = make(gw, _FakeRoomRepo(_baseRoom()));
    addTearDown(c.dispose);
    await c
        .read(realtimeRoomControllerProvider.notifier)
        .connect(_baseRoom(), 'i');
    await settle();
    await c.read(realtimeRoomControllerProvider.notifier).leave();
    expect(gw.closed, isTrue);
  });
}
