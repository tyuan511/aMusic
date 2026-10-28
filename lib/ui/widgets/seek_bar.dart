import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';

/// Repaint signal for progress painters while a song plays.
///
/// Fires about once per physical pixel of progress (between 30 Hz and 1 Hz)
/// instead of every frame: a vsync ticker would make the engine composite the
/// whole scene, glass blurs included, 60 times a second for a bar that moves a
/// few pixels. A plain timer only asks for a frame when the bar actually moved.
class ProgressPulse extends ChangeNotifier {
  ProgressPulse(this._interval);

  final Duration Function() _interval;
  Timer? _timer;

  bool get isActive => _timer != null;

  void start() {
    if (_timer != null) return;
    _timer = Timer(_interval(), _fire);
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  void _fire() {
    notifyListeners();
    // A listener may have stopped the pulse.
    if (_timer != null) _timer = Timer(_interval(), _fire);
  }

  /// Time the playhead needs to cross one of [pixels] across a track of
  /// [duration].
  static Duration intervalFor(Duration duration, double pixels) {
    if (duration <= Duration.zero || pixels <= 0) {
      return const Duration(milliseconds: 250);
    }
    final speed = app.player.clock.speed;
    final micros = duration.inMicroseconds / pixels / math.max(speed, 0.1);
    return Duration(microseconds: micros.clamp(33000, 1000000).round());
  }

  @override
  void dispose() {
    stop();
    super.dispose();
  }
}

/// Seek bar that repaints with [ProgressPulse] without rebuilding any widget.
///
/// Playback position is read from [PlaybackClock] (interpolated between the
/// 5 Hz stream events) inside the painter, so the bar is smooth and the rest of
/// the tree is untouched while a song plays.
class SeekBar extends StatefulWidget {
  const SeekBar({
    super.key,
    this.color,
    this.compact = false,
    this.showTime = true,
    this.height = 26,
    this.onSeekStart,
    this.trackColor,
    this.spectrum = false,
    this.edge = false,
  });

  /// Unplayed part of the track; defaults to a faint grey.
  final Color? trackColor;

  /// Defaults to the album art accent.
  final Color? color;

  /// Thin line without a thumb, used by the mini player.
  final bool compact;
  final bool showTime;
  final double height;
  final VoidCallback? onSeekStart;

  /// Paints Rust-computed frequency bars instead of the compact line. This is
  /// enabled by the full-screen player; the mini player keeps the thin bar.
  final bool spectrum;

  /// A flat line glued to the top edge of the box (the docked mini player):
  /// square ends, with a thumb while hovered or dragged. The box is the hit
  /// area, so make it taller than the line.
  final bool edge;

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> {
  late final ProgressPulse _pulse = ProgressPulse(
    () => ProgressPulse.intervalFor(_duration, _pixels),
  );
  late final Listenable _repaint = widget.spectrum
      ? Listenable.merge([_pulse, app.player.spectrum])
      : _pulse;

  /// Track width in physical pixels, from the last layout.
  double _pixels = 0;

  /// False while an opaque route covers this bar (its [TickerMode] is off).
  bool _visible = true;

  bool _dragging = false;
  bool _hovering = false;
  double _dragFraction = 0;

  @override
  void initState() {
    super.initState();
    app.player.playback.addListener(_syncTicker);
    if (widget.spectrum) app.player.currentSongId.addListener(_ensureSpectrum);
    if (widget.spectrum) {
      _ensureSpectrum();
    }
    _syncTicker();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _syncTicker();
    }
  }

  void _ensureSpectrum() {
    if (!widget.spectrum) return;
    final song = app.player.currentSong;
    if (song != null) unawaited(app.player.ensureSpectrum(song));
  }

  void _syncTicker() {
    final shouldTick =
        app.player.playback.value.playing && !_dragging && _visible;
    if (shouldTick && !_pulse.isActive) {
      _pulse.start();
    } else if (!shouldTick && _pulse.isActive) {
      _pulse.stop();
      // One last repaint so the paused position is exact.
      setState(() {});
    }
  }

  @override
  void dispose() {
    app.player.playback.removeListener(_syncTicker);
    if (widget.spectrum) {
      app.player.currentSongId.removeListener(_ensureSpectrum);
    }
    _pulse.dispose();
    super.dispose();
  }

  Duration get _duration {
    final fromPlayer = app.player.position.value.duration;
    if (fromPlayer > Duration.zero) return fromPlayer;
    return app.player.currentSong?.duration ?? Duration.zero;
  }

