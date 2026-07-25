import 'package:context_game/features/v2/data/remote/v2_error_mapper.dart';
import 'package:context_game/features/v2/domain/errors/v2_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V2ErrorMapper — real backend codes', () {
    test('maps documented codes to enum (frozen contract 2026-07.1)', () {
      expect(
        V2ErrorMapper.fromCode('ROOM_CODE_INVALID'),
        V2ErrorCode.roomInvalid,
      );
      expect(V2ErrorMapper.fromCode('ROOM_NOT_FOUND'), V2ErrorCode.roomInvalid);
      expect(V2ErrorMapper.fromCode('ROOM_FULL'), V2ErrorCode.roomFull);
      expect(
        V2ErrorMapper.fromCode('ROOM_ALREADY_STARTED'),
        V2ErrorCode.roomStarted,
      );
      expect(V2ErrorMapper.fromCode('ROOM_EXPIRED'), V2ErrorCode.roomExpired);
      expect(
        V2ErrorMapper.fromCode('WEEKLY_RUN_EXPIRED'),
        V2ErrorCode.weeklyExpired,
      );
      expect(
        V2ErrorMapper.fromCode('WEEKLY_ALREADY_COMPLETED'),
        V2ErrorCode.weeklyCompleted,
      );
      expect(
        V2ErrorMapper.fromCode('WEEKLY_RUN_NOT_FOUND'),
        V2ErrorCode.weeklyExpired,
      );
      expect(
        V2ErrorMapper.fromCode('PROFILE_BLOCKED'),
        V2ErrorCode.profileBlocked,
      );
      expect(V2ErrorMapper.fromCode('RATE_LIMITED'), V2ErrorCode.rateLimited);
      expect(
        V2ErrorMapper.fromCode('HINT_LIMIT_REACHED'),
        V2ErrorCode.hintLimit,
      );
      // Account-based V2 codes
      expect(
        V2ErrorMapper.fromCode('AUTHENTICATION_REQUIRED'),
        V2ErrorCode.authenticationRequired,
      );
      expect(
        V2ErrorMapper.fromCode('INSUFFICIENT_COINS'),
        V2ErrorCode.insufficientCoins,
      );
      expect(V2ErrorMapper.fromCode('NOT_YOUR_TURN'), V2ErrorCode.notYourTurn);
      expect(
        V2ErrorMapper.fromCode('STATE_VERSION_CONFLICT'),
        V2ErrorCode.stateVersionConflict,
      );
      expect(
        V2ErrorMapper.fromCode('GAME_LANGUAGE_LOCKED'),
        V2ErrorCode.gameLanguageLocked,
      );
    });

    test('retry policy follows the contract legend', () {
      expect(
        const V2Exception(V2ErrorCode.stateVersionConflict).retry,
        V2Retry.resync,
      );
      expect(const V2Exception(V2ErrorCode.rateLimited).retry, V2Retry.backoff);
      expect(const V2Exception(V2ErrorCode.notYourTurn).retry, V2Retry.none);
      expect(
        const V2Exception(V2ErrorCode.sessionExpired).isAuthFailure,
        isTrue,
      );
    });

    test('unknown codes fall back to unknown', () {
      expect(V2ErrorMapper.fromCode('SOMETHING_NEW'), V2ErrorCode.unknown);
      expect(V2ErrorMapper.fromCode(null), V2ErrorCode.unknown);
    });

    test('connectivity codes flagged isConnectivity', () {
      expect(
        const V2Exception(V2ErrorCode.serverOffline).isConnectivity,
        isTrue,
      );
      expect(
        const V2Exception(V2ErrorCode.tunnelOffline).isConnectivity,
        isTrue,
      );
      expect(const V2Exception(V2ErrorCode.roomFull).isConnectivity, isFalse);
    });
  });
}
