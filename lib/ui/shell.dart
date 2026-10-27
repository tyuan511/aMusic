import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../core/config.dart';
import '../core/prefs.dart';
import '../services/app.dart' as services;
import '../theme/app_theme.dart';
import 'shortcuts.dart';
import 'widgets/kit.dart';
import 'widgets/mini_player.dart';
import 'widgets/sidebar.dart';

/// Layout facts the shell publishes to every page.
///
/// Pages draw edge to edge and pad their scrollable content by
/// [bottomInset] so the last row clears the floating player (and the floating
/// navigation on compact layouts).
class ShellLayout extends InheritedWidget {
  const ShellLayout({
    super.key,
    required this.compact,
    required this.bottomInset,
    required super.child,
  });

  /// Phone layout: floating bottom navigation instead of the sidebar.
  final bool compact;

  /// Space covered by floating chrome at the bottom of the page.
  final double bottomInset;

  static ShellLayout? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<ShellLayout>();

  /// Bottom padding for scrollables; 24 outside the shell (dialogs, player).
  static double bottomInsetOf(BuildContext context) =>
      maybeOf(context)?.bottomInset ?? 24;

  static bool compactOf(BuildContext context) =>
      maybeOf(context)?.compact ??
      MediaQuery.sizeOf(context).width < Breakpoints.compact;

  @override
  bool updateShouldNotify(ShellLayout oldWidget) =>
      compact != oldWidget.compact || bottomInset != oldWidget.bottomInset;
}

/// Adaptive application frame.
///
/// Wide: sidebar + content + floating player bar.
/// Compact: content edge to edge, with the floating mini player and the
/// floating glass navigation pill stacked over its bottom.
class AppShell extends StatelessWidget {
  const AppShell({super.key, required this.navigationShell});

  final StatefulNavigationShell navigationShell;

  void _select(int index) => navigationShell.goBranch(
    index,
    initialLocation: index == navigationShell.currentIndex,
  );

