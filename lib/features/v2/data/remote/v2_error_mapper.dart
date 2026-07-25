import '../../domain/errors/v2_error.dart';

/// Maps the backend V2 error-envelope `error.code` strings (frozen contract
/// `12-error-codes.md`) to the app's [V2ErrorCode]. Unknown codes fall back to
/// [V2ErrorCode.unknown].
class V2ErrorMapper {
  V2ErrorMapper._();

  static const _map = <String, V2ErrorCode>{
    // Profile / identity
    'PROFILE_NOT_FOUND': V2ErrorCode.profileNotFound,
    'INVALID_INSTALLATION_ID': V2ErrorCode.invalidInstallationId,
    'DISPLAY_NAME_INVALID': V2ErrorCode.displayNameInvalid,
    'DISPLAY_NAME_REJECTED': V2ErrorCode.displayNameRejected,
    'PROFILE_BLOCKED': V2ErrorCode.profileBlocked,
    // Versioning
    'UNSUPPORTED_API_VERSION': V2ErrorCode.unsupportedApiVersion,
    'VERSION_MISMATCH': V2ErrorCode.unsupportedApiVersion,
    // Auth / session
    'AUTHENTICATION_REQUIRED': V2ErrorCode.authenticationRequired,
    'AUTH_TOKEN_INVALID': V2ErrorCode.authTokenInvalid,
    'AUTH_TOKEN_EXPIRED': V2ErrorCode.authTokenExpired,
    'AUTH_PROVIDER_UNSUPPORTED': V2ErrorCode.authProviderUnsupported,
    'AUTH_PROVIDER_NOT_CONFIGURED': V2ErrorCode.authProviderNotConfigured,
    'SESSION_INVALID': V2ErrorCode.sessionInvalid,
    'SESSION_EXPIRED': V2ErrorCode.sessionExpired,
    'SESSION_REVOKED': V2ErrorCode.sessionRevoked,
    'REAUTHENTICATION_REQUIRED': V2ErrorCode.reauthenticationRequired,
    'AUTH_PROVIDER_DISABLED': V2ErrorCode.authProviderDisabled,
    'INVALID_INSTALLATION_TOKEN': V2ErrorCode.invalidInstallationToken,
    'ACCOUNT_NOT_FOUND': V2ErrorCode.accountNotFound,
    'ACCOUNT_DISABLED': V2ErrorCode.accountDisabled,
    'ACCOUNT_SUSPENDED': V2ErrorCode.accountSuspended,
    'ACCOUNT_BANNED': V2ErrorCode.accountBanned,
    'ACCOUNT_VERIFICATION_REQUIRED': V2ErrorCode.accountVerificationRequired,
    'ACCOUNT_DELETION_PENDING': V2ErrorCode.accountDeletionPending,
    'ACCOUNT_DELETED': V2ErrorCode.accountDeleted,
    'UNAUTHORIZED': V2ErrorCode.unauthorized,
    // Weekly
    'WEEKLY_NOT_ACTIVE': V2ErrorCode.weeklyUnavailable,
    'WEEKLY_UNAVAILABLE': V2ErrorCode.weeklyUnavailable,
    'WEEKLY_RUN_EXPIRED': V2ErrorCode.weeklyExpired,
    'WEEKLY_CLOSED': V2ErrorCode.weeklyExpired,
    'WEEKLY_RUN_NOT_FOUND': V2ErrorCode.weeklyExpired,
    'WEEKLY_ALREADY_COMPLETED': V2ErrorCode.weeklyCompleted,
    // Language lock
    'GAME_LANGUAGE_LOCKED': V2ErrorCode.gameLanguageLocked,
    // Rooms
    'ROOM_NOT_FOUND': V2ErrorCode.roomInvalid,
    'ROOM_CODE_INVALID': V2ErrorCode.roomInvalid,
    'ROOM_FULL': V2ErrorCode.roomFull,
    'ROOM_ALREADY_STARTED': V2ErrorCode.roomStarted,
    'ROOM_NOT_ACTIVE': V2ErrorCode.roomNotActive,
    'ROOM_SOLVED': V2ErrorCode.roomSolved,
    'ROOM_EXPIRED': V2ErrorCode.roomExpired,
    'ROOM_GUESS_DUPLICATE': V2ErrorCode.duplicateRoomGuess,
    'ROOM_FORBIDDEN': V2ErrorCode.roomForbidden,
    // Hints
    'HINT_LIMIT_REACHED': V2ErrorCode.hintLimit,
    'ADAPTIVE_HINT_UNAVAILABLE': V2ErrorCode.adaptiveHintUnavailable,
    // Wallet
    'INSUFFICIENT_COINS': V2ErrorCode.insufficientCoins,
    'WALLET_NOT_FOUND': V2ErrorCode.walletNotFound,
    'WALLET_BLOCKED': V2ErrorCode.walletBlocked,
    // Tiers / matchmaking
    'TIER_NOT_FOUND': V2ErrorCode.tierNotFound,
    'TIER_DISABLED': V2ErrorCode.tierDisabled,
    'MATCHMAKING_ALREADY_ACTIVE': V2ErrorCode.matchmakingAlreadyActive,
    'MATCHMAKING_TICKET_NOT_FOUND': V2ErrorCode.matchmakingTicketNotFound,
    'MATCHMAKING_CANCELLED': V2ErrorCode.matchmakingCancelled,
    // Ranked match
    'MATCH_ALREADY_ACTIVE': V2ErrorCode.matchAlreadyActive,
    'MATCH_NOT_FOUND': V2ErrorCode.matchNotFound,
    'MATCH_NOT_ACTIVE': V2ErrorCode.matchNotActive,
    'MATCH_ALREADY_FINISHED': V2ErrorCode.matchAlreadyFinished,
    'MATCH_FORBIDDEN': V2ErrorCode.matchForbidden,
    'NOT_YOUR_TURN': V2ErrorCode.notYourTurn,
    'TURN_EXPIRED': V2ErrorCode.turnExpired,
    'GUESS_DUPLICATE': V2ErrorCode.guessDuplicate,
    'PLAYER_DISCONNECTED': V2ErrorCode.playerDisconnected,
    'RECONNECT_WINDOW_EXPIRED': V2ErrorCode.reconnectWindowExpired,
    'MATCH_FORFEITED': V2ErrorCode.matchForfeited,
    'MATCH_CANCELLED': V2ErrorCode.matchCancelled,
    'SETTLEMENT_PENDING': V2ErrorCode.settlementPending,
    'SETTLEMENT_FAILED': V2ErrorCode.settlementFailed,
    // Social directory
    'PLAYER_NOT_FOUND': V2ErrorCode.playerNotFound,
    'PLAYER_NOT_AVAILABLE': V2ErrorCode.playerNotAvailable,
    'PLAYER_INVITES_DISABLED': V2ErrorCode.playerInvitesDisabled,
    'PLAYER_BLOCKED': V2ErrorCode.playerBlocked,
    'CANNOT_INVITE_SELF': V2ErrorCode.cannotInviteSelf,
    // Invitations
    'INVITATION_ALREADY_PENDING': V2ErrorCode.invitationAlreadyPending,
    'INVITATION_NOT_FOUND': V2ErrorCode.invitationNotFound,
    'INVITATION_EXPIRED': V2ErrorCode.invitationExpired,
    'INVITATION_ALREADY_RESOLVED': V2ErrorCode.invitationAlreadyResolved,
    // Open rooms / join-requests
    'ROOM_NOT_OPEN': V2ErrorCode.roomNotOpen,
    'ROOM_NOT_ACCEPTING_REQUESTS': V2ErrorCode.roomNotAcceptingRequests,
    'JOIN_REQUEST_ALREADY_PENDING': V2ErrorCode.joinRequestAlreadyPending,
    'JOIN_REQUEST_NOT_FOUND': V2ErrorCode.joinRequestNotFound,
    'JOIN_REQUEST_EXPIRED': V2ErrorCode.joinRequestExpired,
    'JOIN_REQUEST_ALREADY_RESOLVED': V2ErrorCode.joinRequestAlreadyResolved,
    'NOT_ROOM_HOST': V2ErrorCode.notRoomHost,
    'ALREADY_ROOM_PARTICIPANT': V2ErrorCode.alreadyRoomParticipant,
    'ACTIVE_ROOM_EXISTS': V2ErrorCode.activeRoomExists,
    // Presence / concurrency
    'PRESENCE_UNAVAILABLE': V2ErrorCode.presenceUnavailable,
    'STATE_VERSION_CONFLICT': V2ErrorCode.stateVersionConflict,
    // Generic
    'VALIDATION_ERROR': V2ErrorCode.validationError,
    'NOT_IN_VOCABULARY': V2ErrorCode.notInVocabulary,
    'RATE_LIMITED': V2ErrorCode.rateLimited,
    'BACKEND_UNAVAILABLE': V2ErrorCode.backendUnavailable,
    'INTERNAL_ERROR': V2ErrorCode.internalError,
  };

  static V2ErrorCode fromCode(String? code) =>
      code == null ? V2ErrorCode.unknown : (_map[code] ?? V2ErrorCode.unknown);
}