  void _onDragStart(DragStartDetails details, double width) {
    widget.onSeekStart?.call();
    setState(() {
      _dragging = true;
      _dragFraction = _fractionAt(details.localPosition.dx, width);
    });
    _syncTicker();
  }

  void _onDragUpdate(DragUpdateDetails details, double width) {
    setState(
      () => _dragFraction = _fractionAt(details.localPosition.dx, width),
    );
  }

  void _onDragEnd(DragEndDetails details) {
    final duration = _duration;
    final fraction = _dragFraction;
    setState(() => _dragging = false);
    _syncTicker();
    if (duration > Duration.zero) {
      final target = duration * fraction;
      app.player.clock.sync(target, running: app.player.playback.value.playing);
      app.player.seek(target);
    }
  }

  void _onTapUp(TapUpDetails details, double width) {
    final duration = _duration;
    if (duration == Duration.zero) return;
    final fraction = _fractionAt(details.localPosition.dx, width);
    final target = duration * fraction;
    app.player.clock.sync(target, running: app.player.playback.value.playing);
    app.player.seek(target);
  }

  double _fractionAt(double dx, double width) {
    if (width <= 0) return 0;
    return (dx / width).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final accent = widget.color ?? AccentScope.of(context);
    final lowPerformance = context.lowPerformance;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        _pixels = width * MediaQuery.devicePixelRatioOf(context);
        final gesture = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) => _onDragStart(details, width),
          onHorizontalDragUpdate: (details) => _onDragUpdate(details, width),
          onHorizontalDragEnd: _onDragEnd,
          onTapUp: (details) => _onTapUp(details, width),
          child: RepaintBoundary(
            child: SizedBox(
              height: widget.height,
              child: _thumbAnimated(
                (thumb) => AnimatedBuilder(
                  animation: _repaint,
                  builder: (context, _) {
                    final clock = app.player.clock;
                    final fraction = _dragging
                        ? _dragFraction
                        : _fractionOf(clock.now(), _duration);
                    return CustomPaint(
                      size: Size(width, widget.height),
                      painter: _SeekBarPainter(
                        fraction: fraction,
                        buffered: _dragging ? 0 : _bufferedFraction(),
                        accent: accent,
                        trackColor:
                            widget.trackColor ??
                            context.surfaces.textTertiary.withValues(
                              alpha: 0.22,
                            ),
                        compact: widget.compact,
                        dragging: _dragging,
                        hovering: _hovering,
                        thumbColor: accent,
                        spectrum: widget.spectrum,
                        spectrumValues: widget.spectrum
                            ? app.player.spectrum.value
                            : null,
                        glow: !lowPerformance,
                        edge: widget.edge,
                        thumb: thumb,
                      ),
                    );
                  },
                ),
              ),
            ),
          ),
        );
        if (widget.compact && !widget.edge) return gesture;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: gesture,
        );
      },
    );
  }

  /// Animates the edge style's thumb in and out; other styles get a constant.
  Widget _thumbAnimated(Widget Function(double thumb) builder) {
    if (!widget.edge) return builder(0);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _dragging || _hovering ? 1.0 : 0.0),
      duration: AppMotion.quick,
      curve: AppMotion.enter,
      builder: (context, t, _) => builder(t),
    );
  }

  double _fractionOf(Duration position, Duration duration) {
    if (duration <= Duration.zero) return 0;
    return (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
  }

  double _bufferedFraction() {
    final state = app.player.position.value;
    if (state.duration <= Duration.zero) return 0;
    return (state.buffered.inMilliseconds / state.duration.inMilliseconds)
        .clamp(0.0, 1.0);
  }
}

/// Time labels below a [SeekBar]. Rebuilds at 5 Hz, which is invisible for text
/// and far cheaper than repainting at 60 Hz.
class SeekTimeRow extends StatelessWidget {
  const SeekTimeRow({super.key, this.style, this.remaining = false});

  final TextStyle? style;

  /// Show `-m:ss` remaining on the right instead of the total.
  final bool remaining;

  @override
  Widget build(BuildContext context) {
    final textStyle =
        style ??
        context.text.bodySmall?.copyWith(
          color: context.surfaces.textSecondary,
          fontFeatures: const [FontFeature.tabularFigures()],
        );
    return ValueListenableBuilder(
      valueListenable: app.player.position,
      builder: (context, state, _) {
        final duration = state.duration > Duration.zero
            ? state.duration
            : (app.player.currentSong?.duration ?? Duration.zero);
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(state.position.clock, style: textStyle),
            Text(
              remaining
                  ? remainingLabel(duration - state.position)
                  : duration.clock,
              style: textStyle,
            ),
          ],
        );
      },
    );
  }
}

