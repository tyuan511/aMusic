import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';

/// Shared motion and colour primitives for the redesigned surfaces.
///
/// Everything here is built on implicit/explicit Flutter animations only, so
/// no extra dependency is pulled in and each effect stays local to its widget.

/// One ~30 fps clock for slow ambient motion: the player backdrop, the
/// breathing cover, the playing bars.
///
/// A vsync ticker asks for a frame, and with it a full composite of the scene
/// (glass and lyric blurs included), at the display rate. Motion this slow
/// looks the same at 30 fps, and one shared timer lands every subscriber on
/// the same frames instead of interleaving theirs. It runs only while someone
/// listens; widgets subscribe through [AmbientMotion].
class AmbientClock extends ChangeNotifier {
  AmbientClock._();

  static final AmbientClock instance = AmbientClock._();

  static const Duration interval = Duration(milliseconds: 33);

  final Stopwatch _elapsed = Stopwatch()..start();
  Timer? _timer;

  /// Monotonic time since start, for stateless waves.
  Duration get elapsed => _elapsed.elapsed;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _timer ??= Timer.periodic(interval, (_) => notifyListeners());
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    if (!hasListeners) {
      _timer?.cancel();
      _timer = null;
    }
  }
}

/// Subscribes a state to [AmbientClock] while [runAmbient] asked for it and
/// the subtree is not covered by an opaque route (its [TickerMode] is on).
mixin AmbientMotion<T extends StatefulWidget> on State<T> {
  bool _ambientWanted = false;
  bool _ambientVisible = true;
  bool _ambientSubscribed = false;

  /// Called on every ambient tick while running.
  void onAmbientTick();

  bool get ambientRunning => _ambientWanted;

  void runAmbient(bool run) {
    _ambientWanted = run;
    _syncAmbient();
  }

  void _syncAmbient() {
    final subscribe = _ambientWanted && _ambientVisible;
    if (subscribe == _ambientSubscribed) return;
    _ambientSubscribed = subscribe;
    if (subscribe) {
      AmbientClock.instance.addListener(onAmbientTick);
    } else {
      AmbientClock.instance.removeListener(onAmbientTick);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _ambientVisible = TickerMode.valuesOf(context).enabled;
    _syncAmbient();
  }

  @override
  void dispose() {
    _ambientWanted = false;
    _syncAmbient();
    super.dispose();
  }
}

/// Paints [child] (usually text or an icon) with the brand gradient.
class GradientText extends StatelessWidget {
  const GradientText(this.text, {super.key, this.style, this.gradient});

  final String text;
  final TextStyle? style;
  final Gradient? gradient;

  @override
  Widget build(BuildContext context) {
    final shader = gradient ?? context.surfaces.brand;
    return ShaderMask(
      blendMode: BlendMode.srcIn,
      shaderCallback: shader.createShader,
      child: Text(
        text,
        style: style,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
    );
  }
}

/// Fades and slides [child] in once, the first time it is built.
///
/// [index] staggers siblings (grid items, list rows); the delay is capped so a
/// long list does not keep animating after the first screenful.
class EntranceFade extends StatefulWidget {
  const EntranceFade({
    super.key,
    required this.child,
    this.index = 0,
    this.offset = const Offset(0, 0.06),
    this.duration = const Duration(milliseconds: 420),
  });

  final Widget child;
  final int index;
  final Offset offset;
  final Duration duration;

  static const int _maxStaggered = 12;
  static const Duration _step = Duration(milliseconds: 40);

  @override
  State<EntranceFade> createState() => _EntranceFadeState();
}

class _EntranceFadeState extends State<EntranceFade>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: widget.duration,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeOutCubic,
  );

  @override
  void initState() {
    super.initState();
    final slot = widget.index.clamp(0, EntranceFade._maxStaggered);
    final delay = EntranceFade._step * slot;
    if (delay == Duration.zero) {
      _controller.forward();
    } else {
      Future.delayed(delay, () {
        if (mounted) _controller.forward();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return FadeTransition(
      opacity: _curve,
      child: SlideTransition(
        position: Tween(begin: widget.offset, end: Offset.zero).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Lifts [child] on hover (and scales it down slightly while pressed), with an
/// optional coloured glow. Exposes the hover state to [builder] so the child
/// can reveal hover-only affordances.
class HoverLift extends StatefulWidget {
  const HoverLift({
    super.key,
    required this.builder,
    this.onTap,
    this.lift = 4,
    this.radius = 16,
    this.glow,
  });

  final Widget Function(BuildContext context, bool hovering) builder;
  final VoidCallback? onTap;
  final double lift;
  final double radius;

  /// Shadow colour shown while hovering; `null` disables the glow.
  final Color? glow;

  @override
  State<HoverLift> createState() => _HoverLiftState();
}

class _HoverLiftState extends State<HoverLift> {
  bool _hovering = false;
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final glow = widget.glow;
    return MouseRegion(
      cursor: widget.onTap == null
          ? MouseCursor.defer
          : SystemMouseCursors.click,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() {
        _hovering = false;
        _pressed = false;
      }),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        onTapDown: (_) => setState(() => _pressed = true),
        onTapUp: (_) => setState(() => _pressed = false),
        onTapCancel: () => setState(() => _pressed = false),
        child: AnimatedScale(
          scale: _pressed ? 0.97 : 1,
          duration: const Duration(milliseconds: 120),
          curve: Curves.easeOut,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeOutCubic,
            transform: Matrix4.translationValues(
              0,
              _hovering ? -widget.lift : 0,
              0,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(widget.radius),
              boxShadow: glow == null
                  ? null
                  : [
                      BoxShadow(
                        color: _hovering ? glow : glow.withValues(alpha: 0),
                        blurRadius: _hovering ? 26 : 8,
                        spreadRadius: -6,
                        offset: Offset(0, _hovering ? 14 : 4),
                      ),
                    ],
            ),
            child: widget.builder(context, _hovering),
          ),
        ),
      ),
    );
  }
}

/// Circular lime play button with a soft glow, used on cards and heroes.
class GradientPlayButton extends StatelessWidget {
  const GradientPlayButton({
    super.key,
    this.size = 40,
    this.icon = Icons.play_arrow_rounded,
    this.colors,
  });

  final double size;
  final IconData icon;

  /// Optional two-stop fill; defaults to the flat lime accent.
  final List<Color>? colors;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final palette = colors ?? [s.lime, s.lime];
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: palette,
        ),
        boxShadow: [
          BoxShadow(
            color: palette.first.withValues(alpha: 0.45),
            blurRadius: size * 0.45,
            offset: Offset(0, size * 0.12),
          ),
        ],
      ),
      child: Icon(
        icon,
        color: colors == null ? s.onLime : Colors.white,
        size: size * 0.55,
      ),
    );
  }
}
