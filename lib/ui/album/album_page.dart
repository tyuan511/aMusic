import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../models/album.dart';
import '../../models/comment_target.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/detail_header.dart';
import '../browse_widgets/playback.dart';
import '../browse_widgets/sheets.dart';
import '../browse_widgets/track_collection_view.dart';
import '../shared/comments_view.dart';
import '../shared/playlist_picker.dart';
import '../widgets/kit.dart';

/// 专辑详情: cover hero with artist links, release info, description and the
/// track list grouped by disc.
///
/// [preview] may be an [Album] or an [AlbumRef] (from a song row); it renders
/// instantly while the details load.
class AlbumPage extends StatefulWidget {
  const AlbumPage({super.key, required this.albumId, this.preview});

  final int albumId;

  /// Optional summary shown while loading ([Album] or [AlbumRef]).
  final Object? preview;

  @override
  State<AlbumPage> createState() => _AlbumPageState();
}

/// Turns whatever summary the navigation passed into an [Album].
Album? albumFromPreview(int id, Object? preview) => switch (preview) {
  final Album album => album,
  final AlbumRef ref => Album(id: id, name: ref.name, picUrl: ref.picUrl),
  _ => null,
};

class _AlbumPageState extends State<AlbumPage> {
  Album? _detail;
  String? _error;
  int _generation = 0;

  Album get _album =>
      _detail ??
      albumFromPreview(widget.albumId, widget.preview) ??
      Album(id: widget.albumId, name: '专辑');

  @override
  void initState() {
    super.initState();
    unawaited(_load());
  }

  Future<void> _load() async {
    final generation = ++_generation;
    setState(() => _error = null);
    try {
      final detail = await app.library.albumDetail(widget.albumId);
      if (!mounted || generation != _generation) return;
      setState(() => _detail = detail);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = describeError(error));
    }
  }

  void _play({int? index, bool shuffle = false}) {
    final album = _detail;
    if (album == null) return;
    playCollection(
      context,
      album.tracks,
      index: index,
      shuffle: shuffle,
      title: album.name,
      sourceId: album.id,
    );
  }

  void _download() {
    final tracks = (_detail?.tracks ?? const <Song>[])
        .where((song) => song.playable)
        .toList();
    if (tracks.isEmpty) return;
    unawaited(app.downloads.enqueue(tracks, folder: _album.name));
    showToast(context, '已将 ${tracks.length} 首歌加入下载队列');
  }

  void _more() {
    final tracks = _detail?.tracks ?? const <Song>[];
    unawaited(
      showActionSheet(
        context,
        title: _album.name,
        actions: [
          if (tracks.isNotEmpty)
            SheetAction(
              icon: Icons.library_add_rounded,
              label: '全部收藏到歌单',
              onSelected: () => showAddToPlaylist(context, tracks),
            ),
          SheetAction(
            icon: Icons.link_rounded,
            label: '复制专辑链接',
            onSelected: () {
              unawaited(
                Clipboard.setData(
                  ClipboardData(
                    text: 'https://music.163.com/album?id=${widget.albumId}',
                  ),
                ),
              );
              showToast(context, '已复制链接');
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final album = _album;
    final tracks = _detail?.tracks;
    final hasTracks = tracks != null && tracks.isNotEmpty;
    final stats = [
      if (album.publishTime != null) '${album.publishTime!.date} 发行',
      if (album.company != null && album.company!.isNotEmpty) album.company!,
      if ((tracks?.length ?? album.size) > 0)
        '${tracks?.length ?? album.size} 首',
    ];
    return TrackCollectionView(
      title: album.name,
      tracks: tracks,
      error: _error,
      onRetry: _load,
      onRefresh: _load,
      byDisc: true,
      numbered: true,
      onPlay: (index) => _play(index: index),
      emptyMessage: '这张专辑还没有歌曲',
      barActions: [
        RoundIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: '更多',
          size: 42,
          onPressed: _more,
        ),
      ],
      hero: DetailHero(
        title: album.name,
        coverUrl: album.picUrl,
        eyebrow: [
          '专辑',
          if (album.subType != null && album.subType!.isNotEmpty)
            album.subType!,
        ].join(' · '),
        subtitle: album.artists.isEmpty
            ? null
            : _ArtistLinks(artists: album.artists),
        stats: stats,
        description: album.description,
        actions: DetailActions(
          primary: LimePillButton(
            label: '播放全部',
            icon: Icons.play_arrow_rounded,
            loading: _detail == null && _error == null,
            onPressed: hasTracks ? _play : null,
          ),
          secondary: [
            RoundIconButton(
              icon: Icons.shuffle_rounded,
              tooltip: '随机播放',
              onPressed: hasTracks ? () => _play(shuffle: true) : null,
            ),
            RoundIconButton(
              icon: Icons.download_rounded,
              tooltip: '全部下载',
              onPressed: hasTracks ? _download : null,
            ),
            RoundIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: '评论',
              onPressed: () => showComments(
                context,
                CommentTarget(
                  CommentResource.album,
                  widget.albumId,
                  title: album.name,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "歌手 A / 歌手 B" with every name opening the artist page.
class _ArtistLinks extends StatelessWidget {
  const _ArtistLinks({required this.artists});

  final List<Artist> artists;

  @override
  Widget build(BuildContext context) {
    final style = context.text.bodyLarge?.copyWith(
      fontWeight: FontWeight.w500,
      color: context.colors.primary,
    );
    final separator = context.text.bodyLarge?.copyWith(
      color: context.surfaces.textTertiary,
    );
    return Wrap(
      alignment: DetailHeroScope.compactOf(context)
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: [
        for (var i = 0; i < artists.length; i++) ...[
          if (i > 0) Text(' / ', style: separator),
          Pressable(
            onTap: artists[i].id > 0
                ? () => openArtist(context, artists[i].id, preview: artists[i])
                : null,
            child: Text(artists[i].name, style: style),
          ),
        ],
      ],
    );
  }
}
