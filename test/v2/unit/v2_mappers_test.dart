import 'package:context_game/features/v2/data/remote/v2_mappers.dart';
import 'package:context_game/features/v2/domain/entities/gameplay_language.dart';
import 'package:context_game/features/v2/domain/entities/room.dart';
import 'package:context_game/features/v2/domain/entities/room_event.dart';
import 'package:flutter_test/flutter_test.dart';

/// Mapper tests use REAL response bodies captured from the live V2 backend.
void main() {
  group('capabilities', () {
    test('maps feature flags', () {
      final c = V2Mappers.capabilities(const {
        'features': {
          'anonymous_profiles': true,
          'weekly_challenge': true,
          'multiplayer': true,
          'adaptive_hints': true,
        },
        'api_version': '2.0',
      });
      expect(c.available, isTrue);
      expect(c.weeklyEnabled, isTrue);
      expect(c.multiplayerEnabled, isTrue);
      expect(c.adaptiveHintsEnabled, isTrue);
      expect(c.apiVersion, '2.0');
    });
  });

  group('weekly run + guess', () {
    final guessBody = {
      'original_guess': 'بيت',
      'canonical_word': 'بيت',
      'display_word': 'بيت',
      'rank': 12905,
      'total_words': 14060,
      'similarity': 0.0183,
      'heat': {'tier': 1, 'label_ar': 'بارد', 'color': '#3b82f6', 'proximity': 0.1},
      'heat_level': 'cold',
      'proximity': 0.1,
      'solved': false,
      'duplicate': false,
      'accepted': true,
      'run_id': 'wr_x',
      'weekly_id': 'wk_x',
      'game_language': 'ar',
      'category': 'general',
      'status': 'in_progress',
      'user_guess_count': 1,
      'hint_count': 0,
      'best_rank': 12905,
      'guesses': [
        {'guess': 'بيت', 'word': 'بيت', 'rank': 12905, 'proximity': 0.1, 'heat_level': 'cold', 'solved': false},
      ],
      'secret_word': null,
    };

    test('maps run: attempts from server, secret hidden', () {
      final run = V2Mappers.weeklyRun(guessBody);
      expect(run.runId, 'wr_x');
      expect(run.language, GameplayLanguage.arabic);
      expect(run.attempts, 1);
      expect(run.bestUserGeneratedRank, 12905);
      expect(run.secretWord, isNull);
      expect(run.guesses.single.word, 'بيت');
      expect(run.guesses.single.rank, 12905);
    });

    test('maps guess outcome (accepted, not duplicate)', () {
      final o = V2Mappers.guessOutcome(guessBody);
      expect(o.accepted, isTrue);
      expect(o.duplicate, isFalse);
      expect(o.canonicalWord, 'بيت');
      expect(o.rank, 12905);
    });

    test('duplicate flag maps through', () {
      final o = V2Mappers.guessOutcome({...guessBody, 'duplicate': true});
      expect(o.duplicate, isTrue);
    });
  });

  group('adaptive hint', () {
    test('maps revealed word + rank, never an attempt', () {
      final h = V2Mappers.adaptiveHint(const {
        'hint_mode': 'adaptive',
        'revealed_word': 'للبنان',
        'semantic_rank': 89,
        'best_user_generated_rank': 12905,
        'hints_used': 1,
        'hints_remaining': 4,
      });
      expect(h.word, 'للبنان');
      expect(h.semanticRank, 89);
      expect(h.hintsRemaining, 4);
      expect(h.bestUserGeneratedRank, 12905);
    });
  });

  group('leaderboard', () {
    test('maps entries + highlights current profile', () {
      final page = V2Mappers.leaderboard(const {
        'total': 3,
        'limit': 3,
        'offset': 0,
        'entries': [
          {'placement': 1, 'profile_id': 'prof_a', 'display_name': 'لاعب', 'short_code': 'AAA', 'solved': false, 'guesses': 1, 'hints': 1},
          {'placement': 2, 'profile_id': 'prof_me', 'display_name': 'كاظم', 'short_code': 'ZZZ', 'solved': true, 'guesses': 5, 'hints': 0},
        ],
      }, myProfileId: 'prof_me');
      expect(page.entries, hasLength(2));
      expect(page.entries[1].isCurrentProfile, isTrue);
      expect(page.entries[1].label, 'كاظم');
      expect(page.entries[0].label, 'لاعب');
      expect(page.hasMore, isTrue); // offset+2 < total 3
    });
  });

  group('room + participants + shared history', () {
    final roomJson = {
      'room_id': 'room_x',
      'join_code': 'S33ZR',
      'language': 'ar',
      'category': 'general',
      'hint_mode': 'adaptive',
      'status': 'active',
      'host_profile_id': 'prof_host',
      'max_players': 8,
      'participants': [
        {'profile_id': 'prof_host', 'display_name': 'المضيف', 'short_code': 'HHH', 'role': 'host', 'connection_state': 'connected'},
        {'profile_id': 'prof_me', 'display_name': 'أنا', 'short_code': 'MMM', 'role': 'player', 'connection_state': 'connected'},
      ],
      'guesses': [
        {'ord': 1, 'by': {'profile_id': 'prof_host', 'display_name': 'المضيف', 'short_code': 'HHH'}, 'guess': 'بيت', 'word': 'بيت', 'rank': 5650, 'proximity': 3.7, 'heat': {'tier': 1}, 'solved': false},
      ],
      'hints': [
        {'ord': 2, 'by': {'profile_id': 'prof_host'}, 'revealed_word': 'مسيرة', 'semantic_rank': 100, 'proximity': 0.0},
      ],
      'winner': null,
      'winning_word': null,
      'secret_word': null,
      'seq': 4,
    };

    test('maps room, marks me/host, playing state', () {
      final room = V2Mappers.room(roomJson, 'prof_me');
      expect(room.state, RoomState.playing);
      expect(room.joinCode, 'S33ZR');
      expect(room.hintMode.code, 'adaptive');
      expect(room.participants, hasLength(2));
      expect(room.me?.label, 'أنا');
      expect(room.amHost, isFalse);
      expect(room.participants.firstWhere((p) => p.isHost).label, 'المضيف');
    });

    test('shared history: player guess + system hint, attribution', () {
      final room = V2Mappers.room(roomJson, 'prof_me');
      expect(room.sharedHistory, hasLength(2));
      final g = room.sharedHistory.firstWhere((s) => !s.isSystemHint);
      expect(g.guess.word, 'بيت');
      expect(g.byLabel, 'المضيف');
      expect(g.isMine, isFalse);
      final h = room.sharedHistory.firstWhere((s) => s.isSystemHint);
      expect(h.guess.word, 'مسيرة');
      expect(h.isSystemHint, isTrue);
    });
  });

  group('realtime events', () {
    test('room.snapshot → snapshot event with room', () {
      final e = V2Mappers.roomEvent(const {
        'type': 'room.snapshot',
        'seq': 0,
        'snapshot': {'room_id': 'room_x', 'join_code': 'AB', 'status': 'lobby', 'participants': [], 'guesses': [], 'hints': []},
      }, 'prof_me');
      expect(e.type, RoomEventType.snapshot);
      expect(e.seq, 0);
      expect(e.snapshot?.roomId, 'room_x');
    });

    test('guess.accepted → shared guess with seq + event id', () {
      final e = V2Mappers.roomEvent(const {
        'event_id': 'evt_1',
        'seq': 3,
        'type': 'guess.accepted',
        'by': {'profile_id': 'prof_me', 'display_name': 'أنا', 'short_code': 'M'},
        'guess': 'سيارة',
        'canonical_word': 'سيارة',
        'rank': 11334,
        'proximity': 4.1,
        'heat': {'tier': 1},
      }, 'prof_me');
      expect(e.type, RoomEventType.guessAccepted);
      expect(e.id, 'evt_1');
      expect(e.seq, 3);
      expect(e.sharedGuess?.guess.word, 'سيارة');
      expect(e.sharedGuess?.isMine, isTrue);
    });

    test('participant.joined + room.started + hint.revealed', () {
      expect(
          V2Mappers.roomEvent(const {'event_id': 'e', 'seq': 1, 'type': 'participant.joined', 'participant': {'profile_id': 'p', 'display_name': 'x', 'short_code': 's'}}, null).type,
          RoomEventType.participantJoined);
      expect(
          V2Mappers.roomEvent(const {'event_id': 'e', 'seq': 2, 'type': 'room.started'}, null).type,
          RoomEventType.roomStarted);
      final hint = V2Mappers.roomEvent(const {'event_id': 'e', 'seq': 4, 'type': 'hint.revealed', 'by': {'profile_id': 'p'}, 'revealed_word': 'لسكان', 'semantic_rank': 59}, null);
      expect(hint.type, RoomEventType.hintRevealed);
      expect(hint.sharedGuess?.isSystemHint, isTrue);
      expect(hint.sharedGuess?.guess.word, 'لسكان');
    });
  });
}
