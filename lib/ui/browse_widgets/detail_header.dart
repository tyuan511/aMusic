import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../shell.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import 'layout.dart';
import 'sheets.dart';

/// Height of [CollapsingHeaderBar] below the status bar.
const double kHeaderBarHeight = 64;

/// Gap kept between the window edge and the floating header bar when the
/// platform reports no top inset. Desktop windows draw their own title bar, so
/// `MediaQuery.padding.top` is 0 and the round buttons would hug the very top.
const double kHeaderBarTopGap = 12;

/// Top inset the header bar (and the hero under it) must clear: the system
/// status bar when there is one, otherwise [kHeaderBarTopGap].
double headerBarTopInset(BuildContext context) {
  final top = MediaQuery.paddingOf(context).top;
  return top > 0 ? top : kHeaderBarTopGap;
}

/// 0 → 1 as [offset] scrolls through the last [band] px before [threshold].
double collapseProgress(double offset, double threshold, {double band = 64}) =>
    ((offset - (threshold - band)) / band).clamp(0.0, 1.0);

/// Top bar of detail pages on a solid background: back button, a compact
/// title that fades in once the hero scrolled away, and actions. Rebuilds only
/// itself on scroll.
class CollapsingHeaderBar extends StatelessWidget {
  const CollapsingHeaderBar({
    super.key,
    required this.controller,
    required this.title,
    this.actions = const [],
    this.threshold = 260,
  });

  final ScrollController controller;
  final String title;
  final List<Widget> actions;

  /// Scroll offset at which the title is fully visible.
  final double threshold;