  @override
  Widget build(BuildContext context) {
    final body = ValueListenableBuilder(
      valueListenable: services.app.settings,
      builder: (context, settings, _) => LayoutBuilder(
        builder: (context, constraints) {
          final compact = switch (settings.layoutMode) {
            LayoutMode.desktop => false,
            LayoutMode.mobile => true,
            LayoutMode.auto => constraints.maxWidth < Breakpoints.compact,
          };
          return compact ? _compact(context) : _wide(context, constraints);
        },
      ),
    );

    // The album art accent is published here: only widgets that read it (the
    // player surfaces) rebuild when a new track starts.
    //
    // The Scaffold is what the global ScaffoldMessenger presents snack bars on.
    final themed = AccentScope(
      accent: services.app.accent,
      child: Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        resizeToAvoidBottomInset: false,
        body: body,
      ),
    );
    if (!Platforms.isDesktop) return themed;
    return Focus(
      canRequestFocus: false,
      skipTraversal: true,
      onKeyEvent: (node, event) {
        final focused = FocusManager.instance.primaryFocus?.context?.widget;
        if (focused is EditableText) return KeyEventResult.ignored;
        return handleAppShortcut(event)
            ? KeyEventResult.handled
            : KeyEventResult.ignored;
      },
      child: themed,
    );
  }

  Widget _wide(BuildContext context, BoxConstraints constraints) {
    return Row(
      children: [
        Sidebar(
          expanded: constraints.maxWidth >= Breakpoints.medium,
          selectedIndex: navigationShell.currentIndex,
          onDestinationSelected: _select,
        ),
        Expanded(
          child: ShellLayout(
            compact: false,
            bottomInset: 124,
            child: Stack(
              children: [
                Positioned.fill(child: navigationShell),
                const Positioned(
                  left: 20,
                  right: 20,
                  bottom: 18,
                  child: MiniPlayer(),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _compact(BuildContext context) {
    final bottomSafe = MediaQuery.paddingOf(context).bottom;
    return ShellLayout(
      compact: true,
      bottomInset: AppMetrics.compactBottomInset + bottomSafe,
      child: Stack(
        children: [
          Positioned.fill(child: navigationShell),
          // Fades the content out under the floating chrome so text never
          // collides with the glass.
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            height: 150 + bottomSafe,
            child: IgnorePointer(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      context.scaffoldBackground.withValues(alpha: 0),
                      context.scaffoldBackground.withValues(alpha: 0.92),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            left: 14,
            right: 14,
            bottom: 12 + bottomSafe,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const MiniPlayer(),
                const SizedBox(height: 10),
                FloatingNavBar(
                  selectedIndex: navigationShell.currentIndex,
                  onDestinationSelected: _select,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Cross-fades between shell branches while keeping every branch alive (and
/// its scroll position / back stack intact). Hidden branches are offstage with
/// tickers muted.
class ShellBranchSwitcher extends StatefulWidget {
  const ShellBranchSwitcher({
    super.key,
    required this.currentIndex,
    required this.children,
  });

  final int currentIndex;
  final List<Widget> children;

  @override
  State<ShellBranchSwitcher> createState() => _ShellBranchSwitcherState();
}

class _ShellBranchSwitcherState extends State<ShellBranchSwitcher>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: AppMotion.page,
    value: 1,
  );
  int? _previous;

  @override
  void didUpdateWidget(ShellBranchSwitcher oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.currentIndex != widget.currentIndex) {
      _previous = oldWidget.currentIndex;
      _controller.forward(from: 0).whenComplete(() {
        if (mounted) setState(() => _previous = null);
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
    final enter = CurvedAnimation(parent: _controller, curve: AppMotion.enter);
    final exit = CurvedAnimation(
      parent: _controller,
      curve: const Interval(0, 0.5),
    );
    return Stack(
      fit: StackFit.expand,
      children: [
        for (var i = 0; i < widget.children.length; i++)
          if (i == widget.currentIndex)
            FadeTransition(
              key: ValueKey('branch-$i'),
              opacity: enter,
              child: SlideTransition(
                position: Tween(
                  begin: const Offset(0, 0.025),
                  end: Offset.zero,
                ).animate(enter),
                child: widget.children[i],
              ),
            )
          else if (i == _previous)
            IgnorePointer(
              key: ValueKey('branch-$i'),
              child: FadeTransition(
                opacity: ReverseAnimation(exit),
                child: TickerMode(enabled: false, child: widget.children[i]),
              ),
            )
          else
            Offstage(
              key: ValueKey('branch-$i'),
              child: TickerMode(enabled: false, child: widget.children[i]),
            ),
      ],
    );
  }
}

/// Floating glass navigation pill. The lime disc slides to the active tab.
class FloatingNavBar extends StatelessWidget {
  const FloatingNavBar({
    super.key,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final count = navDestinations.length;
    return GlassPanel(
      padding: const EdgeInsets.all(7),
      child: SizedBox(
        height: AppMetrics.floatingNavHeight - 14,
        child: LayoutBuilder(
          builder: (context, constraints) {
            final slot = constraints.maxWidth / count;
            final disc = AppMetrics.floatingNavHeight - 14;
            return Stack(
              children: [
                AnimatedPositioned(
                  duration: AppMotion.emphasized,
                  curve: AppMotion.enter,
                  left: slot * selectedIndex + (slot - disc) / 2,
                  top: 0,
                  width: disc,
                  height: disc,
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: s.lime,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                          color: s.glow,
                          blurRadius: 18,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                  ),
                ),
                Row(
                  children: [
                    for (var i = 0; i < count; i++)
                      Expanded(
                        child: Tooltip(
                          message: navDestinations[i].label,
                          child: Pressable(
                            onTap: () {
                              HapticFeedback.selectionClick();
                              onDestinationSelected(i);
                            },
                            semanticLabel: navDestinations[i].label,
                            child: SizedBox.expand(
                              child: Center(
                                child: AnimatedScale(
                                  scale: i == selectedIndex ? 1.08 : 1,
                                  duration: AppMotion.standard,
                                  curve: AppMotion.pop,
                                  child: TweenAnimationBuilder<Color?>(
                                    tween: ColorTween(
                                      end: i == selectedIndex
                                          ? s.onLime
                                          : s.textSecondary,
                                    ),
                                    duration: AppMotion.standard,
                                    builder: (context, color, _) => Icon(
                                      i == selectedIndex
                                          ? navDestinations[i].selectedIcon
                                          : navDestinations[i].icon,
                                      size: 24,
                                      color: color,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}
