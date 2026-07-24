import 'package:context_game/features/v2/domain/realtime/sequence_tracker.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('SequenceTracker — dedup + gap detection', () {
    test('accepts fresh in-order events', () {
      final t = SequenceTracker();
      expect(t.offer(id: 'a', seq: 1), EventVerdict.ok);
      expect(t.offer(id: 'b', seq: 2), EventVerdict.ok);
      expect(t.lastSeq, 2);
    });

    test('deduplicates a repeated event id', () {
      final t = SequenceTracker();
      t.offer(id: 'a', seq: 1);
      expect(t.offer(id: 'a', seq: 1), EventVerdict.duplicate);
      expect(t.offer(id: 'a', seq: 99), EventVerdict.duplicate);
    });

    test('detects a sequence gap and does NOT advance lastSeq', () {
      final t = SequenceTracker();
      t.offer(id: 'a', seq: 1);
      t.offer(id: 'b', seq: 2);
      expect(t.offer(id: 'd', seq: 4), EventVerdict.gap); // missing seq 3
      expect(t.lastSeq, 2, reason: 'gap must not advance baseline');
    });

    test('marks stale older-seq events', () {
      final t = SequenceTracker();
      t.offer(id: 'a', seq: 5);
      expect(t.offer(id: 'old', seq: 3), EventVerdict.stale);
    });

    test('reconcile accepts a snapshot baseline', () {
      final t = SequenceTracker();
      t.offer(id: 'a', seq: 1);
      t.offer(id: 'b', seq: 2);
      t.offer(id: 'd', seq: 4); // gap
      t.reconcile(id: 'd', seq: 4);
      expect(t.lastSeq, 4);
      // After reconcile the previously-gapped event is a duplicate.
      expect(t.offer(id: 'd', seq: 4), EventVerdict.duplicate);
      expect(t.offer(id: 'e', seq: 5), EventVerdict.ok);
    });

    test('seed sets the baseline (process restart)', () {
      final t = SequenceTracker()..seed(10);
      expect(t.offer(id: 'x', seq: 11), EventVerdict.ok);
      expect(t.offer(id: 'y', seq: 13), EventVerdict.gap);
    });
  });
}
