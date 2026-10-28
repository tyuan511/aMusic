import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../widgets/cover_image.dart';

/// Motion shared by the mini player ⇄ now playing transition. The route
/// reveal, the cover hero and the staggered content all read the same curve
/// so the pieces move as one.
abstract final class PlayerMotion {
  static const open = Duration(milliseconds: 520);
  static const close = Duration(milliseconds: 420);

  /// Material 3 "emphasized" easing: quick start, long soft landing.
  static const Curve curve = Cubic(0.2, 0, 0, 1);

  /// The animation value runs 1 → 0 when closing; flipping the curve makes
  /// the close start fast and settle gently into the mini player too.
  static const Curve reverseCurve = FlippedCurve(curve);

  static const coverHeroTag = 'now-playing-cover';
}

/// Lets the route transition find where the mini player sits on screen so the
/// player can grow out of it (and shrink back into it).
class MiniPlayerAnchor extends StatefulWidget {
  const MiniPlayerAnchor({super.key, required this.child});

  final Widget child;

  static _MiniPlayerAnchorState? _current;

  /// Global rect of the mounted mini player, or null when there is none.
  static Rect? rect() {
    final state = _current;
    if (state == null || !state.mounted) return null;
    final box = state.context.findRenderObject();
    if (box is! RenderBox || !box.attached || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }

  @override
  State<MiniPlayerAnchor> createState() => _MiniPlayerAnchorState();
}

class _MiniPlayerAnchorState extends State<MiniPlayerAnchor> {
  @override
  void initState() {
    super.initState();
    MiniPlayerAnchor._current = this;
  }

  @override
  void dispose() {
    if (MiniPlayerAnchor._current == this) MiniPlayerAnchor._current = null;
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Container-transform style route transition: the player is clipped to the
/// mini player's bar and expands to full screen, rounding off the corners as
/// it goes. Closing runs it backwards, so the page collapses into the bar.
class PlayerRouteTransition extends StatefulWidget {
  const PlayerRouteTransition({
    super.key,
    required this.animation,
    required this.child,
  });

  final Animation<double> animation;
  final Widget child;

  @override
  State<PlayerRouteTransition> createState() => _PlayerRouteTransitionState();
}

class _PlayerRouteTransitionState extends State<PlayerRouteTransition> {
  late CurvedAnimation _curved = _curve(widget.animation);

  CurvedAnimation _curve(Animation<double> parent) => CurvedAnimation(
    parent: parent,
    curve: PlayerMotion.curve,
    reverseCurve: PlayerMotion.reverseCurve,
  );

  @override
  void didUpdateWidget(PlayerRouteTransition oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.animation != widget.animation) {
      _curved.dispose();
      _curved = _curve(widget.animation);
    }
  }

  @override
  void dispose() {
    _curved.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: widget.animation,
      child: widget.child,
      builder: (context, child) {
        final t = _curved.value;
        final raw = widget.animation.value;
        final settled = raw >= 1;
        // Fade the dark page in quickly while it is still small, so the bar
        // turns into the player rather than a hole opening behind it.
        final opacity = Curves.easeOut.transform((raw / 0.3).clamp(0.0, 1.0));
        return ClipRRect(
          clipper: _RevealClipper(t),
          clipBehavior: settled ? Clip.none : Clip.antiAlias,
          child: Opacity(
            opacity: opacity,
            // Vertical only: a uniform scale shrinks the page towards the
            // screen centre, which leaves the clip's far edge (the mini
            // player sits off-centre next to the sidebar) uncovered, so the
            // page behind showed through there.
            child: Transform.scale(
              scaleX: 1,
              scaleY: lerpDouble(0.94, 1, t)!,
              alignment: Alignment.bottomCenter,
              child: child,
            ),
          ),
        );
      },
    );
  }
}

class _RevealClipper extends CustomClipper<RRect> {
  _RevealClipper(this.t);

  final double t;

  @override
  RRect getClip(Size size) {
    final full = Offset.zero & size;
    final from =
        MiniPlayerAnchor.rect() ??
        Rect.fromLTRB(16, size.height - 96, size.width - 16, size.height - 12);
    final rect = Rect.lerp(from, full, t)!;
    final radius = lerpDouble(AppMetrics.radiusLg, 0, t)!;
    return RRect.fromRectAndRadius(rect, Radius.circular(radius));
  }

