import 'package:flutter/material.dart';

import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/user.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/buttons.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/playback.dart';
import '../browse_widgets/playlist_row.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import '../widgets/song_tile.dart';

/// Lime heart tile used as the cover of "我喜欢的音乐".
class LikedCover extends StatelessWidget {
  const LikedCover({super.key, this.size = 58});

  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [s.lavender, s.plum],
        ),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm + 2),
      ),
      child: Icon(
        Icons.favorite_rounded,
        color: Colors.white,
        size: size * 0.42,
      ),
    );
  }
}

/// Lazy, padded list of [children] for one library chip, pull to refresh.
class LibraryList extends StatelessWidget {
  const LibraryList({
    super.key,
    required this.itemCount,
    required this.itemBuilder,
    this.onRefresh,
    this.header,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final Future<void> Function()? onRefresh;
  final Widget? header;

  @override
  Widget build(BuildContext context) {
    final list = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (header != null)
          SliverToBoxAdapter(child: ContentBox(child: header!)),
        SliverContent(
          horizontal: AppMetrics.gutter - 10,
          sliver: SliverList.builder(
            itemCount: itemCount,
            itemBuilder: (context, index) => index < 14
                ? EntranceItem(index: index, child: itemBuilder(context, index))
                : itemBuilder(context, index),
          ),
        ),
        const SliverShellBottomInset(),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// 全部: liked songs, shortcuts and both playlist groups.
class LibraryOverview extends StatelessWidget {
  const LibraryOverview({
    super.key,
    required this.collections,
    required this.onRefresh,
    required this.onManage,
    required this.onCreate,
  });

  final UserCollections collections;
  final Future<void> Function() onRefresh;
  final void Function(Playlist playlist) onManage;
  final VoidCallback onCreate;

  @override
  Widget build(BuildContext context) {
    final liked = collections.liked;
    final rows = <Widget>[
      if (liked != null)
        PlaylistRow(
          playlist: liked,
          title: '我喜欢的音乐',
          showCreator: false,
          leading: const LikedCover(),
        ),
      const _LocalMusicRow(),
      const _RecentMusicRow(),
      SectionTitle(
        title: '创建的歌单',
        subtitle: '${collections.created.length} 个',
        actionLabel: '新建',
        onAction: onCreate,
        padding: const EdgeInsets.fromLTRB(10, 28, 10, 8),
      ),
      for (final playlist in collections.created)
        PlaylistRow(
          playlist: playlist,
          showCreator: false,
          onLongPress: () => onManage(playlist),
        ),
      if (collections.collected.isNotEmpty)
        SectionTitle(
          title: '收藏的歌单',
          subtitle: '${collections.collected.length} 个',
          padding: const EdgeInsets.fromLTRB(10, 28, 10, 8),
        ),
      for (final playlist in collections.collected)
        PlaylistRow(playlist: playlist, onLongPress: () => onManage(playlist)),
    ];
    return LibraryList(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
      onRefresh: onRefresh,
    );
  }
}

/// 本地 / 最近 shortcuts using the same row treatment as playlists.
class LibraryShortcuts extends StatelessWidget {
  const LibraryShortcuts({super.key});

  @override
  Widget build(BuildContext context) =>
      const Column(children: [_LocalMusicRow(), _RecentMusicRow()]);
}

class _LocalMusicRow extends StatelessWidget {
  const _LocalMusicRow();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder<List<Song>>(
      valueListenable: app.localLibrary.songs,
      builder: (context, songs, _) => MediaRow(
        leading: _ShortcutIcon(icon: Icons.folder_open_rounded, color: s.peach),
        title: '本地音乐',
        subtitle: songs.isEmpty ? '扫描设备中的音乐' : '${songs.length} 首本地歌曲',
        trailing: Icon(Icons.chevron_right_rounded, color: s.textTertiary),
        onTap: () => openLocalMusic(context),
      ),
    );
  }
}

class _RecentMusicRow extends StatelessWidget {
  const _RecentMusicRow();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder<List<Song>>(
      valueListenable: app.recent.tracks,
      builder: (context, tracks, _) => MediaRow(
        leading: _ShortcutIcon(icon: Icons.history_rounded, color: s.lavender),
        title: '最近播放',
        subtitle: tracks.isEmpty ? '暂无记录' : '${tracks.length} 首',
        trailing: Icon(Icons.chevron_right_rounded, color: s.textTertiary),
        onTap: () => openHistory(context),
      ),
    );
  }
}

class _ShortcutIcon extends StatelessWidget {
  const _ShortcutIcon({required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 58,
    height: 58,
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.16),
      borderRadius: BorderRadius.circular(AppMetrics.radiusSm + 2),
    ),
    child: Icon(icon, color: color, size: 26),
  );
}

/// List of playlists for 创建 / 收藏.
class PlaylistGroupView extends StatelessWidget {
  const PlaylistGroupView({
    super.key,
    required this.playlists,
    required this.onRefresh,
    required this.onManage,
    this.onCreate,
    this.emptyMessage = '还没有歌单',
  });

