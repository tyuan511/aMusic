import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';

import '../../services/app.dart';
import '../../theme/app_theme.dart';

/// Flowing album colour backdrop of the now playing screen.
///
/// Five soft colour fields from [AccentService.palette] drift on closed
/// Lissajous paths (one loop every [loop]) over a near black base, under a
/// darkening vignette so white text stays legible. The painter repaints at
/// most ~30 fps and only while music plays; a track change cross-fades the
/// palette over 650 ms. `settings.dynamicBackground == false` keeps it still.
class PlayerBackdrop extends StatefulWidget {
  const PlayerBackdrop({super.key});

  static const Duration loop = Duration(seconds: 11);

  @override
  State<PlayerBackdrop> createState() => _PlayerBackdropState();
}

class _PlayerBackdropState extends State<PlayerBackdrop>
    with TickerProviderStateMixin {
  late final Ticker _ticker = createTicker(_onTick);
  late final AnimationController _fade = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 650),
    value: 1,
  );
  final ValueNotifier<double> _phase = ValueNotifier(0);

  List<Color> _from = const [];
  List<Color> _to = const [];
  Duration _phaseOffset = Duration.zero;
  Duration _lastPaint = Duration.zero;

  @override
  void initState() {
    super.initState();
    _to = app.accent.palette.value;
    app.accent.palette.addListener(_onPalette);
    app.settings.addListener(_syncTicker);
    app.player.playback.addListener(_syncTicker);
    _syncTicker();
  }

  @override
  void dispose() {
    app.accent.palette.removeListener(_onPalette);
    app.settings.removeListener(_syncTicker);
    app.player.playback.removeListener(_syncTicker);
    _ticker.dispose();
    _fade.dispose();
    _phase.dispose();
    super.dispose();
  }

  void _onPalette() {
    final next = app.accent.palette.value;
    if (next.isEmpty) return; // keep the old colours while the next loads
    setState(() {
      _from = _blend(_from, _to, _fade.value);
      _to = next;
    });
    _fade.forward(from: 0);
  }

  void _syncTicker() {
    final animate =
        app.settings.value.dynamicBackground &&
        app.player.playback.value.playing;
    if (animate && !_ticker.isActive) {
      _ticker.start();
    } else if (!animate && _ticker.isActive) {
      _phaseOffset += _lastPaint;
      _lastPaint = Duration.zero;
      _ticker.stop();
    }
  }

  void _onTick(Duration elapsed) {
    // ~30 fps is plenty for colour fields that move a few pixels a second.
    if (elapsed - _lastPaint < const Duration(milliseconds: 33)) return;
    _lastPaint = elapsed;
    final total = _phaseOffset + elapsed;
    _phase.value =
        (total.inMilliseconds % PlayerBackdrop.loop.inMilliseconds) /
        PlayerBackdrop.loop.inMilliseconds;
  }

  static List<Color> _blend(List<Color> a, List<Color> b, double t) {
    if (a.isEmpty) return b;
    if (b.isEmpty) return a;
    return [
      for (var i = 0; i < 5; i++)
        Color.lerp(a[i % a.length], b[i % b.length], t)!,
    ];
  }

  @override
  Widget build(BuildContext context) {
    final fallback = [
      ...context.surfaces.brandGradient,
      context.surfaces.plum,
      context.surfaces.lavender,
    ];
    return IgnorePointer(
      child: RepaintBoundary(
        child: CustomPaint(
          size: Size.infinite,
          painter: _MeshPainter(
            phase: _phase,
            fade: _fade,
            from: _from.isEmpty ? fallback : _from,
            to: _to.isEmpty ? fallback : _to,
            dark: context.isDark,
          ),
        ),
      ),
    );
  }
}

class _MeshPainter extends CustomPainter {
  _MeshPainter({
    required this.phase,
    required this.fade,
    required this.from,
    required this.to,
    required this.dark,
  }) : super(repaint: Listenable.merge([phase, fade]));

  final ValueNotifier<double> phase;
  final Animation<double> fade;
  final List<Color> from;
  final List<Color> to;
  final bool dark;

  static const Color _base = Color(0xFF07070A);
  static const Color _lightBase = Color(0xFFF7F7F3);

  // Integer frequencies keep every path closed over one loop.
  static const List<(double, double, int, int, double, double)> _paths = [
    (0.22, 0.24, 1, 1, 0.0, 0.95),
    (0.78, 0.30, -1, 2, 1.3, 0.85),
    (0.40, 0.66, 2, -1, 2.6, 0.9),
    (0.82, 0.80, 1, -2, 3.9, 0.75),
    (0.12, 0.88, -2, 1, 5.1, 0.7),
  ];

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty) return;
    final rect = Offset.zero & size;
    canvas.drawRect(rect, Paint()..color = dark ? _base : _lightBase);
    final t = fade.value;
    final angle = phase.value * 2 * math.pi;
    final extent = math.max(size.width, size.height);
    for (var i = 0; i < _paths.length; i++) {
      final (x, y, fx, fy, seed, scale) = _paths[i];
      final color = Color.lerp(from[i % from.length], to[i % to.length], t)!;
      final center = Offset(
        size.width * (x + 0.16 * math.sin(fx * angle + seed)),
        size.height * (y + 0.12 * math.cos(fy * angle + seed * 0.7)),
      );
      final radius = extent * 0.62 * scale;
      canvas.drawCircle(
        center,
        radius,
        Paint()
          ..shader = RadialGradient(
            colors: [
              color.withValues(alpha: 0.78),
              color.withValues(alpha: 0.32),
              color.withValues(alpha: 0),
            ],
            stops: const [0, 0.45, 1],
          ).createShader(Rect.fromCircle(center: center, radius: radius)),
      );
    }
    if (!dark) {
      // Light theme: wash the colour fields out so dark text stays legible.
      canvas.drawRect(rect, Paint()..color = const Color(0x8CFFFFFF));
      canvas.drawRect(
        rect,
        Paint()
          ..shader = const LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0x00FFFFFF), Color(0x00FFFFFF), Color(0x99FFFFFF)],
            stops: [0, 0.55, 1],
          ).createShader(rect),
      );
      return;
    }
    // Legibility: an overall dim, a vignette and a darker bottom for the
    // controls.
    canvas.drawRect(rect, Paint()..color = const Color(0x52000000));
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const RadialGradient(
          center: Alignment(0, -0.2),
          radius: 1.1,
          colors: [Color(0x00000000), Color(0x8C000000)],
          stops: [0.45, 1],
        ).createShader(rect),
    );
    canvas.drawRect(
      rect,
      Paint()
        ..shader = const LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [Color(0x00000000), Color(0x00000000), Color(0x99000000)],
          stops: [0, 0.55, 1],
        ).createShader(rect),
    );
  }

  @override
  bool shouldRepaint(_MeshPainter old) =>
      old.dark != dark || !identical(old.from, from) || !identical(old.to, to);
}
