import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'cover_image.dart';

/// Shared building blocks of the "midnight lime" design language.
///
/// Every screen composes these instead of styling raw Material widgets, so
/// spacing, radii and motion stay consistent and a restyle happens in one
/// place. All of them animate with the tokens in [AppMotion].

// ---------------------------------------------------------------- pressable

/// Scales [child] down while pressed and slightly up while hovered.
///
/// The base interaction for every tappable custom surface in the app.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.child,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.pressedScale = 0.95,
    this.hoverScale = 1.0,
    this.semanticLabel,
  });

  final Widget child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final double pressedScale;
  final double hoverScale;
  final String? semanticLabel;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable> {
  bool _hovering = false;
  bool _pressed = false;

  bool get _enabled => widget.onTap != null || widget.onLongPress != null;

  @override
  Widget build(BuildContext context) {
    final scale = _pressed
        ? widget.pressedScale
        : (_hovering ? widget.hoverScale : 1.0);
    return Semantics(
      button: _enabled,
      label: widget.semanticLabel,
      child: MouseRegion(
        cursor: _enabled ? SystemMouseCursors.click : MouseCursor.defer,
        onEnter: (_) => setState(() => _hovering = true),
        onExit: (_) => setState(() {
          _hovering = false;
          _pressed = false;
        }),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onTap,
          onLongPress: widget.onLongPress,
          onSecondaryTap: widget.onSecondaryTap,
          onTapDown: _enabled ? (_) => setState(() => _pressed = true) : null,
          onTapUp: _enabled ? (_) => setState(() => _pressed = false) : null,
          onTapCancel: _enabled ? () => setState(() => _pressed = false) : null,
          child: AnimatedScale(
            scale: scale,
            duration: _pressed ? AppMotion.instant : AppMotion.quick,
            curve: _pressed ? Curves.easeOut : AppMotion.pop,
            child: widget.child,
          ),
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- chips

/// Pill chip: lime when selected, charcoal otherwise. Colour and label weight
/// cross-fade on selection.
class PillChip extends StatelessWidget {
  const PillChip({
    super.key,
    required this.label,
    required this.selected,
    this.onTap,
    this.icon,
    this.dense = false,
  });

  final String label;
  final bool selected;
  final VoidCallback? onTap;
  final IconData? icon;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final foreground = selected
        ? s.onLime
        : context.colors.onSurface.withValues(alpha: 0.86);
    return Pressable(
      onTap: onTap,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.enter,
        padding: EdgeInsets.symmetric(
          horizontal: dense ? 14 : 20,
          vertical: dense ? 8 : 11,
        ),
        decoration: BoxDecoration(
          color: selected ? s.lime : s.chip,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
          boxShadow: selected
              ? [
                  BoxShadow(
                    color: s.glow,
                    blurRadius: 16,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (icon != null) ...[
              Icon(icon, size: dense ? 15 : 17, color: foreground),
              const SizedBox(width: 6),
            ],
            AnimatedDefaultTextStyle(
              duration: AppMotion.quick,
              style: context.text.labelLarge!.copyWith(
                color: foreground,
                fontSize: dense ? 13 : 14.5,
                fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
              ),
              child: Text(label),
            ),
          ],
        ),
      ),
    );
  }
}

/// Horizontally scrolling row of [PillChip]s with single selection.
class ChipBar<T> extends StatelessWidget {
  const ChipBar({
    super.key,
    required this.values,
    required this.selected,
    required this.labelOf,
    required this.onSelected,
    this.padding = const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
    this.dense = false,
  });

  final List<T> values;
  final T selected;
  final String Function(T value) labelOf;
  final ValueChanged<T> onSelected;
  final EdgeInsetsGeometry padding;
  final bool dense;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: dense ? 38 : 46,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        clipBehavior: Clip.none,
        itemCount: values.length,
        separatorBuilder: (_, _) => const SizedBox(width: 10),
        itemBuilder: (context, index) {
          final value = values[index];
          return Center(
            child: PillChip(
              label: labelOf(value),
              selected: value == selected,
              dense: dense,
              onTap: () => onSelected(value),
            ),
          );
        },
      ),
    );
  }
}

// ------------------------------------------------------------------- buttons

/// Circular charcoal icon button (search, like, back, more ...).
class RoundIconButton extends StatelessWidget {
  const RoundIconButton({
    super.key,
    required this.icon,
    this.onPressed,
    this.tooltip,
    this.size = 46,
    this.iconSize,
    this.color,
    this.iconColor,
    this.active = false,
  });

