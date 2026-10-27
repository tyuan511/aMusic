import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../core/errors.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/sheets.dart';
import '../login/login_dialog.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'home_feed.dart';
import 'home_sections.dart';

/// 首页: avatar + search / liked buttons, greeting, chip bar and the
/// sections of the selected chip over a soft ambient glow.
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  HomeChip _chip = HomeChip.all;
  late HomeFeed _feed = HomeFeed(loggedIn: app.session.value.isLoggedIn);

  @override
  void initState() {
    super.initState();
    app.session.authRevision.addListener(_reload);
  }

  @override
  void dispose() {
    app.session.authRevision.removeListener(_reload);
    super.dispose();
  }

  void _reload() {
    if (!mounted) return;
    setState(() => _feed = HomeFeed(loggedIn: app.session.value.isLoggedIn));
  }

  Future<void> _refresh() async {
    app.library.clearCaches();
    _reload();
    await Future.wait([
      _feed.discover.then<void>((_) {}, onError: (Object _) {}),
      app.library.refreshLikedIds(),
    ]);
  }

  void _selectChip(HomeChip chip) {
    if (chip == HomeChip.charts && _chip == HomeChip.charts) {
      context.go('/charts');
      return;
    }
    setState(() => _chip = chip);
  }

  Widget _content() {
    switch (_chip) {
      case HomeChip.all:
        return HomeAllSections(
          feed: _feed,
          onRetry: _reload,
          onChip: _selectChip,
        );
      case HomeChip.newSongs:
        return HomeNewSongs(feed: _feed, onRetry: _reload);
      case HomeChip.charts:
        return HomeCharts(feed: _feed, onRetry: _reload);
      case HomeChip.playlists:
        return const HomePlaylists();
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Stack(
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: AmbientBackdrop(height: 520),
        ),
        RefreshIndicator(
          onRefresh: _refresh,
          edgeOffset: top,
          child: CustomScrollView(
            physics: const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverToBoxAdapter(
                child: ContentBox(
                  padding: EdgeInsets.only(top: top + 12),
                  child: const EntranceFade(child: _HomeHeader()),
                ),
              ),
              const SliverToBoxAdapter(
                child: ContentBox(
                  child: EntranceFade(index: 1, child: _Greeting()),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentBox(
                  child: EntranceFade(
                    index: 2,
                    child: ChipBar<HomeChip>(
                      values: HomeChip.values,
                      selected: _chip,
                      labelOf: (chip) => chip.label,
                      onSelected: _selectChip,
                    ),
                  ),
                ),
              ),
              SliverToBoxAdapter(
                child: ContentBox(
                  child: AnimatedSwitcher(
                    duration: AppMotion.emphasized,
                    switchInCurve: AppMotion.enter,
                    switchOutCurve: AppMotion.exit,
                    transitionBuilder: fadeThroughTransition,
                    layoutBuilder: topStackLayout,
                    child: KeyedSubtree(
                      key: ValueKey('${_chip.name}-${identityHashCode(_feed)}'),
                      child: _content(),
                    ),
                  ),
                ),
              ),
              const SliverShellBottomInset(extra: 24),
            ],
          ),
        ),
      ],
    );
  }
}

class _HomeHeader extends StatelessWidget {
  const _HomeHeader();

  Future<void> _openLiked(BuildContext context) async {
    if (!app.session.value.isLoggedIn) {
      await showLoginDialog(context);
      return;
    }
    try {
      final collections = await app.library.userCollections();
      if (!context.mounted) return;
      final liked = collections.liked;
      if (liked == null) {
        showToast(context, '还没有喜欢的歌曲');
      } else {
        openPlaylist(context, liked);
      }
    } on Object catch (error) {
      if (context.mounted) showToast(context, describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
      child: Row(
        children: [
          ValueListenableBuilder(
            valueListenable: app.session,
            builder: (context, session, _) {
              final profile = session.profile;
              return Tooltip(
                message: profile == null ? '登录' : profile.nickname,
                child: Pressable(
                  hoverScale: 1.06,
                  onTap: () => profile == null
                      ? showLoginDialog(context)
                      : context.go('/library'),
                  child: Container(
                    width: 46,
                    height: 46,
                    padding: const EdgeInsets.all(2),
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      gradient: LinearGradient(colors: s.brandGradient),
                    ),
                    child: profile?.avatarUrl == null
                        ? CircleAvatar(
                            backgroundColor: s.chip,
                            child: Icon(
                              Icons.person_rounded,
                              color: s.textSecondary,
                            ),
                          )
                        : CoverImage(
                            url: profile!.avatarUrl,
                            size: 120,
                            width: 42,
                            height: 42,
                            radius: 21,
                          ),
                  ),
                ),
              );
            },
          ),
          const Spacer(),
          RoundIconButton(
            icon: Icons.search_rounded,
            tooltip: '搜索',
            onPressed: () => openSearch(context),
          ),
          const SizedBox(width: 10),
          RoundIconButton(
            icon: Icons.favorite_border_rounded,
            tooltip: '我喜欢的音乐',
            onPressed: () => _openLiked(context),
          ),
        ],
      ),
    );
  }
}

class _Greeting extends StatelessWidget {
  const _Greeting();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.session,
      builder: (context, session, _) => Padding(
        padding: const EdgeInsets.fromLTRB(
          AppMetrics.gutter,
          26,
          AppMetrics.gutter,
          20,
        ),
        child: Text(
          greetingLine(DateTime.now().hour, session.profile?.nickname),
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: context.text.headlineMedium?.copyWith(
            fontSize: 34,
            height: 1.2,
            fontWeight: FontWeight.w500,
            letterSpacing: -0.8,
          ),
        ),
      ),
    );
  }
}
