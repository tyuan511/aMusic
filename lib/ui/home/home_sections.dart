import 'dart:async';

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../models/album.dart';
import '../../models/discovery.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/user.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/future_section.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/media_cards.dart';
import '../browse_widgets/paged.dart';
import '../browse_widgets/playback.dart';
import '../browse_widgets/playlist_row.dart';
import '../charts/charts_page.dart';
import '../widgets/kit.dart';
import '../widgets/playlist_card.dart';
import '../widgets/song_tile.dart';
import 'home_feed.dart';
import 'home_hero.dart';

/// 全部: hero carousel, recent plays, daily playlists, new songs, new
/// albums, charts preview and the account's playlists.
class HomeAllSections extends StatelessWidget {
  const HomeAllSections({
    super.key,
    required this.feed,
    required this.onRetry,
    required this.onChip,
  });

  final HomeFeed feed;
  final VoidCallback onRetry;
  final ValueChanged<HomeChip> onChip;

  @override
  Widget build(BuildContext context) {
    final compact = MediaQuery.sizeOf(context).width < 720;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SectionTitle(title: '精选推荐', subtitle: 'Curated & trending'),
        FutureBuilder<List<Playlist>>(
          future: feed.discover,
          builder: (context, snapshot) => HeroCarousel(
            items: buildHeroItems(
              context,
              loggedIn: feed.loggedIn,
              featured: snapshot.data ?? const [],
            ),
          ),
        ),
        const _RecentShelf(),
        SectionTitle(
          title: feed.loggedIn ? '每日歌单' : '推荐歌单',
          subtitle: feed.loggedIn ? '为你量身打造' : '登录后获得个性化推荐',
          onAction: () => onChip(HomeChip.playlists),
        ),
        FutureSection<List<Playlist>>(
          future: feed.discover,
          onRetry: onRetry,
          hideWhen: (list) => list.isEmpty,
          builder: (context, list) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.gutter - 10,
            ),
            child: ResponsiveColumns(
              minColumnWidth: 420,
              maxColumns: 2,
              children: [
                for (var i = 0; i < list.length && i < (compact ? 5 : 8); i++)
                  EntranceItem(
                    index: i,
                    child: PlaylistRow(playlist: list[i]),
                  ),
              ],
            ),
          ),
        ),
        SectionTitle(title: '新歌速递', onAction: () => onChip(HomeChip.newSongs)),
        FutureSection<List<Song>>(
          future: feed.newSongs(),
          onRetry: onRetry,
          hideWhen: (list) => list.isEmpty,
          builder: (context, songs) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.gutter - 10,
            ),
            child: ResponsiveColumns(
              minColumnWidth: 420,
              maxColumns: 2,
              children: [
                for (var i = 0; i < songs.length && i < (compact ? 5 : 8); i++)
                  SongTile(
                    song: songs[i],
                    onTap: () =>
                        playCollection(context, songs, index: i, title: '新歌速递'),
                  ),
              ],
            ),
          ),
        ),
        const SectionTitle(title: '新碟上架'),
        FutureSection<List<Album>>(
          future: feed.newAlbums,
          onRetry: onRetry,
          skeleton: const CardShelfSkeleton(),
          hideWhen: (list) => list.isEmpty,
          builder: (context, albums) => HorizontalShelf(
            height: 160 + CoverCard.textAreaHeight,
            itemWidth: 160,
            itemCount: albums.length,
            itemBuilder: (context, index) => AlbumCard(album: albums[index]),
          ),
        ),
        SectionTitle(title: '排行榜', onAction: () => context.go('/charts')),
        FutureSection<List<Toplist>>(
          future: feed.officialCharts,
          onRetry: onRetry,
          skeleton: const CardShelfSkeleton(),
          hideWhen: (list) => list.isEmpty,
          builder: (context, lists) => HorizontalShelf(
            height: 160 + CoverCard.textAreaHeight,
            itemWidth: 160,
            itemCount: lists.length.clamp(0, 10),
            itemBuilder: (context, index) =>
                ChartCoverCard(toplist: lists[index]),
          ),
        ),
        if (feed.loggedIn)
          FutureSection<UserCollections>(
            future: feed.collections,
            onRetry: onRetry,
            skeleton: const CardShelfSkeleton(),
            hideWhen: (c) => c.created.isEmpty && c.collected.isEmpty,
            builder: (context, collections) {
              final mine = [...collections.created, ...collections.collected];
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  SectionTitle(
                    title: '我的歌单',
                    onAction: () => context.go('/library'),
                  ),
                  HorizontalShelf(
                    height: 150 + CoverCard.textAreaHeight,
                    itemWidth: 150,
                    itemCount: mine.length.clamp(0, 12),
                    itemBuilder: (context, index) => PlaylistCard(
                      playlist: mine[index],
                      onTap: () => openPlaylist(context, mine[index]),
                    ),
                  ),
                ],
              );
            },
          ),
      ],
    );
  }
}