  final List<Playlist> playlists;
  final Future<void> Function() onRefresh;
  final void Function(Playlist playlist) onManage;
  final VoidCallback? onCreate;
  final String emptyMessage;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final rows = <Widget>[
      if (onCreate != null)
        MediaRow(
          title: '新建歌单',
          leading: Container(
            width: 58,
            height: 58,
            decoration: BoxDecoration(
              color: s.lime,
              borderRadius: BorderRadius.circular(AppMetrics.radiusSm + 2),
            ),
            child: Icon(Icons.add_rounded, color: s.onLime, size: 28),
          ),
          onTap: onCreate,
        ),
      if (playlists.isEmpty)
        EmptyView(message: emptyMessage, icon: Icons.queue_music_rounded),
      for (final playlist in playlists)
        PlaylistRow(playlist: playlist, onLongPress: () => onManage(playlist)),
    ];
    return LibraryList(
      itemCount: rows.length,
      itemBuilder: (context, index) => rows[index],
      onRefresh: onRefresh,
    );
  }
}

/// 喜欢: the liked songs playlist as a lazy song list.
class LikedSongsView extends StatelessWidget {
  const LikedSongsView({
    super.key,
    required this.liked,
    required this.onRefresh,
  });

  final Playlist? liked;
  final Future<void> Function() onRefresh;

  @override
  Widget build(BuildContext context) {
    final playlist = liked;
    if (playlist == null) {
      return const EmptyView(message: '还没有喜欢的歌曲', icon: Icons.favorite_border);
    }
    return AsyncView<Playlist>(
      key: ValueKey('liked-${playlist.id}'),
      load: () => app.library.playlistDetail(playlist.id),
      skeleton: true,
      emptyWhen: (detail) => detail.tracks.isEmpty,
      emptyView: const EmptyView(
        message: '还没有喜欢的歌曲',
        icon: Icons.favorite_border,
      ),
      builder: (context, detail) => SongListView(
        songs: detail.tracks,
        title: '我喜欢的音乐',
        sourceId: detail.id,
        onRefresh: () async {
          app.library.invalidatePlaylist(detail.id);
          await onRefresh();
        },
      ),
    );
  }
}

/// Lazy song list with a "播放全部" header.
class SongListView extends StatelessWidget {
  const SongListView({
    super.key,
    required this.songs,
    required this.title,
    this.sourceId,
    this.onRefresh,
    this.footer,
    this.showHeader = true,
  });

  final List<Song> songs;
  final String title;
  final int? sourceId;
  final Future<void> Function()? onRefresh;
  final Widget? footer;

  /// Whether to show the "播放全部" row; false when the host page offers it.
  final bool showHeader;

  @override
  Widget build(BuildContext context) {
    final list = CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        if (showHeader)
          SliverContent(
            horizontal: AppMetrics.gutter - 10,
            sliver: SliverToBoxAdapter(
              child: Padding(
                // Line up with the song covers, which sit inside the tile padding.
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 8),
                child: Row(
                  children: [
                    LimePillButton(
                      label: '播放全部',
                      icon: Icons.play_arrow_rounded,
                      onPressed: () => playCollection(
                        context,
                        songs,
                        title: title,
                        sourceId: sourceId,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Text(
                      '${songs.length} 首',
                      style: context.text.bodySmall?.copyWith(
                        color: context.surfaces.textTertiary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        SliverContent(
          horizontal: AppMetrics.gutter - 10,
          sliver: SliverFixedExtentList.builder(
            itemExtent: 64,
            itemCount: songs.length,
            itemBuilder: (context, index) => SongTile(
              song: songs[index],
              showAlbum: true,
              onTap: () => playCollection(
                context,
                songs,
                index: index,
                title: title,
                sourceId: sourceId,
              ),
            ),
          ),
        ),
        if (footer != null)
          SliverToBoxAdapter(child: ContentBox(child: footer!)),
        const SliverShellBottomInset(),
      ],
    );
    if (onRefresh == null) return list;
    return RefreshIndicator(onRefresh: onRefresh!, child: list);
  }
}

/// 本地 / 下载: one summary card centred at the top.
class SummaryChipView extends StatelessWidget {
  const SummaryChipView({super.key, required this.card});

  final Widget card;

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        8,
        AppMetrics.gutter,
        shellBottomInset(context),
      ),
      children: [ContentBox(child: EntranceItem(child: card))],
    );
  }
}
