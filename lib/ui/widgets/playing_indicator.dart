import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'motion.dart';

/// Three animated bars shown on the cover of the currently playing track.
///
/// Only the active row ever builds this, so the animation cost is one widget.
class PlayingIndicator extends StatefulWidget {
  const PlayingIndicator({
    super.key,
    this.color = Colors.white,
    this.size = 14,
    this.playing = true,
  });

  final Color color;
  final double size;
  final bool playing;

  @override
  State<PlayingIndicator> createState() => _PlayingIndicatorState();
}

class _PlayingIndicatorState extends State<PlayingIndicator>
    with AmbientMotion {
  /// 0 - 1 - 0 every 1.8 s, sampled from the shared [AmbientClock]: a vsync
  /// ticker here would keep the whole list page compositing at 60 fps for
  /// three tiny bars.
  final ValueNotifier<double> _t = ValueNotifier(0.35);

  static const int _halfMs = 900;

  // Low performance mode keeps the bars still.
  void _sync() => runAmbient(widget.playing && !context.lowPerformance);

  @override
  void didUpdateWidget(PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void dispose() {
    _t.dispose();
    super.dispose();
  }

  @override
  void onAmbientTick() {
    final ms = AmbientClock.instance.elapsed.inMilliseconds % (_halfMs * 2);
    _t.value = ms < _halfMs ? ms / _halfMs : 2 - ms / _halfMs;
  }

  @override
  Widget build(BuildContext context) {
    // The painter listens to the wave: only this layer repaints.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _BarsPainter(
          color: widget.color,
          animation: _t,
          playing: widget.playing,
        ),
      ),
    );
  }
}

class _BarsPainter extends CustomPainter {
  _BarsPainter({
    required this.color,
    required this.animation,
    required this.playing,
  }) : super(repaint: animation);

  final Color color;
  final ValueListenable<double> animation;
  final bool playing;

  @override
  void paint(Canvas canvas, Size size) {
    final t = playing ? animation.value : 0.35;
    final paint = Paint()..color = color;
    final barWidth = size.width / 5;
    final heights = [0.45 + 0.55 * t, 1.0 - 0.55 * t, 0.6 + 0.4 * (1 - t)];
    for (var i = 0; i < 3; i++) {
      final left = i * barWidth * 2;
      final height = size.height * heights[i];
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(left, size.height - height, barWidth, height),
          Radius.circular(barWidth / 2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_BarsPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.playing != playing;
}
