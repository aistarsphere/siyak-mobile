import 'package:context_game/features/v2/domain/entities/adaptive_hint.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/hint_mode.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/domain/errors/v2_error.dart';
import 'package:context_game/features/v2/domain/repositories/v2_repositories.dart';

import 'mock_fixtures.dart';

/// PLACEHOLDER multiplayer REST repo. Holds one in-memory room so the lobby,
/// shared game and recovery flows are exercisable without a backend. TEST-ONLY.
class MockRoomRepository implements RoomRepository {
  Room? _room;
  int _roomSeq = 0;

  Room? get current => _room;

  @override
  Future<Room> create({
    required GameplayLanguage language,
    required String category,
    HintMode hintMode = HintMode.standard,
    int? maxPlayers,
  }) async {
    _roomSeq++;
    final me = const RoomParticipant(
      participantId: 'p-me',
      label: 'أنت',
      isHost: true,
      isMe: true,
    );
    _room = Room(
      roomId: 'room-$_roomSeq',
      joinCode: MockFixtures.roomJoinCode,
      language: language,
      category: category,
      categoryLabelAr: 'التقنية',
      categoryLabelEn: 'Technology',
      hintMode: hintMode,
      state: RoomState.lobby,
      participants: [me],
      sharedHistory: const [],
      totalWords: 22548,
      maxPlayers: maxPlayers ?? 4,
      hostId: 'p-me',
    );
    return _room!;
  }

  @override
  Future<Room> join({required String joinCode}) async {
    final code = joinCode.trim().toUpperCase();
    if (code.isEmpty || code.length < 4) {
      throw const V2Exception(V2ErrorCode.roomInvalid);
    }
    if (code != MockFixtures.roomJoinCode) {
      throw const V2Exception(V2ErrorCode.roomInvalid);
    }
    final me = const RoomParticipant(
      participantId: 'p-me',
      label: 'أنت',
      isHost: false,
      isMe: true,
    );
    _room = Room(
      roomId: 'room-joined',
      joinCode: code,
      language: GameplayLanguage.arabic,
      category: 'technology',
      categoryLabelAr: 'التقنية',
      categoryLabelEn: 'Technology',
      hintMode: HintMode.standard,
      state: RoomState.lobby,
      participants: [
        const RoomParticipant(
          participantId: 'p-host',
          label: 'المضيف',
          isHost: true,
        ),
        me,
      ],
      sharedHistory: const [],
      totalWords: 22548,
      maxPlayers: 4,
      hostId: 'p-host',
    );
    return _room!;
  }

  @override
  Future<Room> snapshot({required String roomId}) async =>
      _room ?? (throw const V2Exception(V2ErrorCode.roomExpired));

  @override
  Future<V2GuessOutcome> guess({
    required String roomId,
    required String word,
  }) async {
    final room = _room ?? (throw const V2Exception(V2ErrorCode.roomExpired));
    final secret = room.language.isArabic
        ? MockFixtures.secretWordAr
        : MockFixtures.secretWordEn;
    if (word == secret) {
      return V2GuessOutcome(
        accepted: true,
        duplicate: false,
        unknown: false,
        canonicalWord: word,
        rank: 1,
        proximity: 100,
        heatLevel: 'boiling',
        solved: true,
        secretWord: secret,
      );
    }
    if (!MockFixtures.vocab.containsKey(word)) {
      return const V2GuessOutcome(
        accepted: false,
        duplicate: false,
        unknown: true,
        suggestions: ['حاسوب', 'كود'],
      );
    }
    final already = room.sharedHistory.any((s) => s.guess.word == word);
    if (already) {
      final first = room.sharedHistory.firstWhere((s) => s.guess.word == word);
      return V2GuessOutcome(
        accepted: true,
        duplicate: true,
        unknown: false,
        canonicalWord: word,
        firstByLabel: first.byLabel,
      );
    }
    final g = MockFixtures.scored(word);
    return V2GuessOutcome(
      accepted: true,
      duplicate: false,
      unknown: false,
      canonicalWord: word,
      rank: g.rank,
      proximity: g.proximity,
      heatLevel: g.tier.name,
    );
  }

  @override
  Future<Room> start({required String roomId}) async {
    _room = _room?.copyWith(state: RoomState.playing) ??
        (throw const V2Exception(V2ErrorCode.roomExpired));
    return _room!;
  }

  @override
  Future<AdaptiveHint> hint({
    required String roomId,
    HintMode mode = HintMode.adaptive,
    String difficulty = 'medium',
  }) async =>
      const AdaptiveHint(
        number: 1,
        word: 'مسيرة',
        semanticRank: 100,
        hintsRemaining: 4,
        bestUserGeneratedRank: 5650,
      );

  @override
  Future<void> leave({required String roomId}) async {
    _room = null;
  }
}