class _RecentShelf extends StatelessWidget {
  const _RecentShelf();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<List<Song>>(
      valueListenable: app.recent.tracks,
      builder: (context, tracks, _) {
        if (tracks.isEmpty) return const SizedBox.shrink();
        final shown = tracks.take(16).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(title: '最近播放', onAction: () => openHistory(context)),
            HorizontalShelf(
              height: 136 + CoverCard.textAreaHeight,
              itemWidth: 136,
              itemCount: shown.length,
              itemBuilder: (context, index) {
                final song = shown[index];
                return CoverCard(
                  title: song.name,
                  subtitle: song.artistText,
                  coverUrl: song.album.picUrl,
                  onTap: () => playCollection(
                    context,
                    shown,
                    index: index,
                    title: '最近播放',
                  ),
                );
              },
            ),
          ],
        );
      },
    );
  }
}

/// 新歌: region chips and the latest songs of that region.
class HomeNewSongs extends StatefulWidget {
  const HomeNewSongs({super.key, required this.feed, required this.onRetry});

  final HomeFeed feed;
  final VoidCallback onRetry;

  @override
  State<HomeNewSongs> createState() => _HomeNewSongsState();
}

class _HomeNewSongsState extends State<HomeNewSongs> {
  NewSongArea _area = NewSongArea.all;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        ChipBar<NewSongArea>(
          values: NewSongArea.values,
          selected: _area,
          labelOf: (area) => area.label,
          dense: true,
          onSelected: (area) => setState(() => _area = area),
        ),
        const SizedBox(height: 10),
        AnimatedSwitcher(
          duration: AppMotion.standard,
          transitionBuilder: fadeThroughTransition,
          layoutBuilder: topStackLayout,
          child: FutureSection<List<Song>>(
            key: ValueKey(_area),
            future: widget.feed.newSongs(_area),
            onRetry: widget.onRetry,
            skeleton: const MediaRowSkeletonList(
              count: 8,
              padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
            ),
            hideWhen: (songs) => songs.isEmpty,
            builder: (context, songs) {
              final shown = songs.take(50).toList();
              return Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.gutter - 10,
                ),
                child: Column(
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(10, 4, 10, 10),
                        child: LimePillButton(
                          label: '播放全部',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () => playCollection(
                            context,
                            shown,
                            title: '新歌速递 · ${_area.label}',
                          ),
                        ),
                      ),
                    ),
                    ResponsiveColumns(
                      minColumnWidth: 460,
                      maxColumns: 2,
                      children: [
                        for (var i = 0; i < shown.length; i++)
                          i < 12
                              ? EntranceItem(
                                  index: i,
                                  child: _tile(context, shown, i),
                                )
                              : _tile(context, shown, i),
                      ],
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _tile(BuildContext context, List<Song> songs, int index) => SongTile(
    song: songs[index],
    index: index,
    showAlbum: true,
    onTap: () => playCollection(
      context,
      songs,
      index: index,
      title: '新歌速递 · ${_area.label}',
    ),
  );
}

/// 排行: official chart cards (top 3 preview) + link to the full charts.
class HomeCharts extends StatelessWidget {
  const HomeCharts({super.key, required this.feed, required this.onRetry});

  final HomeFeed feed;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final tints = [s.lavender, s.lime, s.peach, const Color(0xFF7FD1E8)];
    return FutureSection<List<Toplist>>(
      future: feed.toplists,
      onRetry: onRetry,
      hideWhen: (lists) => lists.isEmpty,
      builder: (context, lists) {
        final official = lists.where((list) => list.isOfficial).toList();
        final shown = official.isEmpty ? lists.take(4).toList() : official;
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: '官方榜',
              actionLabel: '全部榜单',
              onAction: () => context.go('/charts'),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppMetrics.gutter,
              ),
              child: ResponsiveColumns(
                minColumnWidth: 420,
                maxColumns: 2,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < shown.length; i++)
                    EntranceItem(
                      index: i,
                      child: OfficialChartCard(
                        toplist: shown[i],
                        tint: tints[i % tints.length],
                      ),
                    ),
                ],
              ),
            ),
          ],
        );
      },
    );
  }
}

