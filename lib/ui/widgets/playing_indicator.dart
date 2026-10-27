import 'package:flutter/material.dart';

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
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  );

  @override
  void initState() {
    super.initState();
    if (widget.playing) _controller.repeat(reverse: true);
  }

  @override
  void didUpdateWidget(PlayingIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.playing == oldWidget.playing) return;
    if (widget.playing) {
      _controller.repeat(reverse: true);
    } else {
      _controller.stop();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // The painter listens to the controller: only this layer repaints.
    return RepaintBoundary(
      child: CustomPaint(
        size: Size(widget.size, widget.size),
        painter: _BarsPainter(
          color: widget.color,
          animation: _controller,
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
  final Animation<double> animation;
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
