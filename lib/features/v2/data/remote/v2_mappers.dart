import '../../../game/domain/entities/guess.dart';
import '../../../game/domain/entities/heat.dart';
import '../../domain/entities/adaptive_hint.dart';
import '../../domain/entities/gameplay_language.dart';
import '../../domain/entities/hint_mode.dart';
import '../../domain/entities/installation_profile.dart';
import '../../domain/entities/leaderboard.dart';
import '../../domain/entities/room.dart';
import '../../domain/entities/room_event.dart';
import '../../domain/entities/v2_capabilities.dart';
import '../../domain/entities/weekly.dart';
import '../../domain/repositories/v2_repositories.dart';

/// Pure JSON → domain translation for API V2. Kept in one place so DTO shape
/// changes touch nothing else. No business logic; the backend is authoritative.
class V2Mappers {
  V2Mappers._();

  // ---- category labels (codes → localized; codes are the only thing the API
  // returns for weekly/room). Presentation strings, not invented API. --------
  static const _catAr = {
    'general': 'عام',
    'animals': 'الحيوانات',
    'sports': 'الرياضة',
    'agriculture': 'الزراعة',
    'technology': 'التقنية',
    'food': 'الطعام',
    'geography': 'الجغرافيا',
  };
  static const _catEn = {
    'general': 'General',
    'animals': 'Animals',
    'sports': 'Sports',
    'agriculture': 'Agriculture',
    'technology': 'Technology',
    'food': 'Food',
    'geography': 'Geography',
  };
  static String catAr(String code) => _catAr[code] ?? code;
  static String catEn(String code) => _catEn[code] ?? code;

  static int? _int(dynamic v) => v == null ? null : (v as num).toInt();
  static double _dbl(dynamic v) => v == null ? 0 : (v as num).toDouble();

  static DateTime? _date(dynamic v) =>
      v is String ? DateTime.tryParse(v) : null;

  // ---- capabilities --------------------------------------------------------
  static V2Capabilities capabilities(Map<String, dynamic> j) {
    final f = (j['features'] as Map<String, dynamic>?) ?? const {};
    return V2Capabilities(
      available: true,
      weeklyEnabled: f['weekly_challenge'] == true,
      multiplayerEnabled: f['multiplayer'] == true,
      adaptiveHintsEnabled: f['adaptive_hints'] == true,
      apiVersion: j['api_version']?.toString(),
    );
  }

  // ---- profile -------------------------------------------------------------
  static InstallationProfile profile(
    Map<String, dynamic> j, {
    required String installationId,
    InstallationProfile? mergeStats,
  }) =>
      InstallationProfile(
        installationId: installationId,
        profileId: j['profile_id']?.toString(),
        shortCode: (j['short_code'] ?? '').toString(),
        displayName: j['display_name'] as String?,
        gamesPlayed: mergeStats?.gamesPlayed ?? 0,
        gamesSolved: mergeStats?.gamesSolved ?? 0,
        roomsJoined: mergeStats?.roomsJoined ?? 0,
        roomsWon: mergeStats?.roomsWon ?? 0,
      );

  static InstallationProfile withStats(
          InstallationProfile p, Map<String, dynamic> s) =>
      p.copyWith(
        gamesPlayed: _int(s['weekly_played']) ?? p.gamesPlayed,
        gamesSolved: _int(s['weekly_solved']) ?? p.gamesSolved,
        roomsJoined: _int(s['rooms_joined']) ?? p.roomsJoined,
        roomsWon: _int(s['rooms_won']) ?? p.roomsWon,
      );

  // ---- heat / guess --------------------------------------------------------
  static Guess guessEntry(Map<String, dynamic> j) {
    final prox = _dbl(j['proximity']);
    final level = j['heat_level'] as String?;
    return Guess(
      word: (j['word'] ?? j['canonical_word'] ?? j['guess'] ?? '').toString(),
      rank: _int(j['rank']) ?? 0,
      proximity: prox,
      tier: Heat.fromLevel(level, prox),
      isSecret: j['solved'] == true,
    );
  }

  // ---- weekly --------------------------------------------------------------
  static WeeklyChallenge weeklyChallenge(Map<String, dynamic> j) {
    final end = _date(j['end_at']);
    final now = DateTime.now().toUtc();
    final remaining = end != null && end.isAfter(now) ? end.difference(now) : null;
    final status = (j['status'] ?? 'active').toString();
    final cat = (j['category'] ?? 'general').toString();
    return WeeklyChallenge(
      weekId: (j['weekly_id'] ?? '').toString(),
      language: GameplayLanguage.fromCode(j['language'] as String?),
      category: cat,
      categoryLabelAr: catAr(cat),
      categoryLabelEn: catEn(cat),
      state: status == 'completed' || status == 'closed'
          ? WeeklyState.completed
          : WeeklyState.active,
      timeRemaining: remaining,
    );
  }

