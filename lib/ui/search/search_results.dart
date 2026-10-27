import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/album.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/paged.dart';
import '../browse_widgets/playback.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import '../widgets/song_tile.dart';
import 'search_session.dart';

/// Infinite result list of one tab. Reads (and lazily creates) the tab's
/// cached [PagedController] from [session], so switching back to a tab shows
/// its results and scroll position instantly.
class SearchResultsList extends StatelessWidget {
  const SearchResultsList({
    super.key,
    required this.session,
    required this.tab,
  });

  final SearchSession session;
  final SearchTab tab;

  @override
  Widget build(BuildContext context) {
    final controller = session.controllerFor(tab);
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.initialLoading) {
          return const ContentBox(
            padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
            child: MediaRowSkeletonList(count: 8),
          );
        }
        if (controller.items.isEmpty && controller.errorText != null) {
          return ErrorView(
            message: controller.errorText!,
            onRetry: controller.refresh,
          );
        }
        if (controller.items.isEmpty) {
          return EmptyView(
            message: '没有找到相关${tab.label}',
            icon: Icons.search_off_rounded,
          );
        }
        return LoadMoreListener(
          onLoadMore: controller.loadMore,
          child: CustomScrollView(
            key: PageStorageKey('search-${tab.name}-${session.keyword}'),
            slivers: [
              SliverContent(
                horizontal: AppMetrics.gutter - 10,
                top: 4,
                sliver: _sliverFor(context, controller.items),
              ),
              SliverToBoxAdapter(
                child: PagedFooter(
                  loading: controller.loading,
                  hasMore: controller.hasMore,
                  error: controller.errorText,
                  onRetry: controller.loadMore,
                ),
              ),
              const SliverShellBottomInset(),
            ],
          ),
        );
      },
    );
  }

  Widget _sliverFor(BuildContext context, List<Object> items) {
    if (tab == SearchTab.songs) {
      final songs = items.cast<Song>();
      return SliverFixedExtentList.builder(
        itemExtent: 64,
        itemCount: songs.length,
        itemBuilder: (context, index) => SongTile(
          song: songs[index],
          showAlbum: true,
          onTap: () => playCollection(
            context,
            songs,
            index: index,
            title: '“${session.keyword}” 的搜索结果',
          ),
        ),
      );
    }
    return SliverLayoutBuilder(
      builder: (context, constraints) {
        final columns = ResponsiveColumns.columnsFor(
          constraints.crossAxisExtent,
          minColumnWidth: 420,
          maxColumns: 2,
        );
        return SliverGrid.builder(
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: 76,
            crossAxisSpacing: 8,
          ),
          itemCount: items.length,
          itemBuilder: (context, index) => _row(context, items[index]),
        );
      },
    );
  }

  Widget _row(BuildContext context, Object item) {
    switch (item) {
      case final Album album:
        return MediaRow(
          title: album.name,
          subtitle: album.artistText,
          meta: album.publishTime?.date,
          coverUrl: album.picUrl,
          onTap: () => openAlbum(context, album.id, preview: album),
        );
      case final Artist artist:
        return MediaRow(
          title: artist.name,
          subtitle: artist.alias.isEmpty ? null : artist.alias.first,
          meta: (artist.albumSize ?? 0) > 0 ? '${artist.albumSize} 张专辑' : null,
          coverUrl: artist.picUrl,
          circleCover: true,
          onTap: () => openArtist(context, artist.id, preview: artist),
        );
      case final Playlist playlist:
        return MediaRow(
          title: playlist.name,
          subtitle: playlist.creator.nickname.isEmpty
              ? null
              : 'By ${playlist.creator.nickname}',
          meta: [
            if (playlist.trackCount > 0) '${playlist.trackCount} 首',
            if (playlist.playCount > 0) '${playlist.playCount.compact} 次播放',
          ].join('  '),
          coverUrl: playlist.coverUrl,
          onTap: () => openPlaylist(context, playlist),
        );
      default:
        return const SizedBox.shrink();
    }
  }
}