  final IconData icon;
  final VoidCallback? onPressed;
  final String? tooltip;
  final double size;
  final double? iconSize;

  /// Fill override; defaults to the chip colour (lime when [active]).
  final Color? color;
  final Color? iconColor;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final fill = color ?? (active ? s.lime : s.chip);
    final fg =
        iconColor ??
        (active
            ? s.onLime
            : (onPressed == null
                  ? s.textTertiary.withValues(alpha: 0.5)
                  : context.colors.onSurface));
    final button = Pressable(
      onTap: onPressed,
      hoverScale: 1.06,
      semanticLabel: tooltip,
      child: AnimatedContainer(
        duration: AppMotion.standard,
        width: size,
        height: size,
        decoration: BoxDecoration(color: fill, shape: BoxShape.circle),
        child: AnimatedSwitcher(
          duration: AppMotion.quick,
          transitionBuilder: (child, animation) => ScaleTransition(
            scale: animation,
            child: FadeTransition(opacity: animation, child: child),
          ),
          child: Icon(
            icon,
            key: ValueKey(icon),
            size: iconSize ?? size * 0.46,
            color: fg,
          ),
        ),
      ),
    );
    if (tooltip == null) return button;
    return Tooltip(message: tooltip!, child: button);
  }
}

/// The lime play / pause button. The glyph morphs with a rotate + scale when
/// [playing] flips and the glow breathes while playing.
class AccentPlayButton extends StatelessWidget {
  const AccentPlayButton({
    super.key,
    required this.playing,
    this.onPressed,
    this.size = 64,
    this.loading = false,
    this.color,
    this.iconColor,
  });

  final bool playing;
  final bool loading;
  final VoidCallback? onPressed;
  final double size;
  final Color? color;
  final Color? iconColor;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final fill = onPressed == null ? s.chip : (color ?? s.lime);
    final fg = onPressed == null ? s.textTertiary : (iconColor ?? s.onLime);
    final icon = playing ? Icons.pause_rounded : Icons.play_arrow_rounded;
    return Tooltip(
      message: playing ? '暂停' : '播放',
      child: Pressable(
        onTap: onPressed,
        pressedScale: 0.9,
        hoverScale: 1.05,
        child: AnimatedContainer(
          duration: AppMotion.emphasized,
          curve: AppMotion.enter,
          width: size,
          height: size,
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            boxShadow: onPressed == null
                ? null
                : [
                    BoxShadow(
                      color: fill.withValues(alpha: playing ? 0.5 : 0.3),
                      blurRadius: playing ? size * 0.5 : size * 0.28,
                      spreadRadius: playing ? 1 : 0,
                      offset: Offset(0, size * 0.08),
                    ),
                  ],
          ),
          child: Center(
            child: AnimatedSwitcher(
              duration: AppMotion.standard,
              transitionBuilder: (child, animation) => RotationTransition(
                turns: Tween(begin: -0.15, end: 0.0).animate(animation),
                child: ScaleTransition(scale: animation, child: child),
              ),
              child: loading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: size * 0.38,
                      height: size * 0.38,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.4,
                        color: fg,
                      ),
                    )
                  : Icon(
                      icon,
                      key: ValueKey(icon),
                      size: size * 0.5,
                      color: fg,
                    ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Small round play affordance at the end of list rows.
class RowPlayButton extends StatelessWidget {
  const RowPlayButton({
    super.key,
    this.onPressed,
    this.playing = false,
    this.size = 38,
  });

  final VoidCallback? onPressed;
  final bool playing;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      onTap: onPressed,
      hoverScale: 1.1,
      semanticLabel: playing ? '暂停' : '播放',
      child: AnimatedContainer(
        duration: AppMotion.standard,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: playing ? s.lime : s.chip,
          shape: BoxShape.circle,
        ),
        child: Icon(
          playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
          size: size * 0.5,
          color: playing ? s.onLime : context.colors.onSurface,
        ),
      ),
    );
  }
}

// --------------------------------------------------------------------- rows

/// "Cover + title + By X • N songs + trailing" row from the reference design.
///
/// Used for playlists, albums, artists and songs alike. Hover tints the row,
/// press scales it, [highlighted] fades a lime-tinted wash in.
class MediaRow extends StatelessWidget {
  const MediaRow({
    super.key,
    required this.title,
    this.subtitle,
    this.meta,
    this.coverUrl,
    this.leading,
    this.trailing,
    this.onTap,
    this.onLongPress,
    this.onSecondaryTap,
    this.highlighted = false,
    this.circleCover = false,
    this.coverSize = 58,
    this.badges = const [],
  });

