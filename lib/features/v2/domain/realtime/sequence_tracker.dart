/// Verdict for an incoming realtime event.
enum EventVerdict {
  /// Fresh, in-order event — apply it.
  ok,

  /// Already-seen event id — ignore.
  duplicate,

  /// seq jumped ahead of lastSeq+1 — a gap: recover via REST snapshot.
  gap,

  /// seq is older than what we've already applied — stale, ignore.
  stale,
}

/// Pure event-ordering guard: deduplicates by event id and detects sequence
/// gaps against a monotonic `seq`. No I/O — trivially unit-testable.
class SequenceTracker {
  final Set<String> _seenIds = <String>{};
  int? _lastSeq;

  int? get lastSeq => _lastSeq;

  /// Seed the tracker from a persisted/snapshot sequence (process restart).
  void seed(int seq) => _lastSeq = seq;

  EventVerdict offer({required String id, required int seq}) {
    if (_seenIds.contains(id)) return EventVerdict.duplicate;

    final last = _lastSeq;
    if (last == null) {
      _seenIds.add(id);
      _lastSeq = seq;
      return EventVerdict.ok;
    }
    if (seq <= last) {
      // Older-or-equal seq with a new id → stale replay; remember the id.
      _seenIds.add(id);
      return EventVerdict.stale;
    }
    if (seq > last + 1) {
      // Gap. Do NOT advance lastSeq; caller must reconcile via snapshot.
      return EventVerdict.gap;
    }
    _seenIds.add(id);
    _lastSeq = seq;
    return EventVerdict.ok;
  }

  /// After a snapshot reconciles state up to [seq], accept it as the new
  /// baseline and remember [id] as consumed.
  void reconcile({required String id, required int seq}) {
    _seenIds.add(id);
    if (_lastSeq == null || seq > _lastSeq!) _lastSeq = seq;
  }
}