  @override
  bool shouldReclip(_RevealClipper oldClipper) => oldClipper.t != t;
}

/// The album cover shared by the mini player and the now playing page. While
/// the route animates it flies between them, morphing from the mini player's
/// rounded square into the spinning disc.
class NowPlayingCoverHero extends StatelessWidget {
  const NowPlayingCoverHero({
    super.key,
    required this.url,
    required this.isPlayer,
    required this.child,
    this.accent,
  });

  final String? url;

  /// True on the now playing page (the disc), false in the mini player.
  final bool isPlayer;

  /// Glow colour of the disc; only meaningful on the player side.
  final Color? accent;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Hero(
      tag: PlayerMotion.coverHeroTag,
      curve: PlayerMotion.curve,
      reverseCurve: PlayerMotion.reverseCurve,
      createRectTween: (begin, end) =>
          MaterialRectCenterArcTween(begin: begin, end: end),
      flightShuttleBuilder: _shuttle,
      child: child,
    );
  }

  static Widget _shuttle(
    BuildContext flightContext,
    Animation<double> animation,
    HeroFlightDirection direction,
    BuildContext fromContext,
    BuildContext toContext,
  ) {
    // The metadata lives on the NowPlayingCoverHero that built each Hero.
    final fromCover = fromContext
        .findAncestorWidgetOfExactType<NowPlayingCoverHero>();
    final toCover = toContext
        .findAncestorWidgetOfExactType<NowPlayingCoverHero>();
    final player = (fromCover?.isPlayer ?? false) ? fromCover : toCover;
    final url = toCover?.url ?? fromCover?.url;
    if (url == null) return (toContext.widget as Hero).child;
    return _CoverShuttle(
      // Value runs 0 (mini player) → 1 (player) in both directions.
      animation: animation,
      url: url,
      accent: player?.accent,
    );
  }
}

class _CoverShuttle extends StatelessWidget {
  const _CoverShuttle({
    required this.animation,
    required this.url,
    required this.accent,
  });

  final Animation<double> animation;
  final String url;
  final Color? accent;

  @override
  Widget build(BuildContext context) {
    final accent = this.accent ?? context.surfaces.lavender;
    return LayoutBuilder(
      builder: (context, constraints) {
        final side = constraints.biggest.shortestSide;
        // Same decode size as the disc so the full-size image is a cache hit.
        final decode = (side * 2).clamp(300, 1000).round();
        return AnimatedBuilder(
          animation: animation,
          builder: (context, _) {
            final t = animation.value.clamp(0.0, 1.0);
            final radius = BorderRadius.circular(
              lerpDouble(AppMetrics.radiusSm, AppMetrics.radiusLg, t)!,
            );
            return DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: radius,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5 * t),
                    blurRadius: lerpDouble(8, 40, t)!,
                    offset: Offset(0, lerpDouble(4, 22, t)!),
                  ),
                  BoxShadow(
                    color: accent.withValues(alpha: 0.32 * t),
                    blurRadius: 70 * t,
                    spreadRadius: -8,
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: radius,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    // Mini player resolution is always cached, so it covers
                    // the frame or two before the large image decodes.
                    CoverImage(url: url, size: 160, radius: 0),
                    CoverImage(
                      url: url,
                      size: decode,
                      radius: 0,
                      placeholder: const SizedBox.shrink(),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }
}

/// Fades and lifts a piece of the player in after the route starts opening,
/// [delay] (0–1 of the open animation) after the previous piece. On close it
/// fades out early so only the cover and the shrinking card remain.
class PlayerEntrance extends StatelessWidget {
  const PlayerEntrance({
    super.key,
    required this.delay,
    required this.child,
    this.offset = const Offset(0, 24),
  });

  final double delay;
  final Offset offset;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final animation = ModalRoute.of(context)?.animation;
    if (animation == null) return child;
    return AnimatedBuilder(
      animation: animation,
      child: child,
      builder: (context, child) {
        final raw = animation.value;
        // Keep the same tree shape when settled so the child keeps its state.
        final double t;
        if (raw >= 1) {
          t = 1;
        } else if (animation.status == AnimationStatus.reverse) {
          // Closing: gone during the first ~40% of the shrink.
          t = Curves.easeIn.transform(((raw - 0.6) / 0.4).clamp(0.0, 1.0));
        } else {
          const span = 0.55;
          t = Curves.easeOutCubic.transform(
            ((raw - delay) / span).clamp(0.0, 1.0),
          );
        }
        return Opacity(
          opacity: t,
          child: Transform.translate(offset: offset * (1 - t), child: child),
        );
      },
    );
  }
}
