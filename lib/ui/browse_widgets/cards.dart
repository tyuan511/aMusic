import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../login/login_dialog.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
export 'buttons.dart';

/// Square cover card for grids and shelves (playlists, albums, toplists).
///
/// Rounded 18, lifts on hover, cover zooms slightly and a lime play button
/// slides in. [onPlay] defaults to opening the item.
class CoverCard extends StatelessWidget {
  const CoverCard({
    super.key,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.coverUrl,
    this.onPlay,
    this.topLeft,
    this.topRight,
    this.circle = false,
    this.playButton,
  });

  /// Height of the two text lines below the cover.
  static const double textAreaHeight = 56;

  /// Height a card needs for a column of [width].
  static double heightFor(double width) => width + textAreaHeight;

  final String title;
  final String? subtitle;
  final String? coverUrl;
  final VoidCallback onTap;
  final VoidCallback? onPlay;
  final Widget? topLeft;
  final Widget? topRight;

  /// Artist cards render a round cover and centred text.
  final bool circle;

  /// Replaces the hover-only play glyph (e.g. a [CollectionPlayButton]).
  final Widget? playButton;

  @override
  Widget build(BuildContext context) {
    const radius = AppMetrics.radiusMd;
    return HoverLift(
      onTap: onTap,
      radius: circle ? 999 : radius,
      lift: 5,
      builder: (context, hovering) => Column(
        crossAxisAlignment: circle
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          AspectRatio(
            aspectRatio: 1,
            child: AnimatedContainer(
              duration: AppMotion.standard,
              decoration: BoxDecoration(
                shape: circle ? BoxShape.circle : BoxShape.rectangle,
                borderRadius: circle ? null : BorderRadius.circular(radius),
                boxShadow: [
                  BoxShadow(
                    color: hovering
                        ? context.surfaces.glow
                        : Colors.black.withValues(
                            alpha: context.isDark ? 0.28 : 0.08,
                          ),
                    blurRadius: hovering ? 26 : 10,
                    spreadRadius: -5,
                    offset: Offset(0, hovering ? 14 : 5),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(circle ? 999 : radius),
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    AnimatedScale(
                      scale: hovering ? 1.06 : 1,
                      duration: AppMotion.emphasized,
                      curve: AppMotion.enter,
                      child: CoverImage(url: coverUrl, size: 360, radius: 0),
                    ),
                    if (!circle)
                      AnimatedOpacity(
                        opacity: hovering ? 1 : 0.45,
                        duration: AppMotion.standard,
                        child: const DecoratedBox(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topCenter,
                              end: Alignment.bottomCenter,
                              stops: [0.5, 1],
                              colors: [Colors.transparent, Color(0x99000000)],
                            ),
                          ),
                        ),
                      ),
                    if (topLeft != null)
                      Positioned(left: 10, top: 10, child: topLeft!),
                    if (topRight != null)
                      Positioned(right: 10, top: 10, child: topRight!),
                    if (!circle)
                      Positioned(
                        right: 10,
                        bottom: 10,
                        child:
                            playButton ??
                            AnimatedSlide(
                              offset: hovering
                                  ? Offset.zero
                                  : const Offset(0, 0.5),
                              duration: AppMotion.standard,
                              curve: AppMotion.pop,
                              child: AnimatedOpacity(
                                opacity: hovering ? 1 : 0,
                                duration: AppMotion.quick,
                                child: Pressable(
                                  onTap: onPlay ?? onTap,
                                  child: const GradientPlayButton(size: 40),
                                ),
                              ),
                            ),
                      ),
                  ],
                ),
              ),
            ),
          ),
          SizedBox(
            height: textAreaHeight,
            child: Padding(
              padding: const EdgeInsets.only(top: 10, left: 2, right: 2),
              child: Column(
                crossAxisAlignment: circle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  AnimatedDefaultTextStyle(
                    duration: AppMotion.quick,
                    style: context.text.bodyMedium!.copyWith(
                      fontWeight: FontWeight.w500,
                      fontSize: 14,
                      color: hovering
                          ? context.colors.primary
                          : context.colors.onSurface,
                    ),
                    child: Text(
                      title.isEmpty ? '未命名' : title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      textAlign: circle ? TextAlign.center : TextAlign.start,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...[
                    const SizedBox(height: 3),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        fontSize: 12,
                        color: context.surfaces.textTertiary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Fixed-extent responsive grid of [CoverCard]-shaped items as a sliver.
class SliverCoverGrid extends StatelessWidget {
  const SliverCoverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxItemWidth = 190,
    this.spacing = 16,
    this.minColumns = 2,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double maxItemWidth;
  final double spacing;
  final int minColumns;

  @override
  Widget build(BuildContext context) {
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.crossAxisExtent;
        final columns = (width / maxItemWidth).ceil().clamp(minColumns, 8);
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: CoverCard.heightFor(itemWidth),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => RepaintBoundary(
            child: EntranceFade(
              index: index,
              child: itemBuilder(context, index),
            ),
          ),
        );
      },
    );
  }
}

/// Box (non-sliver) grid for short collections inside a column.
class CoverGrid extends StatelessWidget {
  const CoverGrid({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.maxItemWidth = 190,
    this.spacing = 16,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double maxItemWidth;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / maxItemWidth).ceil().clamp(2, 8);
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return GridView.builder(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: CoverCard.heightFor(itemWidth),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: itemCount,
          itemBuilder: (context, index) => RepaintBoundary(
            child: EntranceFade(
              index: index,
              child: itemBuilder(context, index),
            ),
          ),
        );
      },
    );
  }
}

/// Rounded charcoal card inviting a guest to sign in.
class SignInCard extends StatelessWidget {
  const SignInCard({
    super.key,
    this.title = '登录网易云音乐',
    this.message = '同步歌单、红心歌曲与每日推荐',
    this.padding = const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
  });

  final String title;
  final String message;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: padding,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
          border: Border.all(color: s.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: s.lavender.withValues(alpha: 0.18),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.person_rounded, color: s.lavender, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    message,
                    style: context.text.bodySmall?.copyWith(
                      color: s.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            FilledButton(
              onPressed: () => showLoginDialog(context),
              child: const Text('登录'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Summary card that links to another screen (本地音乐 / 下载 / 最近播放).
class EntryCard extends StatelessWidget {
  const EntryCard({
    super.key,
    required this.icon,
    required this.title,
    required this.onTap,
    this.subtitle,
    this.tint,
  });

  final IconData icon;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Color? tint;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final color = tint ?? s.lime;
    return HoverLift(
      onTap: onTap,
      radius: AppMetrics.radiusLg,
      lift: 3,
      builder: (context, hovering) => AnimatedContainer(
        duration: AppMotion.standard,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: hovering ? s.cardHover : s.card,
          borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
          border: Border.all(color: s.hairline),
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.16),
                borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
              ),
              child: Icon(icon, color: color, size: 26),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    title,
                    style: context.text.titleMedium?.copyWith(
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  if (subtitle != null) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle!,
                      style: context.text.bodySmall?.copyWith(
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            AnimatedSlide(
              offset: hovering ? const Offset(0.15, 0) : Offset.zero,
              duration: AppMotion.standard,
              child: Icon(Icons.chevron_right_rounded, color: s.textTertiary),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small rounded "12.3万" play-count pill over covers.
class PlayCountPill extends StatelessWidget {
  const PlayCountPill(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.42),
        borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(Icons.play_arrow_rounded, size: 12, color: Colors.white),
          const SizedBox(width: 2),
          Text(
            text,
            style: const TextStyle(
              color: Colors.white,
              fontSize: 10.5,
              fontWeight: FontWeight.w600,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}
