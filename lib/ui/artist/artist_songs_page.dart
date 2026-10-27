import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/paged.dart';
import '../browse_widgets/playback.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import '../widgets/song_tile.dart';

/// Sort order of [ArtistSongsPage].
enum ArtistSongOrder {
  hot('hot', '热门'),
  time('time', '最新');

  const ArtistSongOrder(this.value, this.label);

  /// Value of the `order` API parameter.
  final String value;
  final String label;
}

/// Every song of an artist, sorted 热门 / 最新, paged infinitely. Each order
/// keeps its own loaded pages while switching.
class ArtistSongsPage extends StatefulWidget {
  const ArtistSongsPage({super.key, required this.artistId});

  final int artistId;

  @override
  State<ArtistSongsPage> createState() => _ArtistSongsPageState();
}

class _ArtistSongsPageState extends State<ArtistSongsPage> {
  ArtistSongOrder _order = ArtistSongOrder.hot;
  final Map<ArtistSongOrder, PagedController<Song>> _pages = {};
  String _name = '';

  @override
  void initState() {
    super.initState();
    app.library.artistDetail(widget.artistId).then((detail) {
      if (mounted) setState(() => _name = detail.name);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    for (final controller in _pages.values) {
      controller.dispose();
    }
    super.dispose();
  }

  PagedController<Song> _controllerFor(ArtistSongOrder order) =>
      _pages.putIfAbsent(order, () {
        final controller = PagedController<Song>(
          (offset, limit) => app.library.artistSongs(
            widget.artistId,
            order: order.value,
            offset: offset,
            limit: limit,
          ),
          pageSize: 50,
        );
        unawaited(controller.ensureStarted());
        return controller;
      });

  @override
  Widget build(BuildContext context) {
    final controller = _controllerFor(_order);
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        SizedBox(height: top),
        ContentBox(
          child: PageHeader(
            title: _name.isEmpty ? '全部歌曲' : '$_name 的歌曲',
            actions: [
              ListenableBuilder(
                listenable: controller,
                builder: (context, _) => RoundIconButton(
                  icon: Icons.play_arrow_rounded,
                  tooltip: '播放已加载的歌曲',
                  active: true,
                  onPressed: controller.items.isEmpty
                      ? null
                      : () => playCollection(
                          context,
                          controller.items,
                          title: '$_name 的歌曲',
                          sourceId: widget.artistId,
                        ),
                ),
              ),
            ],
          ),
        ),
        ContentBox(
          padding: const EdgeInsets.only(bottom: 8),
          child: ChipBar<ArtistSongOrder>(
            values: ArtistSongOrder.values,
            selected: _order,
            labelOf: (order) => order.label,
            onSelected: (order) => setState(() => _order = order),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.standard,
            transitionBuilder: fadeThroughTransition,
            child: _SongList(
              key: ValueKey(_order),
              controller: controller,
              title: '$_name 的歌曲',
              artistId: widget.artistId,
            ),
          ),
        ),
      ],
    );
  }
}

class _SongList extends StatelessWidget {
  const _SongList({
    super.key,
    required this.controller,
    required this.title,
    required this.artistId,
  });

  final PagedController<Song> controller;
  final String title;
  final int artistId;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: controller,
      builder: (context, _) {
        if (controller.initialLoading) {
          return const ContentBox(
            padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
            child: MediaRowSkeletonList(count: 8),
          );
        }
        final songs = controller.items;
        if (songs.isEmpty && controller.errorText != null) {
          return ErrorView(
            message: controller.errorText!,
            onRetry: controller.refresh,
          );
        }
        if (songs.isEmpty) return const EmptyView(message: '暂无歌曲');
        return LoadMoreListener(
          onLoadMore: controller.loadMore,
          child: CustomScrollView(
            key: PageStorageKey(
              'artist-songs-$artistId-$title-${controller.hashCode}',
            ),
            slivers: [
              SliverContent(
                horizontal: AppMetrics.gutter - 10,
                sliver: SliverFixedExtentList.builder(
                  itemExtent: 64,
                  itemCount: songs.length,
                  itemBuilder: (context, index) => SongTile(
                    song: songs[index],
                    index: index,
                    onTap: () => playCollection(
                      context,
                      songs,
                      index: index,
                      title: title,
                      sourceId: artistId,
                    ),
                  ),
                ),
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
}
