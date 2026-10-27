import 'dart:async';

import 'package:flutter/foundation.dart';

/// Sleep timer state machine, independent of the audio engine so it can be
/// tested with a fake clock.
///
/// * [start] counts down; the last [fadeDuration] reports a shrinking volume
///   factor through [onFade]; at zero [onExpire] fires.
/// * With `endOfTrack: true` reaching zero does not stop playback: the timer
///   waits ([waitingForTrackEnd]) and fades out over the end of the current
///   song instead, then [onExpire] fires from [trackEnded].
class SleepTimer {
  SleepTimer({
    required this.onFade,
    required this.onExpire,
    DateTime Function()? now,
    this.fadeDuration = const Duration(seconds: 8),
    this.tickInterval = const Duration(milliseconds: 250),
    this.autoTick = true,
  }) : _now = now ?? DateTime.now;

  /// Volume factor 0 - 1 (1 = untouched).
  final void Function(double factor) onFade;
  final VoidCallback onExpire;
  final Duration fadeDuration;
  final Duration tickInterval;

  /// `false` in tests: the owner calls [tick] itself.
  final bool autoTick;
  final DateTime Function() _now;

  /// Remaining time, `null` when off. `Duration.zero` while waiting for the
  /// end of the track.
  final ValueNotifier<Duration?> remaining = ValueNotifier(null);

  DateTime? _deadline;
  bool _endOfTrack = false;
  bool _waiting = false;
  double _factor = 1;
  Timer? _timer;

  bool get active => remaining.value != null;
  bool get endOfTrack => _endOfTrack;
  bool get waitingForTrackEnd => _waiting;

  /// Supplies the remaining time of the current track while waiting for its
  /// end, so the fade can track the song instead of the clock.
  Duration? Function()? trackRemaining;

  /// Starts (or with `null` cancels) the timer. A zero [duration] with
  /// [endOfTrack] means "stop after the current song".
  void start(Duration? duration, {bool endOfTrack = false}) {
    cancel();
    if (duration == null) return;
    _endOfTrack = endOfTrack;
    _deadline = _now().add(duration);
    if (duration <= Duration.zero) {
      if (!endOfTrack) {
        _expire();
        return;
      }
      _waiting = true;
    }
    remaining.value = duration <= Duration.zero ? Duration.zero : duration;
    if (autoTick) _timer = Timer.periodic(tickInterval, (_) => tick());
  }

  void cancel() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _waiting = false;
    _endOfTrack = false;
    remaining.value = null;
    _setFactor(1);
  }

  /// Advances the state machine; called periodically.
  @visibleForTesting
  void tick() {
    final deadline = _deadline;
    if (deadline == null) return;
    if (_waiting) {
      final left = trackRemaining?.call();
      if (left != null) _setFactor(fadeFactor(left, fadeDuration));
      return;
    }
    var left = deadline.difference(_now());
    if (left < Duration.zero) left = Duration.zero;
    remaining.value = left;
    if (!_endOfTrack) _setFactor(fadeFactor(left, fadeDuration));
    if (left == Duration.zero) {
      if (_endOfTrack) {
        _waiting = true;
        tick();
      } else {
        _expire();
      }
    }
  }

  /// The player finished a track on its own (not skipped).
  void trackEnded() {
    if (_waiting) _expire();
  }

  void _expire() {
    _timer?.cancel();
    _timer = null;
    _deadline = null;
    _waiting = false;
    _endOfTrack = false;
    remaining.value = null;
    onExpire();
    // The owner restores the volume after pausing; reset the cached factor
    // without reporting it again.
    _factor = 1;
  }

  void _setFactor(double factor) {
    if ((factor - _factor).abs() < 0.001) return;
    _factor = factor;
    onFade(factor);
  }

  void dispose() {
    _timer?.cancel();
    remaining.dispose();
  }
}

/// Linear fade: 1 while more than [fade] is left, 0 at the end.
double fadeFactor(Duration left, Duration fade) {
  if (fade <= Duration.zero) return left > Duration.zero ? 1 : 0;
  if (left >= fade) return 1;
  if (left <= Duration.zero) return 0;
  return left.inMilliseconds / fade.inMilliseconds;
}
