import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/format.dart';
import '../../data/net_image.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../login/login_dialog.dart';
import 'kit.dart';

class NavDestination {
  const NavDestination(this.label, this.icon, this.selectedIcon, this.location);

  final String label;
  final IconData icon;
  final IconData selectedIcon;
  final String location;
}

/// Shell destinations, in branch order (must match `shellDestinations`).
const List<NavDestination> navDestinations = [
  NavDestination('首页', Icons.home_outlined, Icons.home_rounded, '/home'),
  NavDestination(
    '排行榜',
    Icons.leaderboard_outlined,
    Icons.leaderboard_rounded,
    '/charts',
  ),
  NavDestination(
    '搜索',
    Icons.search_rounded,
    Icons.manage_search_rounded,
    '/search',
  ),
  NavDestination(
    '我的音乐',
    Icons.library_music_outlined,
    Icons.library_music_rounded,
    '/library',
  ),
  NavDestination(
    '设置',
    Icons.settings_outlined,
    Icons.settings_rounded,
    '/settings',
  ),
];

/// Desktop / tablet sidebar. Collapses to icons when the window is narrow.
class Sidebar extends StatelessWidget {
  const Sidebar({
    super.key,
    required this.expanded,
    required this.selectedIndex,
    required this.onDestinationSelected,
  });

  static const double _itemHeight = 48;
  static const double _itemGap = 6;

  final bool expanded;
  final int selectedIndex;
  final ValueChanged<int> onDestinationSelected;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return AnimatedContainer(
      duration: AppMotion.emphasized,
      curve: AppMotion.enter,
      width: expanded ? 236 : 84,
      decoration: BoxDecoration(
        color: s.sidebar,
        border: Border(right: BorderSide(color: s.hairline)),
      ),
      child: Stack(
        children: [
          // The same ambient haze as the home header, so the sidebar and the
          // page read as one surface.
          const Positioned(
            left: 0,
            right: 0,
            top: 0,
            child: AmbientBackdrop(height: 260, intensity: 0.45),
          ),
          Column(
            children: [
              SizedBox(height: MediaQuery.paddingOf(context).top + 18),
              _Brand(expanded: expanded),
              const SizedBox(height: 28),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 14),
                child: SizedBox(
                  height: navDestinations.length * (_itemHeight + _itemGap),
                  child: Stack(
                    children: [
                      // Selection pill slides between items.
                      AnimatedPositioned(
                        duration: AppMotion.emphasized,
                        curve: AppMotion.enter,
                        top: selectedIndex * (_itemHeight + _itemGap),
                        left: 0,
                        right: 0,
                        height: _itemHeight,
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: s.lime,
                            borderRadius: BorderRadius.circular(
                              AppMetrics.radiusPill,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: s.glow,
                                blurRadius: 18,
                                offset: const Offset(0, 6),
                              ),
                            ],
                          ),
                        ),
                      ),
                      Column(
                        children: [
                          for (var i = 0; i < navDestinations.length; i++)
                            Padding(
                              padding: const EdgeInsets.only(bottom: _itemGap),
                              child: _NavItem(
                                destination: navDestinations[i],
                                selected: i == selectedIndex,
                                expanded: expanded,
                                height: _itemHeight,
                                onTap: () => onDestinationSelected(i),
                              ),
                            ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const Spacer(),
              _UserCard(expanded: expanded),
              const SizedBox(height: 14),
            ],
          ),
        ],
      ),
    );
  }
}

class _Brand extends StatelessWidget {
  const _Brand({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final logo = Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: s.lime,
        shape: BoxShape.circle,
        boxShadow: [
          BoxShadow(color: s.glow, blurRadius: 16, offset: const Offset(0, 5)),
        ],
      ),
      child: Icon(Icons.graphic_eq_rounded, color: s.onLime, size: 22),
    );
    if (!expanded) return Center(child: logo);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Row(
        children: [
          logo,
          const SizedBox(width: 12),
          Text(
            'aMusic',
            style: context.text.titleLarge?.copyWith(
              fontWeight: FontWeight.w700,
              letterSpacing: -0.6,
            ),
          ),
        ],
      ),
    );
  }
}

