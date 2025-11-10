class RateLimiter {
  final Map<String, DateTime> _lastAttempts = {};
  final Map<String, int> _attemptCounts = {};
  final Duration _windowDuration;
  final int _maxAttempts;

  RateLimiter({
    Duration? windowDuration,
    int? maxAttempts,
  })  : _windowDuration = windowDuration ?? const Duration(minutes: 1),
        _maxAttempts = maxAttempts ?? 5;

  bool isAllowed(String key) {
    final now = DateTime.now();
    final lastAttempt = _lastAttempts[key];

    if (lastAttempt == null || now.difference(lastAttempt) > _windowDuration) {
      _lastAttempts[key] = now;
      _attemptCounts[key] = 1;
      return true;
    }

    final attemptCount = _attemptCounts[key] ?? 0;

    if (attemptCount >= _maxAttempts) {
      return false;
    }

    _attemptCounts[key] = attemptCount + 1;
    _lastAttempts[key] = now;
    return true;
  }

  void reset(String key) {
    _lastAttempts.remove(key);
    _attemptCounts.remove(key);
  }

  Duration? getTimeUntilReset(String key) {
    final lastAttempt = _lastAttempts[key];
    if (lastAttempt == null) return null;

    final timeSinceLastAttempt = DateTime.now().difference(lastAttempt);
    final timeRemaining = _windowDuration - timeSinceLastAttempt;

    return timeRemaining.isNegative ? null : timeRemaining;
  }
}