  final String title;

  /// Rendered before the dot, e.g. "By Alexiao".
  final String? subtitle;

  /// Rendered after the dot, e.g. "24 首".
  final String? meta;
  final String? coverUrl;

  /// Replaces the cover entirely (track number, icon ...).
  final Widget? leading;
  final Widget? trailing;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onSecondaryTap;
  final bool highlighted;

  /// Artists render with a round cover.
  final bool circleCover;
  final double coverSize;

  /// Small inline tags after the title (VIP, SQ ...).
  final List<Widget> badges;

  @override
  Widget build(BuildContext context) {
    final cover =
        leading ??
        CoverImage(
          url: coverUrl,
          size: (coverSize * 3).round(),
          width: coverSize,
          height: coverSize,
          radius: circleCover ? coverSize / 2 : AppMetrics.radiusSm + 2,
        );
    return _HoverWash(
      highlighted: highlighted,
      child: Pressable(
        onTap: onTap,
        onLongPress: onLongPress,
        onSecondaryTap: onSecondaryTap,
        pressedScale: 0.98,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          child: Row(
            children: [
              cover,
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: AnimatedDefaultTextStyle(
                            duration: AppMotion.quick,
                            style: context.text.titleSmall!.copyWith(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w500,
                              color: highlighted
                                  ? context.colors.primary
                                  : context.colors.onSurface,
                            ),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ),
                        for (final badge in badges) ...[
                          const SizedBox(width: 6),
                          badge,
                        ],
                      ],
                    ),
                    if (subtitle != null || meta != null) ...[
                      const SizedBox(height: 5),
                      DotSeparated(parts: [?subtitle, ?meta]),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[const SizedBox(width: 12), trailing!],
            ],
          ),
        ),
      ),
    );
  }
}

/// `By Alexiao  •  24 Songs` secondary line.
class DotSeparated extends StatelessWidget {
  const DotSeparated({super.key, required this.parts, this.style});

  final List<String> parts;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final textStyle =
        style ??
        context.text.bodySmall?.copyWith(
          color: s.textSecondary,
          fontSize: 12.5,
        );
    final visible = parts.where((part) => part.isNotEmpty).toList();
    return Text.rich(
      TextSpan(
        children: [
          for (var i = 0; i < visible.length; i++) ...[
            if (i > 0)
              TextSpan(
                text: '  •  ',
                style: textStyle?.copyWith(color: s.textTertiary, fontSize: 9),
              ),
            TextSpan(text: visible[i]),
          ],
        ],
      ),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: textStyle,
    );
  }
}

class _HoverWash extends StatefulWidget {
  const _HoverWash({required this.child, required this.highlighted});

  final Widget child;
  final bool highlighted;

  @override
  State<_HoverWash> createState() => _HoverWashState();
}

class _HoverWashState extends State<_HoverWash> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final color = widget.highlighted
        ? s.lime.withValues(alpha: context.isDark ? 0.10 : 0.16)
        : s.cardHover.withValues(alpha: _hovering ? null : 0);
    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.enter,
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        ),
        child: widget.child,
      ),
    );
  }
}

/// Small rounded tag (VIP / SQ / 试听 / 无版权).
class TagBadge extends StatelessWidget {
  const TagBadge(this.label, {super.key, this.color});

  final String label;
  final Color? color;

  /// Text style of a tag label; shared with `SongBadge.measureWidth`.
  static const TextStyle textStyle = TextStyle(
    fontSize: 9.5,
    fontWeight: FontWeight.w700,
    height: 1.25,
  );

  /// Horizontal padding plus border of one tag.
  static const double horizontalInset = 6 * 2 + 0.8 * 2;

  @override
  Widget build(BuildContext context) {
    final tint = color ?? context.colors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1.5),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(6),
        border: Border.all(color: tint.withValues(alpha: 0.55), width: 0.8),
      ),
      child: Text(
        label,
        maxLines: 1,
        softWrap: false,
        overflow: TextOverflow.clip,
        style: textStyle.copyWith(color: tint),
      ),
    );
  }
}

// ------------------------------------------------------------------ headers

