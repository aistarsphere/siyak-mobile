import '../../domain/errors/v2_error.dart';

/// Maps the backend V2 error-envelope `error.code` strings to the app's
/// [V2ErrorCode] enum. Unknown codes fall back to [V2ErrorCode.unknown].
class V2ErrorMapper {
  V2ErrorMapper._();

  static V2ErrorCode fromCode(String? code) {
    switch (code) {
      case 'PROFILE_BLOCKED':
        return V2ErrorCode.profileBlocked;
      case 'UNSUPPORTED_API_VERSION':
      case 'VERSION_MISMATCH':
        return V2ErrorCode.unsupportedApiVersion;
      case 'WEEKLY_UNAVAILABLE':
      case 'WEEKLY_NOT_ACTIVE':
        return V2ErrorCode.weeklyUnavailable;
      case 'WEEKLY_EXPIRED':
      case 'WEEKLY_CLOSED':
        return V2ErrorCode.weeklyExpired;
      case 'WEEKLY_COMPLETED':
      case 'WEEKLY_ALREADY_SOLVED':
        return V2ErrorCode.weeklyCompleted;
      case 'WEEKLY_RUN_NOT_FOUND':
        return V2ErrorCode.weeklyExpired;
      case 'ROOM_CODE_INVALID':
      case 'ROOM_NOT_FOUND':
        return V2ErrorCode.roomInvalid;
      case 'ROOM_FULL':
        return V2ErrorCode.roomFull;
      case 'ROOM_ALREADY_STARTED':
      case 'ROOM_STARTED':
        return V2ErrorCode.roomStarted;
      case 'ROOM_SOLVED':
      case 'GAME_FINISHED':
        return V2ErrorCode.roomSolved;
      case 'ROOM_EXPIRED':
      case 'ROOM_CANCELLED':
        return V2ErrorCode.roomExpired;
      case 'DUPLICATE_GUESS':
        return V2ErrorCode.duplicateRoomGuess;
      case 'HINT_LIMIT':
      case 'HINT_LIMIT_REACHED':
        return V2ErrorCode.hintLimit;
      case 'ADAPTIVE_HINT_UNAVAILABLE':
        return V2ErrorCode.adaptiveHintUnavailable;
      case 'RATE_LIMITED':
      case 'TOO_MANY_REQUESTS':
        return V2ErrorCode.rateLimited;
      default:
        return V2ErrorCode.unknown;
    }
  }
}
