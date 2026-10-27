import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import '../shell.dart';

/// Layout helpers shared by the browsing screens.
///
/// Wide windows keep content at [kContentMaxWidth] and centre it; phones use
/// the full width. Every helper here is cheap and stateless.

/// Maximum width of page content on wide layouts.
const double kContentMaxWidth = 1180;

/// Horizontal padding needed on each side to centre [kContentMaxWidth] wide
/// content in a viewport of [width].
double contentSidePadding(double width) =>
    math.max(0, (width - kContentMaxWidth) / 2);

/// Constrains [child] to [kContentMaxWidth] and centres it.
class ContentBox extends StatelessWidget {
  const ContentBox({super.key, required this.child, this.padding});

  final Widget child;
  final EdgeInsetsGeometry? padding;

  @override
  Widget build(BuildContext context) {
    final box = Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: kContentMaxWidth),
        child: child,
      ),
    );
    return padding == null ? box : Padding(padding: padding!, child: box);
  }
}

/// Sliver version of [ContentBox]: pads [sliver] so its content is centred
/// and at most [kContentMaxWidth] wide.
class SliverContent extends StatelessWidget {
  const SliverContent({
    super.key,
    required this.sliver,
    this.horizontal = 0,
    this.top = 0,
    this.bottom = 0,
  });

  final Widget sliver;

  /// Extra gutter added to the centring padding.
  final double horizontal;
  final double top;
  final double bottom;

  @override
  Widget build(BuildContext context) {
    final side =
        contentSidePadding(MediaQuery.sizeOf(context).width) + horizontal;
    return SliverPadding(
      padding: EdgeInsets.fromLTRB(side, top, side, bottom),
      sliver: sliver,
    );
  }
}

/// Bottom padding that clears the shell's floating chrome.
double shellBottomInset(BuildContext context) =>
    ShellLayout.bottomInsetOf(context);

/// Bottom spacer that clears the floating player / navigation of the shell.
class SliverShellBottomInset extends StatelessWidget {
  const SliverShellBottomInset({super.key, this.extra = 16});

  final double extra;

  @override
  Widget build(BuildContext context) => SliverToBoxAdapter(
    child: SizedBox(height: ShellLayout.bottomInsetOf(context) + extra),
  );
}

/// Lays [children] out in `n` equal columns (n from the available width), as
/// a plain [Column] of [Row]s. For short, bounded collections only; long
/// lists use slivers.
class ResponsiveColumns extends StatelessWidget {
  const ResponsiveColumns({
    super.key,
    required this.children,
    this.minColumnWidth = 380,
    this.maxColumns = 3,
    this.spacing = 12,
    this.runSpacing = 0,
  });

  final List<Widget> children;
  final double minColumnWidth;
  final int maxColumns;
  final double spacing;
  final double runSpacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final columns = columnsFor(
          constraints.maxWidth,
          minColumnWidth: minColumnWidth,
          maxColumns: maxColumns,
        );
        if (columns == 1) return Column(children: children);
        final rows = <Widget>[];
        for (var i = 0; i < children.length; i += columns) {
          rows.add(
            Padding(
              padding: EdgeInsets.only(top: i == 0 ? 0 : runSpacing),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var c = 0; c < columns; c++) ...[
                    if (c > 0) SizedBox(width: spacing),
                    Expanded(
                      child: i + c < children.length
                          ? children[i + c]
                          : const SizedBox.shrink(),
                    ),
                  ],
                ],
              ),
            ),
          );
        }
        return Column(children: rows);
      },
    );
  }

  /// How many columns of at least [minColumnWidth] fit into [width].
  static int columnsFor(
    double width, {
    double minColumnWidth = 380,
    int maxColumns = 3,
  }) => (width / minColumnWidth).floor().clamp(1, maxColumns);
}

/// Horizontally scrolling shelf of fixed-width items, lazily built.
class HorizontalShelf extends StatelessWidget {
  const HorizontalShelf({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    required this.height,
    this.itemWidth,
    this.spacing = 14,
    this.padding = const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final double height;
  final double? itemWidth;
  final double spacing;
  final EdgeInsetsGeometry padding;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: padding,
        clipBehavior: Clip.none,
        itemCount: itemCount,
        separatorBuilder: (_, _) => SizedBox(width: spacing),
        itemBuilder: (context, index) {
          final child = EntranceItem(
            index: index,
            child: itemBuilder(context, index),
          );
          return itemWidth == null
              ? child
              : SizedBox(width: itemWidth, child: child);
        },
      ),
    );
  }
}

/// Fade + slight slide in, once, staggered by [index]. Thin wrapper around
/// `EntranceFade` with a horizontal default for shelves.
class EntranceItem extends StatelessWidget {
  const EntranceItem({super.key, required this.child, this.index = 0});

  final Widget child;
  final int index;

  @override
  Widget build(BuildContext context) => _Entrance(index: index, child: child);
}

class _Entrance extends StatefulWidget {
  const _Entrance({required this.child, required this.index});

  final Widget child;
  final int index;

  @override
  State<_Entrance> createState() => _EntranceState();
}

class _EntranceState extends State<_Entrance>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
  );
  late final Animation<double> _curve = CurvedAnimation(
    parent: _controller,
    curve: AppMotion.enter,
  );

  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    // Lazy lists rebuild items that scroll back into view; only the first
    // reveal (scroll view still at its start) plays the entrance, otherwise
    // the item would replay it every time.
    final position = Scrollable.maybeOf(context)?.position;
    final scrolled =
        position != null && position.hasPixels && position.pixels > 1;
    if (scrolled) {
      _controller.value = 1;
      return;
    }
    final delay = Duration(milliseconds: 35 * widget.index.clamp(0, 10));
    Future.delayed(delay, () {
      if (mounted) _controller.forward();
    });
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
        position: Tween(
          begin: const Offset(0.08, 0),
          end: Offset.zero,
        ).animate(_curve),
        child: widget.child,
      ),
    );
  }
}

/// Fade-through transition used by every chip-filtered content switch.
Widget fadeThroughTransition(Widget child, Animation<double> animation) {
  final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
  return FadeTransition(
    opacity: curved,
    child: SlideTransition(
      position: Tween(
        begin: const Offset(0, 0.025),
        end: Offset.zero,
      ).animate(curved),
      child: child,
    ),
  );
}

/// Top-aligned layout builder for [AnimatedSwitcher] so switching between
/// children of different heights does not jump to the centre.
Widget topStackLayout(Widget? current, List<Widget> previous) =>
    Stack(alignment: Alignment.topCenter, children: [...previous, ?current]);
