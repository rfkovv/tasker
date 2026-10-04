import 'dart:async';

/// Fake one-shot timers driven manually — no real-time sleeps.
///
/// Time is cumulative: [elapse] advances a fake clock; timers fire when
/// their arm-time + duration is reached.
class FakeTimers {
  Duration _now = Duration.zero;
  final pending = <_FakeTimer>[];

  Duration get now => _now;

  Timer call(Duration duration, void Function() callback) {
    final timer = _FakeTimer(
      this,
      duration,
      callback,
      fireAt: _now + duration,
    );
    pending.add(timer);
    return timer;
  }

  /// Advances the fake clock and fires every timer whose [fireAt] ≤ now.
  void elapse(Duration duration) {
    _now += duration;
    final due =
        pending.where((t) => t.isActive && t.fireAt <= _now).toList();
    for (final timer in due) {
      timer._fire();
    }
  }

  /// Fires all currently pending timers (ignore remaining duration).
  void fireAll() {
    final due = List<_FakeTimer>.of(pending);
    for (final timer in due) {
      if (!timer.isActive) continue;
      timer._fire();
    }
  }

  int get activeCount => pending.where((t) => t.isActive).length;

  /// Durations of currently active timers (for backoff assertions).
  List<Duration> get activeDurations => [
        for (final t in pending)
          if (t.isActive) t.duration,
      ];
}

class _FakeTimer implements Timer {
  _FakeTimer(
    this._owner,
    this.duration,
    this._callback, {
    required this.fireAt,
  });

  final FakeTimers _owner;
  final Duration duration;
  final Duration fireAt;
  final void Function() _callback;
  var _active = true;

  @override
  bool get isActive => _active;

  @override
  int get tick => _active ? 0 : -1;

  @override
  void cancel() {
    _active = false;
    _owner.pending.remove(this);
  }

  void _fire() {
    if (!_active) return;
    _active = false;
    _owner.pending.remove(this);
    _callback();
  }
}
