/// Pure exponential-backoff policy for WebSocket reconnection.
/// Delays: base * 2^attempt, capped at [max]. Attempt is 0-based.
class ReconnectPolicy {
  const ReconnectPolicy({
    this.base = const Duration(seconds: 1),
    this.max = const Duration(seconds: 30),
    this.maxAttempts = 8,
  });

  final Duration base;
  final Duration max;
  final int maxAttempts;

  /// Delay before the given (0-based) reconnect attempt.
  Duration delayFor(int attempt) {
    if (attempt < 0) attempt = 0;
    final ms = base.inMilliseconds * (1 << attempt.clamp(0, 20));
    final capped = ms > max.inMilliseconds ? max.inMilliseconds : ms;
    return Duration(milliseconds: capped);
  }

  bool shouldRetry(int attempt) => attempt < maxAttempts;
}