class _SeekBarPainter extends CustomPainter {
  _SeekBarPainter({
    required this.fraction,
    required this.buffered,
    required this.accent,
    required this.trackColor,
    required this.compact,
    required this.dragging,
    required this.hovering,
    required this.thumbColor,
    required this.spectrum,
    required this.spectrumValues,
    required this.glow,
    required this.edge,
    required this.thumb,
  });

  final bool hovering;
  final double fraction;
  final double buffered;
  final Color accent;
  final Color trackColor;
  final bool compact;
  final bool dragging;
  final Color thumbColor;
  final bool spectrum;
  final List<int>? spectrumValues;

  /// Blurred bloom under the played spectrum (off in low performance mode).
  final bool glow;
  final bool edge;

  /// 0 - 1 appearance of the edge style's thumb.
  final double thumb;

  @override
  void paint(Canvas canvas, Size size) {
    if (spectrum) {
      _paintSpectrum(canvas, size);
      return;
    }
    if (edge) {
      const thickness = 2.5;
      canvas
        ..drawRect(
          Rect.fromLTWH(0, 0, size.width, thickness),
          Paint()..color = trackColor,
        )
        ..drawRect(
          Rect.fromLTWH(0, 0, size.width * fraction, thickness),
          Paint()..color = accent,
        );
      if (thumb > 0) {
        // Centred on the line, so the upper half spills over the bar's edge.
        final thumbRadius = (dragging ? 7.0 : 6.0) * thumb;
        canvas.drawCircle(
          Offset(size.width * fraction, thickness / 2),
          thumbRadius,
          Paint()..color = thumbColor.withValues(alpha: thumb),
        );
      }
      return;
    }
    final thickness = compact ? 2.5 : (dragging || hovering ? 5.0 : 4.0);
    final centerY = size.height / 2;
    final radius = Radius.circular(thickness / 2);
    final trackRect = Rect.fromLTWH(
      0,
      centerY - thickness / 2,
      size.width,
      thickness,
    );

    canvas.drawRRect(
      RRect.fromRectAndRadius(trackRect, radius),
      Paint()..color = trackColor,
    );

    if (!compact && buffered > fraction) {
      final bufferedRect = Rect.fromLTWH(
        0,
        centerY - thickness / 2,
        size.width * buffered,
        thickness,
      );
      canvas.drawRRect(
        RRect.fromRectAndRadius(bufferedRect, radius),
        Paint()..color = trackColor.withValues(alpha: 0.55),
      );
    }

    final progressRect = Rect.fromLTWH(
      0,
      centerY - thickness / 2,
      size.width * fraction,
      thickness,
    );
    final progressPaint = Paint()..color = accent;
    canvas.drawRRect(
      RRect.fromRectAndRadius(progressRect, radius),
      progressPaint,
    );

    if (compact) return;

    final thumbRadius = dragging ? 8.5 : (hovering ? 7.5 : 6.5);
    final thumbX = size.width * fraction;
    canvas.drawCircle(
      Offset(thumbX, centerY),
      thumbRadius + 3,
      Paint()..color = accent.withValues(alpha: dragging ? 0.24 : 0.0),
    );
    canvas.drawCircle(
      Offset(thumbX, centerY),
      thumbRadius,
      Paint()..color = thumbColor,
    );
  }

  void _paintSpectrum(Canvas canvas, Size size) {
    final values = spectrumValues;
    final sourceCount = values == null || values.isEmpty ? 72 : values.length;
    // Dense ~3px pitch so the bars merge into a continuous waveform envelope.
    final count = math.max(48, (size.width / 3).floor());
    final center = size.height / 2;
    final slot = size.width / count;
    final barWidth = math.max(1.4, slot * 0.62);
    final playedX = size.width * fraction;
    final bufferedX = size.width * buffered;

    final shaped = values == null || values.isEmpty
        ? null
        : _shapeSpectrum(values);
    double valueAt(int index) {
      if (shaped == null) {
        final slow = math.sin(index * 0.19 + 0.8).abs();
        final quick = math.sin(index * 0.53 + 1.4).abs();
        return 0.12 + slow * 0.28 + quick * 0.2;
      }
      final position = index * (sourceCount - 1) / (count - 1);
      final left = position.floor().clamp(0, sourceCount - 1);
      final right = math.min(left + 1, sourceCount - 1);
      final t = position - left;
      return shaped[left] + (shaped[right] - shaped[left]) * t;
    }

    // Only a whisper of smoothing: enough to hide interpolation seams, not so
    // much that the peaks melt into a flat ribbon.
    final raw = List<double>.generate(count, (i) => valueAt(i).clamp(0.0, 1.0));
    final smoothed = List<double>.generate(count, (i) {
      double at(int k) => raw[k.clamp(0, count - 1)];
      return at(i - 1) * 0.15 + at(i) * 0.7 + at(i + 1) * 0.15;
    });

    final maxHalf = size.height / 2 - 1;
    // Vertical gradient shared by all bars: solid at the centre line, fading
    // towards the tips, so the mirrored waveform glows from the middle out.
    final bounds = Offset.zero & size;
    Paint fade(Color color) {
      final tip = color.withValues(alpha: color.a * 0.22);
      return Paint()
        ..isAntiAlias = true
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [tip, color, tip],
          stops: const [0.0, 0.5, 1.0],
        ).createShader(bounds);
    }

