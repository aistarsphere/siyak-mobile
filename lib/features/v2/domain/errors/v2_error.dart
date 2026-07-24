/// Documented V2 error conditions, mapped to friendly localized UI. The exact
/// backend code strings are reconciled in the data layer when the contract is
/// available (see `data/remote/`); controllers/UI only see this enum.
enum V2ErrorCode {
  serverOffline,
  tunnelOffline,
  unsupportedApiVersion,
  profileBlocked,
  weeklyUnavailable,
  weeklyExpired,
  weeklyCompleted,
  roomInvalid,
  roomFull,
  roomStarted,
  roomSolved,
  roomExpired,
  duplicateRoomGuess,
  hintLimit,
  adaptiveHintUnavailable,
  rateLimited,
  socketReconnecting,
  unknown,
}

class V2Exception implements Exception {
  const V2Exception(this.code, {this.detail});

  final V2ErrorCode code;
  final String? detail;

  /// True for "can't reach the backend" style failures.
  bool get isConnectivity =>
      code == V2ErrorCode.serverOffline ||
      code == V2ErrorCode.tunnelOffline ||
      code == V2ErrorCode.socketReconnecting;

  /// Localization key for a friendly message (see strings_*.dart).
  String get messageKey => switch (code) {
    V2ErrorCode.serverOffline => 'errNetwork',
    V2ErrorCode.tunnelOffline => 'offlineTitle',
    V2ErrorCode.unsupportedApiVersion => 'v2ErrUnsupported',
    V2ErrorCode.profileBlocked => 'v2ErrProfileBlocked',
    V2ErrorCode.weeklyUnavailable => 'v2ErrWeeklyUnavailable',
    V2ErrorCode.weeklyExpired => 'v2ErrWeeklyExpired',
    V2ErrorCode.weeklyCompleted => 'v2ErrWeeklyCompleted',
    V2ErrorCode.roomInvalid => 'v2ErrRoomInvalid',
    V2ErrorCode.roomFull => 'v2ErrRoomFull',
    V2ErrorCode.roomStarted => 'v2ErrRoomStarted',
    V2ErrorCode.roomSolved => 'v2ErrRoomSolved',
    V2ErrorCode.roomExpired => 'v2ErrRoomExpired',
    V2ErrorCode.duplicateRoomGuess => 'v2ErrDuplicateRoomGuess',
    V2ErrorCode.hintLimit => 'noMoreHints',
    V2ErrorCode.adaptiveHintUnavailable => 'v2ErrAdaptiveUnavailable',
    V2ErrorCode.rateLimited => 'v2ErrRateLimited',
    V2ErrorCode.socketReconnecting => 'v2Reconnecting',
    V2ErrorCode.unknown => 'errUnknown',
  };

  @override
  String toString() => 'V2Exception($code, $detail)';
}
