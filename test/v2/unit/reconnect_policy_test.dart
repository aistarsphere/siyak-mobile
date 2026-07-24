import 'package:context_game/features/v2/domain/realtime/reconnect_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ReconnectPolicy — exponential backoff', () {
    const p = ReconnectPolicy(
      base: Duration(seconds: 1),
      max: Duration(seconds: 30),
      maxAttempts: 8,
    );

    test('doubles each attempt', () {
      expect(p.delayFor(0), const Duration(seconds: 1));
      expect(p.delayFor(1), const Duration(seconds: 2));
      expect(p.delayFor(2), const Duration(seconds: 4));
      expect(p.delayFor(3), const Duration(seconds: 8));
    });

    test('caps at max', () {
      expect(p.delayFor(10), const Duration(seconds: 30));
    });

    test('clamps negative attempts', () {
      expect(p.delayFor(-5), const Duration(seconds: 1));
    });

    test('stops retrying after maxAttempts', () {
      expect(p.shouldRetry(7), isTrue);
      expect(p.shouldRetry(8), isFalse);
    });
  });
}