/// 歌单: hot categories and a paged playlist grid of the selected one.
class HomePlaylists extends StatefulWidget {
  const HomePlaylists({super.key});

  @override
  State<HomePlaylists> createState() => _HomePlaylistsState();
}

class _HomePlaylistsState extends State<HomePlaylists> {
  static const String _all = '全部';
  String _category = _all;
  List<String> _categories = const [_all];
  final Map<String, PagedController<Playlist>> _pages = {};

  @override
  void initState() {
    super.initState();
    app.library.playlistCategories().then((catalogue) {
      if (!mounted) return;
      setState(() {
        _categories = [_all, ...catalogue.hot.map((c) => c.name).take(14)];
      });
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    for (final controller in _pages.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PagedController<Playlist> _controllerFor(String category) =>
      _pages.putIfAbsent(category, () {
        final controller = PagedController<Playlist>(
          (offset, limit) => app.library.topPlaylists(
            cat: category,
            offset: offset,
            limit: limit,
          ),
          pageSize: 30,
        );
        unawaited(controller.ensureStarted());
        return controller;
      });

  @override
  Widget build(BuildContext context) {
    final controller = _controllerFor(_category);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 18),
        ChipBar<String>(
          values: _categories,
          selected: _category,
          labelOf: (c) => c,
          dense: true,
          onSelected: (c) => setState(() => _category = c),
        ),
        const SizedBox(height: 18),
        AnimatedSwitcher(
          duration: AppMotion.standard,
          transitionBuilder: fadeThroughTransition,
          layoutBuilder: topStackLayout,
          child: ListenableBuilder(
            key: ValueKey(_category),
            listenable: controller,
            builder: (context, _) {
              if (controller.initialLoading) {
                return const CardShelfSkeleton();
              }
              if (controller.items.isEmpty && controller.errorText != null) {
                return SectionError(
                  message: controller.errorText!,
                  onRetry: controller.refresh,
                );
              }
              final playlists = controller.items;
              return Column(
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppMetrics.gutter,
                    ),
                    child: CoverGrid(
                      itemCount: playlists.length,
                      itemBuilder: (context, index) => PlaylistCard(
                        playlist: playlists[index],
                        onTap: () => openPlaylist(context, playlists[index]),
                      ),
                    ),
                  ),
                  if (controller.hasMore || controller.loading)
                    Padding(
                      padding: const EdgeInsets.only(top: 20),
                      child: Center(
                        child: LimePillButton(
                          label: '加载更多',
                          icon: Icons.expand_more_rounded,
                          loading: controller.loading,
                          onPressed: controller.loading
                              ? null
                              : controller.loadMore,
                        ),
                      ),
                    )
                  else
                    PagedFooter(
                      loading: false,
                      hasMore: false,
                      error: controller.errorText,
                      onRetry: controller.loadMore,
                    ),
                ],
              );
            },
          ),
        ),
      ],
    );
  }
}
