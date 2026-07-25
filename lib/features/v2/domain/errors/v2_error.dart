/// Stable V2 error conditions from the frozen contract (`12-error-codes.md`).
///
/// Controllers/UI switch on this enum; the data layer maps the backend
/// `error.code` strings here (see `data/remote/v2_error_mapper.dart`). The
/// original string is preserved on [V2Exception.rawCode] for logging.
enum V2ErrorCode {
  // Connectivity / transport (client-derived)
  serverOffline,
  tunnelOffline,
  socketReconnecting,
  // Versioning
  unsupportedApiVersion,
  // Profile / identity
  profileNotFound,
  invalidInstallationId,
  displayNameInvalid,
  displayNameRejected,
  profileBlocked,
  // Auth / session
  authenticationRequired,
  authTokenInvalid,
  authTokenExpired,
  authProviderUnsupported,
  authProviderNotConfigured,
  sessionInvalid,
  sessionExpired,
  accountNotFound,
  accountDisabled,
  // Weekly
  weeklyUnavailable,
  weeklyExpired,
  weeklyCompleted,
  // Language lock
  gameLanguageLocked,
  // Rooms (code + social lifecycle)
  roomInvalid,
  roomFull,
  roomStarted,
  roomSolved,
  roomExpired,
  roomNotActive,
  roomForbidden,
  duplicateRoomGuess,
  // Hints
  hintLimit,
  adaptiveHintUnavailable,
  // Wallet / coins
  insufficientCoins,
  walletNotFound,
  walletBlocked,
  // Ranked tiers / matchmaking
  tierNotFound,
  tierDisabled,
  matchmakingAlreadyActive,
  matchmakingTicketNotFound,
  matchmakingCancelled,
  // Ranked match
  matchAlreadyActive,
  matchNotFound,
  matchNotActive,
  matchAlreadyFinished,
  matchForbidden,
  notYourTurn,
  turnExpired,
  guessDuplicate,
  playerDisconnected,
  reconnectWindowExpired,
  matchForfeited,
  matchCancelled,
  settlementPending,
  settlementFailed,
  // Social directory / players
  playerNotFound,
  playerNotAvailable,
  playerInvitesDisabled,
  playerBlocked,
  cannotInviteSelf,
  // Invitations
  invitationAlreadyPending,
  invitationNotFound,
  invitationExpired,
  invitationAlreadyResolved,
  // Open rooms / join-requests
  roomNotOpen,
  roomNotAcceptingRequests,
  joinRequestAlreadyPending,
  joinRequestNotFound,
  joinRequestExpired,
  joinRequestAlreadyResolved,
  notRoomHost,
  alreadyRoomParticipant,
  activeRoomExists,
  // Presence / concurrency
  presenceUnavailable,
  stateVersionConflict,
  // Generic
  validationError,
  notInVocabulary,
  rateLimited,
  unauthorized,
  backendUnavailable,
  internalError,
  unknown,
}

/// Recommended retry behavior from the contract's retry legend.
enum V2Retry {
  /// Do not auto-retry — fix inputs / state.
  none,

  /// Transient — retry with exponential backoff.
  backoff,

  /// Re-fetch the authoritative snapshot, then retry.
  resync,
}

class V2Exception implements Exception {
  const V2Exception(this.code, {this.detail, this.rawCode});

  final V2ErrorCode code;

  /// Human/context detail (backend `error.message`), may change.
  final String? detail;

  /// The original backend `error.code` string, for logging/telemetry.
  final String? rawCode;

  /// True for "can't reach the backend" style failures.
  bool get isConnectivity =>
      code == V2ErrorCode.serverOffline ||
      code == V2ErrorCode.tunnelOffline ||
      code == V2ErrorCode.socketReconnecting ||
      code == V2ErrorCode.backendUnavailable;

  /// True when the session must be re-established (clear token, prompt sign-in).
  bool get isAuthFailure =>
      code == V2ErrorCode.authenticationRequired ||
      code == V2ErrorCode.authTokenInvalid ||
      code == V2ErrorCode.authTokenExpired ||
      code == V2ErrorCode.sessionInvalid ||
      code == V2ErrorCode.sessionExpired ||
      code == V2ErrorCode.unauthorized ||
      code == V2ErrorCode.accountNotFound;