/// Section title with an optional "See all" action.
class SectionTitle extends StatelessWidget {
  const SectionTitle({
    super.key,
    required this.title,
    this.actionLabel = '查看全部',
    this.onAction,
    this.subtitle,
    this.padding = const EdgeInsets.fromLTRB(
      AppMetrics.gutter,
      28,
      AppMetrics.gutter,
      14,
    ),
  });

  final String title;
  final String? subtitle;
  final String actionLabel;
  final VoidCallback? onAction;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleLarge?.copyWith(
                    fontSize: 22,
                    fontWeight: FontWeight.w500,
                    letterSpacing: -0.4,
                  ),
                ),
                if (subtitle != null) ...[
                  const SizedBox(height: 3),
                  Text(
                    subtitle!,
                    style: context.text.bodySmall?.copyWith(
                      color: context.surfaces.textTertiary,
                    ),
                  ),
                ],
              ],
            ),
          ),
          if (onAction != null)
            Pressable(
              onTap: onAction,
              child: Padding(
                padding: const EdgeInsets.only(left: 12, bottom: 2),
                child: Text(
                  actionLabel,
                  style: context.text.bodyMedium?.copyWith(
                    color: context.surfaces.textSecondary,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// "( ← )   My Music   ( ⋯ )" header used by detail and secondary pages.
class PageHeader extends StatelessWidget {
  const PageHeader({
    super.key,
    required this.title,
    this.onBack,
    this.actions = const [],
    this.padding = const EdgeInsets.fromLTRB(
      AppMetrics.gutter,
      12,
      AppMetrics.gutter,
      8,
    ),
    this.translucent = false,
  });

  final String title;

  /// Defaults to `Navigator.maybePop`. Pass `null` explicitly via [showBack].
  final VoidCallback? onBack;
  final List<Widget> actions;
  final EdgeInsetsGeometry padding;

  /// Use a glass fill for the buttons (when drawn over artwork).
  final bool translucent;

  @override
  Widget build(BuildContext context) {
    final canPop = Navigator.of(context).canPop();
    final buttonColor = translucent
        ? Colors.white.withValues(alpha: 0.16)
        : null;
    return Padding(
      padding: padding,
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            if (onBack != null || canPop)
              RoundIconButton(
                icon: Icons.arrow_back_rounded,
                tooltip: '返回',
                color: buttonColor,
                onPressed: onBack ?? () => Navigator.of(context).maybePop(),
              )
            else
              const SizedBox(width: 46),
            Expanded(
              child: Text(
                title,
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.titleMedium?.copyWith(
                  fontSize: 18,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            if (actions.isEmpty) const SizedBox(width: 46),
            for (final action in actions) ...[const SizedBox(width: 8), action],
          ],
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- glass

/// Frosted, rounded container for floating bars and overlays.
class GlassPanel extends StatelessWidget {
  const GlassPanel({
    super.key,
    required this.child,
    this.radius = AppMetrics.radiusPill,
    this.padding = EdgeInsets.zero,
    this.blur = 24,
    this.color,
  });

  final Widget child;
  final double radius;
  final EdgeInsetsGeometry padding;
  final double blur;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: context.isDark ? 0.45 : 0.12),
            blurRadius: 30,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: BackdropFilter(
          filter: ui.ImageFilter.blur(sigmaX: blur, sigmaY: blur),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: color ?? s.glass,
              borderRadius: BorderRadius.circular(radius),
              border: Border.all(
                color: Colors.white.withValues(
                  alpha: context.isDark ? 0.08 : 0.5,
                ),
              ),
            ),
            child: Padding(padding: padding, child: child),
          ),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- backdrop

/// Soft, slowly drifting colour glows behind a page (the pink/purple haze at
/// the top-left of the reference home screen).
///
/// Cheap: three radial gradients painted on one layer, repainted by a 12 s
/// looping controller. Pass [colors] to tint it with the album accent.
class AmbientBackdrop extends StatefulWidget {
  const AmbientBackdrop({
    super.key,
    this.colors,
    this.intensity = 1,
    this.height,
    this.animate = true,
  });

  final List<Color>? colors;
  final double intensity;

  /// Limits the glow to the top part of the page; `null` fills the parent.
  final double? height;
  final bool animate;

  @override
  State<AmbientBackdrop> createState() => _AmbientBackdropState();
}

class _AmbientBackdropState extends State<AmbientBackdrop>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(seconds: 12),
  );

  @override
  void initState() {
    super.initState();
    if (widget.animate) _controller.repeat();
  }

  @override
  void didUpdateWidget(AmbientBackdrop oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.animate && !_controller.isAnimating) _controller.repeat();
    if (!widget.animate && _controller.isAnimating) _controller.stop();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colors = widget.colors ?? context.surfaces.brandGradient;
    final painter = TweenAnimationBuilder<double>(
      tween: Tween(end: widget.intensity),
      duration: AppMotion.emphasized,
      builder: (context, intensity, _) => RepaintBoundary(
        child: CustomPaint(
          painter: _AmbientPainter(
            animation: _controller,
            colors: colors,
            intensity: intensity * (context.isDark ? 1 : 0.55),
          ),
          size: Size.infinite,
        ),
      ),
    );
    return IgnorePointer(
      child: widget.height == null
          ? SizedBox.expand(child: painter)
          : SizedBox(
              height: widget.height,
              width: double.infinity,
              child: painter,
            ),
    );
  }
}

class _AmbientPainter extends CustomPainter {
  _AmbientPainter({
    required this.animation,
    required this.colors,
    required this.intensity,
  }) : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;
  final double intensity;

  @override
  void paint(Canvas canvas, Size size) {
    if (size.isEmpty || colors.isEmpty) return;
    final t = animation.value * 2 * math.pi;
    final shortest = size.shortestSide;
    final blobs = [
      (
        Offset(
          size.width * (0.12 + 0.05 * math.sin(t)),
          size.height * (0.08 + 0.04 * math.cos(t)),
        ),
        0.95,
      ),
      (
        Offset(
          size.width * (0.42 + 0.06 * math.cos(t * 0.8)),
          size.height * (-0.02 + 0.05 * math.sin(t * 1.2)),
        ),
        0.7,
      ),
      (
        Offset(
          size.width * (0.05 + 0.04 * math.sin(t * 1.3 + 1)),
          size.height * (0.35 + 0.05 * math.cos(t)),
        ),
        0.6,
      ),
    ];
    for (var i = 0; i < blobs.length; i++) {
      final (center, scale) = blobs[i];
      final color = colors[i % colors.length];
      final radius = math.max(shortest, 320.0) * 0.75 * scale;
      final paint = Paint()
        ..shader = RadialGradient(
          colors: [
            color.withValues(alpha: 0.55 * intensity),
            color.withValues(alpha: 0.18 * intensity),
            color.withValues(alpha: 0),
          ],
          stops: const [0, 0.45, 1],
        ).createShader(Rect.fromCircle(center: center, radius: radius));
      canvas.drawCircle(center, radius, paint);
    }
  }

  @override
  bool shouldRepaint(_AmbientPainter oldDelegate) =>
      oldDelegate.colors != colors || oldDelegate.intensity != intensity;
}

// ----------------------------------------------------------------- skeleton

/// Shimmering placeholder block shown while content loads.
class Skeleton extends StatefulWidget {
  const Skeleton({
    super.key,
    this.width,
    this.height = 16,
    this.radius = AppMetrics.radiusSm,
  });

  final double? width;
  final double height;
  final double radius;

  @override
  State<Skeleton> createState() => _SkeletonState();
}

class _SkeletonState extends State<Skeleton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final base = context.surfaces.chip;
    final shine = Color.lerp(base, Colors.white, context.isDark ? 0.07 : 0.5)!;
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        final x = _controller.value * 3 - 1;
        return Container(
          width: widget.width,
          height: widget.height,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(widget.radius),
            gradient: LinearGradient(
              begin: Alignment(x - 1, 0),
              end: Alignment(x + 1, 0),
              colors: [base, shine, base],
            ),
          ),
        );
      },
    );
  }
}

/// A column of [MediaRow]-shaped skeletons.
class MediaRowSkeletonList extends StatelessWidget {
  const MediaRowSkeletonList({
    super.key,
    this.count = 6,
    this.padding = EdgeInsets.zero,
  });

  final int count;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: padding,
      child: Column(
        children: [
          for (var i = 0; i < count; i++)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              child: Row(
                children: [
                  Skeleton(
                    width: 58,
                    height: 58,
                    radius: AppMetrics.radiusSm + 2,
                  ),
                  SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Skeleton(width: 180, height: 14),
                        SizedBox(height: 8),
                        Skeleton(width: 110, height: 11),
                      ],
                    ),
                  ),
                  Skeleton(width: 38, height: 38, radius: 19),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