  static WeeklyRun weeklyRun(Map<String, dynamic> j) {
    final cat = (j['category'] ?? 'general').toString();
    final guesses = (j['guesses'] as List<dynamic>? ?? const [])
        .map((e) => guessEntry(e as Map<String, dynamic>))
        .toList();
    return WeeklyRun(
      runId: (j['run_id'] ?? '').toString(),
      weekId: (j['weekly_id'] ?? '').toString(),
      language: GameplayLanguage.fromCode(j['game_language'] as String?),
      category: cat,
      totalWords: _int(j['total_words']) ?? 0,
      guesses: guesses,
      solved: j['status'] == 'solved' || j['solved_at'] != null,
      attempts: _int(j['user_guess_count']) ?? guesses.length,
      hintsUsed: _int(j['hint_count']) ?? 0,
      hintsRemaining: _int(j['hints_remaining']) ??
          (5 - (_int(j['hint_count']) ?? 0)).clamp(0, 5),
      maxHints: 5,
      bestUserGeneratedRank: _int(j['best_rank']),
      secretWord: j['secret_word'] as String?,
      elapsed: _int(j['elapsed_ms']) != null
          ? Duration(milliseconds: _int(j['elapsed_ms'])!)
          : null,
    );
  }

  /// Guess outcome from the top-level fields of a weekly/room guess response.
  static V2GuessOutcome guessOutcome(Map<String, dynamic> j) => V2GuessOutcome(
        accepted: j['accepted'] != false,
        duplicate: j['duplicate'] == true,
        unknown: false,
        canonicalWord:
            (j['canonical_word'] ?? j['display_word'] ?? j['word'])?.toString(),
        originalWord: j['original_guess'] as String?,
        rank: _int(j['rank']),
        proximity: j['proximity'] == null ? null : _dbl(j['proximity']),
        heatLevel: j['heat_level'] as String?,
        solved: j['solved'] == true,
        secretWord: j['secret_word'] as String?,
      );

  static AdaptiveHint adaptiveHint(Map<String, dynamic> j) => AdaptiveHint(
        number: _int(j['hints_used']) ?? 0,
        word: (j['revealed_word'] ?? '').toString(),
        semanticRank: _int(j['semantic_rank']) ?? 0,
        hintsRemaining: _int(j['hints_remaining']) ?? 0,
        bestUserGeneratedRank: _int(j['best_user_generated_rank']),
      );

  // ---- leaderboard ---------------------------------------------------------
  static LeaderboardPage leaderboard(
    Map<String, dynamic> j, {
    String? myProfileId,
    int? currentPlacement,
  }) {
    final entries = (j['entries'] as List<dynamic>? ?? const [])
        .map((e) => leaderboardEntry(e as Map<String, dynamic>, myProfileId))
        .toList();
    final limit = _int(j['limit']) ?? entries.length;
    final offset = _int(j['offset']) ?? 0;
    final total = _int(j['total']) ?? entries.length;
    return LeaderboardPage(
      entries: entries,
      page: limit == 0 ? 0 : offset ~/ (limit == 0 ? 1 : limit),
      hasMore: offset + entries.length < total,
      currentPlacement: currentPlacement,
    );
  }

  static LeaderboardEntry leaderboardEntry(
      Map<String, dynamic> j, String? myProfileId) {
    final name = j['display_name'] as String?;
    final short = (j['short_code'] ?? '').toString();
    return LeaderboardEntry(
      placement: _int(j['placement']) ?? 0,
      label: (name != null && name.trim().isNotEmpty) ? name : short,
      solved: j['solved'] == true,
      attempts: _int(j['guesses']) ?? 0,
      hintsUsed: _int(j['hints']) ?? 0,
      elapsed: _int(j['elapsed_ms']) != null
          ? Duration(milliseconds: _int(j['elapsed_ms'])!)
          : null,
      isCurrentProfile:
          myProfileId != null && j['profile_id']?.toString() == myProfileId,
    );
  }

  // ---- rooms ---------------------------------------------------------------
  static HintMode hintMode(String? code) => HintMode.fromCode(code);

  static RoomState roomState(String? s) => switch (s) {
        'active' => RoomState.playing,
        'solved' || 'finished' => RoomState.solved,
        'cancelled' || 'expired' => RoomState.expired,
        _ => RoomState.lobby,
      };

  static RoomParticipant participant(
      Map<String, dynamic> j, String? myProfileId) {
    final pid = (j['profile_id'] ?? '').toString();
    final name = j['display_name'] as String?;
    final short = (j['short_code'] ?? '').toString();
    return RoomParticipant(
      participantId: pid,
      label: (name != null && name.trim().isNotEmpty) ? name : short,
      isHost: j['role'] == 'host',
      connected: (j['connection_state'] ?? 'connected') == 'connected',
      isMe: myProfileId != null && pid == myProfileId,
    );
  }