  /// Contract-recommended retry policy.
  V2Retry get retry => switch (code) {
    V2ErrorCode.serverOffline ||
    V2ErrorCode.tunnelOffline ||
    V2ErrorCode.socketReconnecting ||
    V2ErrorCode.backendUnavailable ||
    V2ErrorCode.authProviderNotConfigured ||
    V2ErrorCode.presenceUnavailable ||
    V2ErrorCode.playerDisconnected ||
    V2ErrorCode.settlementPending ||
    V2ErrorCode.settlementFailed ||
    V2ErrorCode.rateLimited ||
    V2ErrorCode.internalError =>
      V2Retry.backoff,
    V2ErrorCode.stateVersionConflict => V2Retry.resync,
    _ => V2Retry.none,
  };

  /// Localization key for a friendly message (see strings_*.dart). Codes without
  /// a dedicated string fall back to a generic message.
  String get messageKey => switch (code) {
    V2ErrorCode.serverOffline => 'errNetwork',
    V2ErrorCode.tunnelOffline || V2ErrorCode.backendUnavailable =>
      'offlineTitle',
    V2ErrorCode.socketReconnecting => 'v2Reconnecting',
    V2ErrorCode.unsupportedApiVersion => 'v2ErrUnsupported',
    V2ErrorCode.profileBlocked => 'v2ErrProfileBlocked',
    V2ErrorCode.displayNameInvalid || V2ErrorCode.displayNameRejected =>
      'v2ErrDisplayName',
    V2ErrorCode.authenticationRequired ||
    V2ErrorCode.authTokenInvalid ||
    V2ErrorCode.authTokenExpired ||
    V2ErrorCode.sessionInvalid ||
    V2ErrorCode.sessionExpired ||
    V2ErrorCode.unauthorized =>
      'v2ErrSignInRequired',
    V2ErrorCode.accountDisabled => 'v2ErrAccountDisabled',
    V2ErrorCode.weeklyUnavailable => 'v2ErrWeeklyUnavailable',
    V2ErrorCode.weeklyExpired => 'v2ErrWeeklyExpired',
    V2ErrorCode.weeklyCompleted => 'v2ErrWeeklyCompleted',
    V2ErrorCode.gameLanguageLocked => 'v2ErrLanguageLocked',
    V2ErrorCode.roomInvalid => 'v2ErrRoomInvalid',
    V2ErrorCode.roomFull => 'v2ErrRoomFull',
    V2ErrorCode.roomStarted => 'v2ErrRoomStarted',
    V2ErrorCode.roomSolved => 'v2ErrRoomSolved',
    V2ErrorCode.roomExpired => 'v2ErrRoomExpired',
    V2ErrorCode.roomNotActive => 'v2ErrRoomNotActive',
    V2ErrorCode.duplicateRoomGuess || V2ErrorCode.guessDuplicate =>
      'v2ErrDuplicateRoomGuess',
    V2ErrorCode.hintLimit => 'noMoreHints',
    V2ErrorCode.adaptiveHintUnavailable => 'v2ErrAdaptiveUnavailable',
    V2ErrorCode.insufficientCoins => 'v2ErrInsufficientCoins',
    V2ErrorCode.walletBlocked => 'v2ErrWalletBlocked',
    V2ErrorCode.tierDisabled || V2ErrorCode.tierNotFound => 'v2ErrTier',
    V2ErrorCode.matchmakingAlreadyActive => 'v2ErrMatchmakingActive',
    V2ErrorCode.matchAlreadyActive => 'v2ErrMatchActive',
    V2ErrorCode.notYourTurn => 'v2ErrNotYourTurn',
    V2ErrorCode.turnExpired => 'v2ErrTurnExpired',
    V2ErrorCode.playerDisconnected => 'v2ErrOpponentDropped',
    V2ErrorCode.matchForfeited => 'v2ErrForfeit',
    V2ErrorCode.matchCancelled => 'v2ErrMatchCancelled',
    V2ErrorCode.playerNotAvailable => 'v2ErrPlayerUnavailable',
    V2ErrorCode.playerInvitesDisabled => 'v2ErrInvitesDisabled',
    V2ErrorCode.cannotInviteSelf => 'v2ErrInviteSelf',
    V2ErrorCode.invitationExpired => 'v2ErrInvitationExpired',
    V2ErrorCode.roomNotAcceptingRequests || V2ErrorCode.roomNotOpen =>
      'v2ErrRequestsClosed',
    V2ErrorCode.notRoomHost => 'v2ErrNotHost',
    V2ErrorCode.activeRoomExists => 'v2ErrActiveRoomExists',
    V2ErrorCode.stateVersionConflict => 'v2ErrStateConflict',
    V2ErrorCode.rateLimited => 'v2ErrRateLimited',
    V2ErrorCode.notInVocabulary => 'v2ErrNotInVocabulary',
    _ => 'errUnknown',
  };

  @override
  String toString() => 'V2Exception($code, raw=$rawCode, $detail)';
}
