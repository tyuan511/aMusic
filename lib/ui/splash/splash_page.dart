import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Shown while the persisted session and playback queue are restored: a lime
/// disc with a breathing glow over the ambient backdrop, the wordmark and a
/// slim loader.
class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          const AmbientBackdrop(),
          Center(
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0, end: 1),
              duration: AppMotion.page,
              curve: AppMotion.enter,
              builder: (context, t, child) => Opacity(
                opacity: t,
                child: Transform.scale(scale: 0.9 + 0.1 * t, child: child),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  AnimatedBuilder(
                    animation: _pulse,
                    builder: (context, child) {
                      final t = Curves.easeInOut.transform(_pulse.value);
                      return Container(
                        width: 96,
                        height: 96,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: s.lime,
                          boxShadow: [
                            BoxShadow(
                              color: s.lime.withValues(alpha: 0.25 + 0.3 * t),
                              blurRadius: 30 + 26 * t,
                              spreadRadius: 2 + 8 * t,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: CustomPaint(painter: _DiscPainter(s.onLime, s.lime)),
                  ),
                  const SizedBox(height: 28),
                  Text(
                    'aMusic',
                    style: context.text.headlineMedium?.copyWith(
                      fontSize: 32,
                      fontWeight: FontWeight.w500,
                      letterSpacing: -0.8,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '网易云音乐 · 随心而听',
                    style: context.text.bodySmall?.copyWith(
                      color: s.textSecondary,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 34),
                  SizedBox(
                    width: 64,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(2),
                      child: LinearProgressIndicator(
                        minHeight: 3,
                        color: s.lime,
                        backgroundColor: s.chip,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Vinyl grooves and a centre hole on the lime disc.
class _DiscPainter extends CustomPainter {
  const _DiscPainter(this.color, this.disc);

  final Color color;
  final Color disc;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = math.min(size.width, size.height) / 2;
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.2
      ..color = color.withValues(alpha: 0.18);
    for (final f in const [0.82, 0.68, 0.54]) {
      canvas.drawCircle(center, radius * f, groove);
    }
    canvas.drawCircle(center, radius * 0.24, Paint()..color = color);
    canvas.drawCircle(center, radius * 0.07, Paint()..color = disc);
  }

  @override
  bool shouldRepaint(_DiscPainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.disc != disc;
}
