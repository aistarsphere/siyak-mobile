import 'package:context_game/features/v2/data/remote/v2_error_mapper.dart';
import 'package:context_game/features/v2/domain/errors/v2_error.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('V2ErrorMapper — real backend codes', () {
    test('maps documented codes to enum', () {
      expect(V2ErrorMapper.fromCode('ROOM_CODE_INVALID'), V2ErrorCode.roomInvalid);
      expect(V2ErrorMapper.fromCode('ROOM_NOT_FOUND'), V2ErrorCode.roomInvalid);
      expect(V2ErrorMapper.fromCode('ROOM_FULL'), V2ErrorCode.roomFull);
      expect(V2ErrorMapper.fromCode('ROOM_STARTED'), V2ErrorCode.roomStarted);
      expect(V2ErrorMapper.fromCode('ROOM_EXPIRED'), V2ErrorCode.roomExpired);
      expect(V2ErrorMapper.fromCode('WEEKLY_EXPIRED'), V2ErrorCode.weeklyExpired);
      expect(V2ErrorMapper.fromCode('WEEKLY_COMPLETED'), V2ErrorCode.weeklyCompleted);
      expect(V2ErrorMapper.fromCode('WEEKLY_RUN_NOT_FOUND'), V2ErrorCode.weeklyExpired);
      expect(V2ErrorMapper.fromCode('PROFILE_BLOCKED'), V2ErrorCode.profileBlocked);
      expect(V2ErrorMapper.fromCode('RATE_LIMITED'), V2ErrorCode.rateLimited);
      expect(V2ErrorMapper.fromCode('HINT_LIMIT'), V2ErrorCode.hintLimit);
    });

    test('unknown codes fall back to unknown', () {
      expect(V2ErrorMapper.fromCode('SOMETHING_NEW'), V2ErrorCode.unknown);
      expect(V2ErrorMapper.fromCode(null), V2ErrorCode.unknown);
    });

    test('connectivity codes flagged isConnectivity', () {
      expect(const V2Exception(V2ErrorCode.serverOffline).isConnectivity, isTrue);
      expect(const V2Exception(V2ErrorCode.tunnelOffline).isConnectivity, isTrue);
      expect(const V2Exception(V2ErrorCode.roomFull).isConnectivity, isFalse);
    });
  });
}
