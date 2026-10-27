import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';

/// Seek bar that repaints on every frame without rebuilding any widget.
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

  @override
  State<SeekBar> createState() => _SeekBarState();
}

class _SeekBarState extends State<SeekBar> with SingleTickerProviderStateMixin {
  late final AnimationController _ticker = AnimationController(
    vsync: this,
    duration: const Duration(hours: 1),
  );

  bool _dragging = false;
  bool _hovering = false;
  double _dragFraction = 0;

  @override
  void initState() {
    super.initState();
    app.player.playback.addListener(_syncTicker);
    _syncTicker();
  }

  void _syncTicker() {
    final shouldTick = app.player.playback.value.playing && !_dragging;
    if (shouldTick && !_ticker.isAnimating) {
      _ticker.repeat();
    } else if (!shouldTick && _ticker.isAnimating) {
      _ticker.stop();
      // One last repaint so the paused position is exact.
      setState(() {});
    }
  }

  @override
  void dispose() {
    app.player.playback.removeListener(_syncTicker);
    _ticker.dispose();
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final gesture = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onHorizontalDragStart: (details) => _onDragStart(details, width),
          onHorizontalDragUpdate: (details) => _onDragUpdate(details, width),
          onHorizontalDragEnd: _onDragEnd,
          onTapUp: (details) => _onTapUp(details, width),
          child: RepaintBoundary(
            child: SizedBox(
              height: widget.height,
              child: AnimatedBuilder(
                animation: _ticker,
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
                          context.surfaces.textTertiary.withValues(alpha: 0.22),
                      compact: widget.compact,
                      dragging: _dragging,
                      hovering: _hovering,
                      thumbColor: accent,
                    ),
                  );
                },
              ),
            ),
          ),
        );
        if (widget.compact) return gesture;
        return MouseRegion(
          cursor: SystemMouseCursors.click,
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: gesture,
        );
      },
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
  });

  final bool hovering;
  final double fraction;
  final double buffered;
  final Color accent;
  final Color trackColor;
  final bool compact;
  final bool dragging;
  final Color thumbColor;

  @override
  void paint(Canvas canvas, Size size) {
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

  @override
  bool shouldRepaint(_SeekBarPainter old) =>
      old.fraction != fraction ||
      old.buffered != buffered ||
      old.accent != accent ||
      old.compact != compact ||
      old.dragging != dragging ||
      old.hovering != hovering ||
      old.trackColor != trackColor;
}

/// `-2:15`; clamps negative remainders to `-0:00`.
String remainingLabel(Duration remaining) =>
    '-${(remaining.isNegative ? Duration.zero : remaining).clock}';