  static SharedGuess sharedFromRoomGuess(
      Map<String, dynamic> j, String? myProfileId,
      {bool systemHint = false}) {
    final by = (j['by'] as Map<String, dynamic>?) ?? const {};
    final byId = (by['profile_id'] ?? '').toString();
    final byName = by['display_name'] as String?;
    final byShort = (by['short_code'] ?? '').toString();
    final prox = _dbl(j['proximity']);
    return SharedGuess(
      guess: Guess(
        word: (j['word'] ??
                j['canonical_word'] ??
                j['revealed_word'] ??
                j['guess'] ??
                '')
            .toString(),
        rank: _int(j['rank'] ?? j['semantic_rank']) ?? 0,
        proximity: prox,
        tier: Heat.fromLevel(j['heat_level'] as String?, prox),
        isSecret: j['solved'] == true,
      ),
      byParticipantId: byId,
      byLabel: (byName != null && byName.trim().isNotEmpty) ? byName : byShort,
      isMine: myProfileId != null && byId == myProfileId,
      isSystemHint: systemHint,
    );
  }

  static Room room(Map<String, dynamic> j, String? myProfileId) {
    final cat = (j['category'] ?? 'general').toString();
    final participants = (j['participants'] as List<dynamic>? ?? const [])
        .map((e) => participant(e as Map<String, dynamic>, myProfileId))
        .toList();
    final history = <SharedGuess>[
      for (final g in (j['guesses'] as List<dynamic>? ?? const []))
        sharedFromRoomGuess(g as Map<String, dynamic>, myProfileId),
      for (final h in (j['hints'] as List<dynamic>? ?? const []))
        sharedFromRoomGuess(h as Map<String, dynamic>, myProfileId,
            systemHint: true),
    ];
    final winnerJson = j['winner'];
    RoomParticipant? winner;
    if (winnerJson is Map<String, dynamic>) {
      winner = participant(winnerJson, myProfileId);
    }
    return Room(
      roomId: (j['room_id'] ?? '').toString(),
      joinCode: (j['join_code'] ?? '').toString(),
      language: GameplayLanguage.fromCode(j['language'] as String?),
      category: cat,
      categoryLabelAr: catAr(cat),
      categoryLabelEn: catEn(cat),
      hintMode: hintMode(j['hint_mode'] as String?),
      state: roomState(j['status'] as String?),
      participants: participants,
      sharedHistory: history,
      totalWords: _int(j['total_words']) ?? 0,
      maxPlayers: _int(j['max_players']),
      hostId: j['host_profile_id']?.toString(),
      winner: winner,
      secretWord: (j['winning_word'] ?? j['secret_word']) as String?,
    );
  }

  // ---- realtime events -----------------------------------------------------
  static RoomEvent roomEvent(Map<String, dynamic> j, String? myProfileId) {
    final type = (j['type'] ?? '').toString();
    final seq = _int(j['seq']) ?? 0;
    final id = (j['event_id'] ?? 'seed-$seq').toString();
    switch (type) {
      case 'room.snapshot':
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.snapshot,
          snapshot: room(
              (j['snapshot'] as Map<String, dynamic>?) ?? const {}, myProfileId),
          raw: j,
        );
      case 'participant.joined':
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.participantJoined,
          participant: participant(
              (j['participant'] as Map<String, dynamic>?) ?? const {},
              myProfileId),
          raw: j,
        );
      case 'participant.left':
      case 'participant.disconnected':
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.participantLeft,
          participant: participant(
              (j['participant'] as Map<String, dynamic>?) ?? const {},
              myProfileId),
          raw: j,
        );
      case 'host.changed':
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.hostChanged,
          participant: participant(
              (j['participant'] as Map<String, dynamic>?) ??
                  {'profile_id': j['host_profile_id']},
              myProfileId),
          raw: j,
        );
      case 'room.started':
        return RoomEvent(
            id: id, seq: seq, type: RoomEventType.roomStarted, raw: j);
      case 'guess.accepted':
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.guessAccepted,
          sharedGuess: sharedFromRoomGuess(j, myProfileId),
          raw: j,
        );
      case 'hint.revealed':
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.hintRevealed,
          sharedGuess: sharedFromRoomGuess(j, myProfileId, systemHint: true),
          raw: j,
        );
      case 'room.solved':
      case 'game.finished':
        final w = j['winner'];
        return RoomEvent(
          id: id,
          seq: seq,
          type: RoomEventType.roomSolved,
          winner: w is Map<String, dynamic> ? participant(w, myProfileId) : null,
          snapshot: j['winning_word'] != null || j['secret_word'] != null
              ? Room(
                  roomId: (j['room_id'] ?? '').toString(),
                  joinCode: '',
                  language: GameplayLanguage.arabic,
                  category: 'general',
                  categoryLabelAr: '',
                  categoryLabelEn: '',
                  hintMode: HintMode.standard,
                  state: RoomState.solved,
                  participants: const [],
                  sharedHistory: const [],
                  totalWords: 0,
                  secretWord:
                      (j['winning_word'] ?? j['secret_word']) as String?,
                )
              : null,
          raw: j,
        );
      case 'room.cancelled':
      case 'room.expired':
        return RoomEvent(
            id: id, seq: seq, type: RoomEventType.roomExpired, raw: j);
      case 'pong':
      case 'ping':
        return RoomEvent(id: id, seq: seq, type: RoomEventType.pong, raw: j);
      default:
        return RoomEvent(id: id, seq: seq, type: RoomEventType.unknown, raw: j);
    }
  }
}
