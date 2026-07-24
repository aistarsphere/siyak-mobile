import '../../../game/domain/entities/guess.dart';
import 'gameplay_language.dart';
import 'hint_mode.dart';

enum RoomState { lobby, playing, solved, expired }

class RoomParticipant {
  const RoomParticipant({
    required this.participantId,
    required this.label,
    required this.isHost,
    this.connected = true,
    this.isMe = false,
  });

  final String participantId;

  /// Display name or fallback short code — never an installation ID.
  final String label;
  final bool isHost;
  final bool connected;
  final bool isMe;

  RoomParticipant copyWith({bool? connected}) => RoomParticipant(
    participantId: participantId,
    label: label,
    isHost: isHost,
    connected: connected ?? this.connected,
    isMe: isMe,
  );
}

/// One entry in the shared, live guess history of a room.
class SharedGuess {
  const SharedGuess({
    required this.guess,
    required this.byParticipantId,
    required this.byLabel,
    this.isMine = false,
    this.isSystemHint = false,
  });

  final Guess guess;
  final String byParticipantId;
  final String byLabel;
  final bool isMine;
  final bool isSystemHint;
}

class Room {
  const Room({
    required this.roomId,
    required this.joinCode,
    required this.language,
    required this.category,
    required this.categoryLabelAr,
    required this.categoryLabelEn,
    required this.hintMode,
    required this.state,
    required this.participants,
    required this.sharedHistory,
    required this.totalWords,
    this.maxPlayers,
    this.hostId,
    this.winner,
    this.secretWord,
  });

  final String roomId;
  final String joinCode;
  final GameplayLanguage language;
  final String category;
  final String categoryLabelAr;
  final String categoryLabelEn;
  final HintMode hintMode;
  final RoomState state;
  final List<RoomParticipant> participants;
  final List<SharedGuess> sharedHistory;
  final int totalWords;
  final int? maxPlayers;
  final String? hostId;
  final RoomParticipant? winner;
  final String? secretWord;

  bool get isSolved => state == RoomState.solved;

  String categoryLabel(bool arabic) =>
      arabic ? categoryLabelAr : categoryLabelEn;

  RoomParticipant? get me {
    for (final p in participants) {
      if (p.isMe) return p;
    }
    return null;
  }

  bool get amHost => me?.isHost ?? false;

  List<SharedGuess> get sortedHistory =>
      [...sharedHistory]..sort((a, b) => a.guess.rank.compareTo(b.guess.rank));

  Room copyWith({
    RoomState? state,
    List<RoomParticipant>? participants,
    List<SharedGuess>? sharedHistory,
    RoomParticipant? winner,
    String? secretWord,
    String? hostId,
  }) => Room(
    roomId: roomId,
    joinCode: joinCode,
    language: language,
    category: category,
    categoryLabelAr: categoryLabelAr,
    categoryLabelEn: categoryLabelEn,
    hintMode: hintMode,
    state: state ?? this.state,
    participants: participants ?? this.participants,
    sharedHistory: sharedHistory ?? this.sharedHistory,
    totalWords: totalWords,
    maxPlayers: maxPlayers,
    hostId: hostId ?? this.hostId,
    winner: winner ?? this.winner,
    secretWord: secretWord ?? this.secretWord,
  );
}