    final playedPaint = fade(accent);
    final bufferedPaint = fade(accent.withValues(alpha: 0.5));
    final restPaint = fade(trackColor.withValues(alpha: trackColor.a * 1.6));
    final glowPath = Path();
    for (var i = 0; i < count; i++) {
      // Taper both ends so the waveform reads as a lens-shaped envelope.
      final edge = (math.min(i, count - 1 - i) / (count * 0.08)).clamp(
        0.0,
        1.0,
      );
      final taper = 0.35 + 0.65 * edge * edge * (3 - 2 * edge);
      final half = math.max(
        barWidth / 2,
        maxHalf * (0.04 + smoothed[i] * 0.96) * taper,
      );
      final x = slot * (i + 0.5);
      final played = x <= playedX;
      final paint = played
          ? playedPaint
          : x <= bufferedX
          ? bufferedPaint
          : restPaint;
      final bar = RRect.fromRectAndRadius(
        Rect.fromCenter(
          center: Offset(x, center),
          width: barWidth,
          height: half * 2,
        ),
        Radius.circular(barWidth / 2),
      );
      if (played && glow) glowPath.addRRect(bar);
      canvas.drawRRect(bar, paint);
    }

    // Soft bloom under the played part. Drawn after the bars with a low alpha
    // so it only lifts the colour instead of smearing the shape.
    if (glow && playedX > 0) {
      canvas.drawPath(
        glowPath,
        Paint()
          ..color = accent.withValues(alpha: 0.35)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5),
      );
    }

    // Playhead: a tall line that fades out at both ends, with a small bright
    // core that grows on hover/drag.
    final active = hovering || dragging;
    final head = Rect.fromLTRB(
      playedX - 1,
      center - maxHalf,
      playedX + 1,
      center + maxHalf,
    );
    canvas.drawRRect(
      RRect.fromRectAndRadius(head, const Radius.circular(1)),
      Paint()
        ..shader = LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            accent.withValues(alpha: 0),
            accent,
            accent.withValues(alpha: 0),
          ],
        ).createShader(head),
    );
    canvas.drawCircle(
      Offset(playedX, center),
      active ? 4.0 : 2.6,
      Paint()..color = accent,
    );
  }

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.fraction != fraction ||
      old.buffered != buffered ||
      old.accent != accent ||
      old.compact != compact ||
      old.dragging != dragging ||
      old.hovering != hovering ||
      old.trackColor != trackColor ||
      old.spectrum != spectrum ||
      old.spectrumValues != spectrumValues ||
      old.glow != glow ||
      old.edge != edge ||
      old.thumb != thumb;
}

/// `-2:15`; clamps negative remainders to `-0:00`.
String remainingLabel(Duration remaining) =>
    '-${(remaining.isNegative ? Duration.zero : remaining).clock}';

final _shapedSpectra = Expando<List<double>>('shapedSpectrum');

/// Stretches the engine's envelope so the bar has real hills and valleys.
///
/// The bytes arrive already normalised, but loud masters still sit in a
/// narrow band near the top. Re-spreading between the 8th and 96th percentile
/// and then applying a >1 curve pushes the quiet parts down and lets the
/// drums and choruses stand tall. Cached per list since it runs every frame.
List<double> _shapeSpectrum(List<int> values) {
  final cached = _shapedSpectra[values];
  if (cached != null) return cached;
  final sorted = [...values]..sort();
  int at(double q) => sorted[((sorted.length - 1) * q).round()];
  final low = at(0.08).toDouble();
  final spread = math.max(1.0, at(0.96) - low);
  final shaped = List<double>.unmodifiable(
    values.map((v) => math.pow(((v - low) / spread).clamp(0.0, 1.0), 1.7)),
  );
  _shapedSpectra[values] = shaped;
  return shaped;
}