class _NavItem extends StatefulWidget {
  const _NavItem({
    required this.destination,
    required this.selected,
    required this.expanded,
    required this.height,
    required this.onTap,
  });

  final NavDestination destination;
  final bool selected;
  final bool expanded;
  final double height;
  final VoidCallback onTap;

  @override
  State<_NavItem> createState() => _NavItemState();
}

class _NavItemState extends State<_NavItem> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final selected = widget.selected;
    final foreground = selected
        ? s.onLime
        : (_hovering ? context.colors.onSurface : s.textSecondary);

    final content = AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      height: widget.height,
      padding: EdgeInsets.symmetric(horizontal: widget.expanded ? 18 : 0),
      decoration: BoxDecoration(
        color: !selected && _hovering ? s.chip : Colors.transparent,
        borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
      ),
      child: Row(
        mainAxisAlignment: widget.expanded
            ? MainAxisAlignment.start
            : MainAxisAlignment.center,
        children: [
          AnimatedScale(
            scale: selected ? 1.08 : 1,
            duration: AppMotion.standard,
            curve: AppMotion.pop,
            child: TweenAnimationBuilder<Color?>(
              tween: ColorTween(end: foreground),
              duration: AppMotion.standard,
              builder: (context, color, _) => Icon(
                selected
                    ? widget.destination.selectedIcon
                    : widget.destination.icon,
                size: 22,
                color: color,
              ),
            ),
          ),
          if (widget.expanded) ...[
            const SizedBox(width: 14),
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.standard,
                style: context.text.bodyLarge!.copyWith(
                  color: foreground,
                  fontWeight: selected ? FontWeight.w700 : FontWeight.w500,
                ),
                child: Text(
                  widget.destination.label,
                  maxLines: 1,
                  overflow: TextOverflow.fade,
                ),
              ),
            ),
          ],
        ],
      ),
    );

    return MouseRegion(
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: Tooltip(
        message: widget.expanded ? '' : widget.destination.label,
        child: Pressable(
          onTap: widget.onTap,
          pressedScale: 0.96,
          semanticLabel: widget.destination.label,
          child: content,
        ),
      ),
    );
  }
}

class _UserCard extends StatelessWidget {
  const _UserCard({required this.expanded});

  final bool expanded;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder(
      valueListenable: app.session,
      builder: (context, session, _) {
        final profile = session.profile;
        final avatar = CircleAvatar(
          radius: 19,
          backgroundColor: s.chip,
          backgroundImage: (profile?.avatarUrl ?? '').isEmpty
              ? null
              : NetImage(sizedImage(profile!.avatarUrl, size: 96)),
          child: profile == null
              ? Icon(Icons.person_rounded, size: 20, color: s.textSecondary)
              : null,
        );
        void onTap() {
          if (profile == null) {
            showLoginDialog(context);
          } else {
            context.go('/settings');
          }
        }

        final card = Pressable(
          onTap: onTap,
          pressedScale: 0.97,
          semanticLabel: profile?.nickname ?? '登录',
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 12),
            padding: EdgeInsets.all(expanded ? 10 : 6),
            decoration: BoxDecoration(
              color: s.card,
              borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
              border: Border.all(color: s.hairline),
            ),
            child: expanded
                ? Row(
                    children: [
                      avatar,
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              profile?.nickname ?? '未登录',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodyMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            Text(
                              profile == null
                                  ? '扫码登录'
                                  : (profile.isVip ? '黑胶VIP' : '已登录'),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: context.text.bodySmall?.copyWith(
                                color: profile?.isVip ?? false
                                    ? s.lime
                                    : s.textTertiary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        Icons.chevron_right_rounded,
                        size: 18,
                        color: s.textTertiary,
                      ),
                    ],
                  )
                : Center(child: avatar),
          ),
        );
        return card;
      },
    );
  }
}
