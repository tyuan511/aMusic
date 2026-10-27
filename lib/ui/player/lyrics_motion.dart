import 'dart:math' as math;

import 'package:flutter/physics.dart';

/// Motion maths of the lyric viewport, kept free of widgets so it can be
/// unit tested.
class LyricMotion {
  LyricMotion._();

  /// Mass 1, stiffness 170, damping ratio 0.85: settles in ~0.5 s with a
  /// barely visible overshoot.
  static final SpringDescription spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 170,
    ratio: 0.85,
  );

  /// Delay per line of distance below the focus line.
  static const Duration staggerStep = Duration(milliseconds: 40);

  /// Lines further than this below the focus share the last delay.
  static const int maxStaggerLines = 8;

  /// Strongest distance blur (logical sigma).
  static const double maxBlurSigma = 4;

  /// Blur levels: sigma is quantised so lines share one filter layer each.
  static const int blurLevels = 4;

  /// Lines above the focus move at once; lines below follow one step later
  /// per line, which reads as the text "flowing" up.
  static Duration staggerDelay(int line, int focus) {
    final below = line - focus;
    if (below <= 0) return Duration.zero;
    return staggerStep * math.min(below, maxStaggerLines);
  }

  /// 1.0 on the focus line, 0.96 elsewhere.
  static double scaleFor(int distance) => distance == 0 ? 1.0 : 0.96;

  /// Opacity of a line [distance] lines away from the focus.
  static double opacityFor(int distance) {
    final d = distance.abs();
    if (d == 0) return 1;
    return math.max(0.16, 0.56 - 0.1 * (d - 1));
  }

  /// Quantised blur level 0 ([blurLevels] max) for a line [distance] away.
  static int blurLevelFor(int distance) => math.min(distance.abs(), blurLevels);

  /// Sigma of a blur level.
  static double sigmaForLevel(int level) =>
      maxBlurSigma * level.clamp(0, blurLevels) / blurLevels;
}

/// Spring driven offset of one line.
///
/// [retarget] keeps the current velocity, so a new focus mid-flight bends the
/// motion instead of restarting it. A [delay] holds the old trajectory for a
/// while before the new spring starts (the stagger).
class LineSpring {
  LineSpring(double value) : _from = value, _target = value;

  double _from;
  double _target;
  double _startTime = 0;
  SpringSimulation? _simulation;
  double _velocityAtStart = 0;

  // The trajectory running before the latest retarget, used during the
  // delay.
  SpringSimulation? _previous;
  double _previousStart = 0;

  double get target => _target;

  /// Value at [time] (seconds, monotonic).
  double valueAt(double time) {
    if (time < _startTime) return _heldValue(time);
    final simulation = _ensureSimulation(time);
    if (simulation == null) return _target;
    return simulation.x(time - _startTime);
  }

  /// Velocity (px / s) at [time].
  double velocityAt(double time) {
    if (time < _startTime) return _heldVelocity(time);
    final simulation = _ensureSimulation(time);
    if (simulation == null) return 0;
    return simulation.dx(time - _startTime);
  }

  /// Whether the line is at rest on its target at [time].
  bool isDoneAt(double time) {
    if (time < _startTime) return false;
    final simulation = _ensureSimulation(time);
    return simulation == null || simulation.isDone(time - _startTime);
  }

  /// Heads for [target] starting [delay] seconds after [time], continuing
  /// from the position and velocity the line has at that moment.
  void retarget(double target, {required double time, double delay = 0}) {
    if (target == _target && isDoneAt(time)) return;
    if (time >= _startTime) {
      // Freeze the motion running now so the delay keeps following it.
      final running = _ensureSimulation(time);
      _previous = running;
      _previousStart = _startTime;
      if (running == null) _from = _target;
    }
    // Still inside an earlier delay: that held trajectory keeps running.
    _startTime = time + delay;
    _target = target;
    _simulation = null;
    _velocityAtStart = double.nan;
  }

  /// Puts the line exactly at [value] with no motion (manual scrolling).
  void jumpTo(double value) {
    _from = value;
    _target = value;
    _simulation = null;
    _previous = null;
    _startTime = 0;
    _velocityAtStart = 0;
  }

  double _heldValue(double time) {
    final previous = _previous;
    if (previous == null) return _from;
    return previous.x(time - _previousStart);
  }

  double _heldVelocity(double time) {
    final previous = _previous;
    if (previous == null) return 0;
    return previous.dx(time - _previousStart);
  }

  SpringSimulation? _ensureSimulation(double time) {
    if (_simulation != null) return _simulation;
    if (_velocityAtStart.isNaN) {
      // Materialise the spring from the state at its start time.
      final start = _heldValue(_startTime);
      _velocityAtStart = _heldVelocity(_startTime);
      _from = start;
      _previous = null;
      if ((start - _target).abs() < 0.01 && _velocityAtStart.abs() < 0.01) {
        _from = _target;
        return null;
      }
      _simulation = SpringSimulation(
        LyricMotion.spring,
        start,
        _target,
        _velocityAtStart,
        tolerance: const Tolerance(distance: 0.05, velocity: 0.5),
      );
      return _simulation;
    }
    return null;
  }
}