  @override
  Widget build(BuildContext context) {
    final top = headerBarTopInset(context);
    final s = context.surfaces;
    final canPop = Navigator.of(context).canPop();
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        final offset = controller.hasClients ? controller.offset : 0.0;
        final t = collapseProgress(offset, threshold);
        return DecoratedBox(
          decoration: BoxDecoration(
            // Transparent over the hero backdrop, solid once content scrolls
            // under the bar.
            color: context.scaffoldBackground.withValues(alpha: t),
            border: Border(
              bottom: BorderSide(
                color: s.hairline.withValues(alpha: s.hairline.a * t),
              ),
            ),
          ),
          child: Padding(
            padding: EdgeInsets.only(top: top),
            child: SizedBox(
              height: kHeaderBarHeight,
              child: ContentBox(
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppMetrics.gutter,
                  ),
                  child: Row(
                    children: [
                      if (canPop)
                        RoundIconButton(
                          icon: Icons.arrow_back_rounded,
                          tooltip: '返回',
                          size: 42,
                          color: s.chip,
                          onPressed: () => Navigator.of(context).maybePop(),
                        ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Opacity(
                          opacity: t,
                          child: Transform.translate(
                            offset: Offset(0, 8 * (1 - t)),
                            child: Text(
                              title,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ),
                      ),
                      for (final action in actions) ...[
                        const SizedBox(width: 8),
                        action,
                      ],
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Big rounded cover that scales and fades in once.
class HeroCover extends StatelessWidget {
  const HeroCover({
    super.key,
    required this.url,
    required this.size,
    this.circle = false,
  });

  final String? url;
  final double size;
  final bool circle;

  @override
  Widget build(BuildContext context) {
    final radius = circle ? size / 2 : AppMetrics.radiusLg;
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: AppMotion.page,
      curve: AppMotion.enter,
      builder: (context, t, child) => Opacity(
        opacity: t.clamp(0.0, 1.0),
        child: Transform.scale(scale: 0.86 + 0.14 * t, child: child),
      ),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(radius),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.4),
              blurRadius: 36,
              offset: const Offset(0, 16),
            ),
          ],
        ),
        child: CoverImage(
          url: url,
          size: (size * 2.2).round(),
          width: size,
          height: size,
          radius: radius,
        ),
      ),
    );
  }
}

/// Header block of playlist / album / artist pages: blurred backdrop,
/// cover, eyebrow, title, subtitle, stats, description and actions.
///
/// Stacks vertically and centred on phones, side by side on wide layouts.
class DetailHero extends StatelessWidget {
  const DetailHero({
    super.key,
    required this.title,
    required this.coverUrl,
    this.eyebrow,
    this.subtitle,
    this.stats = const [],
    this.description,
    this.actions,
    this.circleCover = false,
    this.below,
  });

  final String title;
  final String? coverUrl;
  final String? eyebrow;
  final Widget? subtitle;
  final List<String> stats;
  final String? description;
  final Widget? actions;
  final bool circleCover;

  /// Extra content under the actions (tags ...).
  final Widget? below;

  /// Below this content width the hero stacks vertically.
  static const double stackBelow = 640;

  @override
  Widget build(BuildContext context) {
    final top = headerBarTopInset(context) + kHeaderBarHeight;
    return Stack(
      children: [
        Positioned.fill(child: _HeroBackdrop(url: coverUrl)),
        ContentBox(
          padding: EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            top + 8,
            AppMetrics.gutter,
            8,
          ),
          child: LayoutBuilder(
            builder: (context, constraints) {
              final compact = constraints.maxWidth < stackBelow;
              return DetailHeroScope(
                compact: compact,
                child: _layout(context, compact, constraints.maxWidth),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _layout(BuildContext context, bool compact, double width) {
    final coverSize = compact ? (width * 0.62).clamp(150.0, 240.0) : 232.0;
    final s = context.surfaces;
    final texts = <Widget>[
      if (eyebrow != null)
        Text(
          eyebrow!,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.labelMedium?.copyWith(
            color: s.lime,
            letterSpacing: 1.2,
            fontWeight: FontWeight.w600,
          ),
        ),
      if (eyebrow != null) const SizedBox(height: 8),
      Text(
        title,
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        textAlign: compact ? TextAlign.center : TextAlign.start,
        style: context.text.headlineMedium?.copyWith(
          fontSize: compact ? 24 : 34,
          height: 1.18,
          fontWeight: FontWeight.w500,
          letterSpacing: -0.6,
        ),
      ),
      if (subtitle != null) ...[const SizedBox(height: 12), subtitle!],
      if (stats.isNotEmpty) ...[
        const SizedBox(height: 10),
        DotSeparated(parts: stats),
      ],
      if (description != null && description!.trim().isNotEmpty) ...[
        const SizedBox(height: 12),
        ExpandableDescription(
          text: description!.trim(),
          title: title,
          centered: compact,
        ),
      ],
      if (actions != null) ...[const SizedBox(height: 18), actions!],
      if (below != null) ...[const SizedBox(height: 14), below!],
    ];
    if (compact) {
      return Column(
        children: [
          HeroCover(url: coverUrl, size: coverSize, circle: circleCover),
          const SizedBox(height: 22),
          ...texts,
        ],
      );
    }
    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        HeroCover(url: coverUrl, size: coverSize, circle: circleCover),
        const SizedBox(width: 30),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: texts,
          ),
        ),
      ],
    );
  }
}

/// Blurred cover that tints the top of a detail page and fades into the page
/// background towards the bottom.
///
/// Only a tiny version of the cover is decoded. Normally it is blurred once
/// (the layer is cached, scrolling does not re-run the filter); in low
/// performance mode the blur filter is skipped and the upscaled thumbnail,
/// which is soft by itself, stands in for it.
class _HeroBackdrop extends StatelessWidget {
  const _HeroBackdrop({required this.url});

  final String? url;

  @override
  Widget build(BuildContext context) {
    final provider = CoverImage.providerFor(
      url,
      size: context.lowPerformance ? 16 : 96,
    );
    if (provider == null) return const SizedBox.shrink();
    final background = context.scaffoldBackground;
    Widget image = Image(
      image: provider,
      fit: BoxFit.cover,
      filterQuality: FilterQuality.medium,
      gaplessPlayback: true,
      errorBuilder: (context, error, _) => const SizedBox.shrink(),
    );
    if (!context.lowPerformance) {
      image = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: 36,
          sigmaY: 36,
          tileMode: TileMode.clamp,
        ),
        child: image,
      );
    }
    return IgnorePointer(
      child: RepaintBoundary(
        child: ClipRect(
          child: Stack(
            fit: StackFit.expand,
            children: [
              Opacity(opacity: context.isDark ? 0.5 : 0.62, child: image),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      background.withValues(alpha: 0),
                      background.withValues(alpha: 0.55),
                      background,
                    ],
                    stops: const [0, 0.55, 1],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Tells hero content (actions, tags, links) whether the hero is stacked
/// and centred.
class DetailHeroScope extends InheritedWidget {
  const DetailHeroScope({
    super.key,
    required this.compact,
    required super.child,
  });

  final bool compact;

  /// Stacked layout of the enclosing hero (falls back to the shell layout).
  static bool compactOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DetailHeroScope>()?.compact ??
      ShellLayout.compactOf(context);

  @override
  bool updateShouldNotify(DetailHeroScope oldWidget) =>
      compact != oldWidget.compact;
}

/// Two lines of description; tapping opens the full text in a sheet.
class ExpandableDescription extends StatelessWidget {
  const ExpandableDescription({
    super.key,
    required this.text,
    this.title,
    this.centered = false,
    this.maxLines = 2,
  });

  final String text;
  final String? title;
  final bool centered;
  final int maxLines;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      pressedScale: 0.98,
      onTap: () => showTextSheet(context, title: title ?? '简介', text: text),
      semanticLabel: '查看完整简介',
      child: Column(
        crossAxisAlignment: centered
            ? CrossAxisAlignment.center
            : CrossAxisAlignment.start,
        children: [
          Text(
            text.replaceAll(RegExp(r'\s+'), ' '),
            maxLines: maxLines,
            overflow: TextOverflow.ellipsis,
            textAlign: centered ? TextAlign.center : TextAlign.start,
            style: context.text.bodySmall?.copyWith(
              color: s.textSecondary,
              height: 1.5,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '更多',
            style: context.text.labelSmall?.copyWith(color: s.textTertiary),
          ),
        ],
      ),
    );
  }
}

/// Scrollable sheet with selectable long text (descriptions, biographies).
Future<void> showTextSheet(
  BuildContext context, {
  required String title,
  required String text,
}) {
  return showAppSheet<void>(
    context,
    isScrollControlled: true,
    builder: (context) => FractionallySizedBox(
      heightFactor: 0.7,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
        children: [
          Text(
            title,
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 16),
          SelectableText(
            text,
            style: context.text.bodyMedium?.copyWith(height: 1.7),
          ),
        ],
      ),
    ),
  );
}

/// Wrap of round action buttons after the primary pill; centred on phones.
class DetailActions extends StatelessWidget {
  const DetailActions({
    super.key,
    required this.primary,
    this.secondary = const [],
  });

  final Widget primary;
  final List<Widget> secondary;

  @override
  Widget build(BuildContext context) {
    final compact = DetailHeroScope.compactOf(context);
    return Wrap(
      alignment: compact ? WrapAlignment.center : WrapAlignment.start,
      crossAxisAlignment: WrapCrossAlignment.center,
      spacing: 10,
      runSpacing: 10,
      children: [primary, ...secondary],
    );
  }
}
