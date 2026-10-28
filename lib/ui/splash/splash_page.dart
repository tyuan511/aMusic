import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Shown while the persisted session and playback queue are restored: the logo
/// with a breathing glow over the ambient backdrop, the wordmark and a
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
                          borderRadius: BorderRadius.circular(26),
                          boxShadow: [
                            BoxShadow(
                              color: s.lime.withValues(alpha: 0.2 + 0.25 * t),
                              blurRadius: 30 + 26 * t,
                              spreadRadius: 0 + 6 * t,
                            ),
                          ],
                        ),
                        child: child,
                      );
                    },
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(26),
                      child: Image.asset(
                        'assets/images/logo.png',
                        filterQuality: FilterQuality.medium,
                      ),
                    ),
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
