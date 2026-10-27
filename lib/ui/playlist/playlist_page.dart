import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../models/comment_target.dart';
import '../../models/playlist.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/detail_header.dart';
import '../browse_widgets/playback.dart';
import '../browse_widgets/sheets.dart';
import '../browse_widgets/track_collection_view.dart';
import '../login/login_dialog.dart';
import '../shared/comments_view.dart';
import '../shared/playlist_picker.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';

/// Playlist detail: blurred-cover hero, actions and the full track list.
///
/// The [preview] passed by the navigation call renders instantly; the track
/// list shows skeletons until the details arrive.
class PlaylistPage extends StatefulWidget {
  const PlaylistPage({super.key, required this.playlistId, this.preview});

  final int playlistId;

  /// Playlist summary passed by the navigation call, rendered instantly while
  /// the details load.
  final Playlist? preview;

  @override
  State<PlaylistPage> createState() => _PlaylistPageState();
}

class _PlaylistPageState extends State<PlaylistPage> {
  Playlist? _detail;
  String? _error;
  bool _subscribed = false;
  bool _subscribing = false;
  int _generation = 0;

  bool get _isDaily => widget.playlistId == Playlist.dailyRecommendId;

  Playlist get _playlist =>
      _detail ??
      widget.preview ??
      Playlist(
        id: widget.playlistId,
        name: _isDaily ? '每日歌曲推荐' : '歌单',
        isDailyRecommend: _isDaily,
      );

  @override
  void initState() {
    super.initState();
    _subscribed = widget.preview?.subscribed ?? false;
    unawaited(_load());
  }

  Future<void> _load({bool force = false}) async {
    final generation = ++_generation;
    if (_isDaily && !app.session.value.isLoggedIn) {
      setState(() => _error = '登录后查看每日推荐');
      return;
    }
    if (force) app.library.invalidatePlaylist(widget.playlistId);
    setState(() => _error = null);
    try {
      final detail = await app.library.playlistDetail(widget.playlistId);
      if (!mounted || generation != _generation) return;
      setState(() {
        _detail = detail;
        _subscribed = detail.subscribed;
      });
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = describeError(error));
    }
  }

  void _retry() {
    if (_isDaily && !app.session.value.isLoggedIn) {
      showLoginDialog(context).then((ok) {
        if (ok && mounted) unawaited(_load());
      });
      return;
    }
    unawaited(_load(force: true));
  }

  void _play({int? index, bool shuffle = false}) {
    final playlist = _detail;
    if (playlist == null) return;
    playCollection(
      context,
      playlist.tracks,
      index: index,
      shuffle: shuffle,
      title: playlist.name,
      sourceId: playlist.id,
    );
  }

  bool get _canSubscribe {
    final uid = app.session.value.profile?.id;
    return uid != null && !_isDaily && !_playlist.isMine(uid);
  }

  bool get _isOwn =>
      !_isDaily && _playlist.isMine(app.session.value.profile?.id);

  Future<void> _toggleSubscribe() async {
    if (_subscribing) return;
    final next = !_subscribed;
    setState(() {
      _subscribed = next;
      _subscribing = true;
    });
    try {
      await app.library.subscribePlaylist(widget.playlistId, subscribe: next);
      if (mounted) showToast(context, next ? '已收藏歌单' : '已取消收藏');
    } on Object catch (error) {
      if (!mounted) return;
      setState(() => _subscribed = !next);
      showToast(context, describeError(error));
    } finally {
      if (mounted) setState(() => _subscribing = false);
    }
  }

  void _downloadAll() {
    final tracks = _detail?.tracks ?? const [];
    final playable = tracks.where((song) => song.playable).toList();
    if (playable.isEmpty) return;
    unawaited(app.downloads.enqueue(playable, folder: _playlist.name));
    showToast(context, '已将 ${playable.length} 首歌加入下载队列');
  }

  void _openComments() => showComments(
    context,
    CommentTarget(
      CommentResource.playlist,
      widget.playlistId,
      title: _playlist.name,
    ),
  );

  void _more() {
    final playlist = _playlist;
    final tracks = _detail?.tracks ?? const [];
    unawaited(
      showActionSheet(
        context,
        title: playlist.name,
        actions: [
          if (tracks.isNotEmpty)
            SheetAction(
              icon: Icons.library_add_rounded,
              label: '全部收藏到歌单',
              onSelected: () => showAddToPlaylist(context, tracks),
            ),
          if (!_isDaily)
            SheetAction(
              icon: Icons.link_rounded,
              label: '复制歌单链接',
              onSelected: () {
                unawaited(
                  Clipboard.setData(
                    ClipboardData(
                      text: 'https://music.163.com/playlist?id=${playlist.id}',
                    ),
                  ),
                );
                showToast(context, '已复制链接');
              },
            ),
          SheetAction(
            icon: Icons.refresh_rounded,
            label: '刷新',
            onSelected: () => unawaited(_load(force: true)),
          ),
          if (_isOwn && !playlist.isLikedSongs)
            SheetAction(
              icon: Icons.delete_outline_rounded,
              label: '删除歌单',
              destructive: true,
              onSelected: _delete,
            ),
        ],
      ),
    );
  }

  Future<void> _delete() async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除歌单',
      message: '确定删除「${_playlist.name}」吗？此操作无法撤销。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    try {
      await app.library.deletePlaylist(widget.playlistId);
      if (!mounted) return;
      showToast(context, '已删除歌单');
      Navigator.of(context).maybePop();
    } on Object catch (error) {
      if (mounted) showToast(context, describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final playlist = _playlist;
    final tracks = _detail?.tracks;
    return TrackCollectionView(
      title: playlist.name,
      tracks: tracks,
      error: _error,
      onRetry: _retry,
      onRefresh: () => _load(force: true),
      onPlay: (index) => _play(index: index),
      removeFrom: _isOwn ? _detail : null,
      onRemoved: () => unawaited(_load(force: true)),
      emptyMessage: '这个歌单还没有歌曲',
      barActions: [
        RoundIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: '更多',
          size: 42,
          onPressed: _more,
        ),
      ],
      hero: _PlaylistHero(
        playlist: playlist,
        loaded: _detail != null,
        subscribed: _subscribed,
        canSubscribe: _canSubscribe,
        onPlay: tracks == null || tracks.isEmpty ? null : _play,
        onShuffle: tracks == null || tracks.isEmpty
            ? null
            : () => _play(shuffle: true),
        onSubscribe: _toggleSubscribe,
        onDownload: tracks == null || tracks.isEmpty ? null : _downloadAll,
        onComments: _isDaily ? null : _openComments,
      ),
    );
  }
}

class _PlaylistHero extends StatelessWidget {
  const _PlaylistHero({
    required this.playlist,
    required this.loaded,
    required this.subscribed,
    required this.canSubscribe,
    required this.onPlay,
    required this.onShuffle,
    required this.onSubscribe,
    required this.onDownload,
    required this.onComments,
  });

  final Playlist playlist;
  final bool loaded;
  final bool subscribed;
  final bool canSubscribe;
  final VoidCallback? onPlay;
  final VoidCallback? onShuffle;
  final VoidCallback onSubscribe;
  final VoidCallback? onDownload;
  final VoidCallback? onComments;

  @override
  Widget build(BuildContext context) {
    final daily = playlist.isDailyRecommend;
    final count = loaded ? playlist.tracks.length : playlist.trackCount;
    final stats = [
      if (count > 0) '$count 首',
      if (playlist.playCount > 0) '${playlist.playCount.compact} 次播放',
      if (playlist.subscribedCount > 0)
        '${playlist.subscribedCount.compact} 收藏',
      if (playlist.updateTime != null) '${playlist.updateTime!.date} 更新',
    ];
    final cover =
        playlist.coverUrl ??
        (loaded && playlist.tracks.isNotEmpty
            ? playlist.tracks.first.album.picUrl
            : null);
    return DetailHero(
      title: playlist.isLikedSongs ? '我喜欢的音乐' : playlist.name,
      coverUrl: cover,
      eyebrow: daily
          ? '每日推荐 · ${DateTime.now().month} 月 ${DateTime.now().day} 日'
          : (playlist.isPrivate ? '隐私歌单' : '歌单'),
      subtitle: playlist.creator.nickname.isEmpty
          ? null
          : _Creator(playlist: playlist),
      stats: stats,
      description: playlist.description,
      below: playlist.tags.isEmpty ? null : _Tags(tags: playlist.tags),
      actions: DetailActions(
        primary: LimePillButton(
          label: '播放全部',
          icon: Icons.play_arrow_rounded,
          loading: !loaded,
          onPressed: onPlay,
        ),
        secondary: [
          RoundIconButton(
            icon: Icons.shuffle_rounded,
            tooltip: '随机播放',
            onPressed: onShuffle,
          ),
          if (canSubscribe)
            RoundIconButton(
              icon: subscribed
                  ? Icons.favorite_rounded
                  : Icons.favorite_border_rounded,
              tooltip: subscribed ? '取消收藏' : '收藏歌单',
              active: subscribed,
              onPressed: onSubscribe,
            ),
          RoundIconButton(
            icon: Icons.download_rounded,
            tooltip: '全部下载',
            onPressed: onDownload,
          ),
          if (onComments != null)
            RoundIconButton(
              icon: Icons.chat_bubble_outline_rounded,
              tooltip: '评论',
              onPressed: onComments,
            ),
        ],
      ),
    );
  }
}

class _Creator extends StatelessWidget {
  const _Creator({required this.playlist});

  final Playlist playlist;

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CoverImage(
          url: playlist.creator.avatarUrl,
          size: 80,
          width: 26,
          height: 26,
          radius: 13,
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            playlist.creator.nickname,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ),
      ],
    );
  }
}

class _Tags extends StatelessWidget {
  const _Tags({required this.tags});

  final List<String> tags;

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 6,
      runSpacing: 6,
      alignment: DetailHeroScope.compactOf(context)
          ? WrapAlignment.center
          : WrapAlignment.start,
      children: [
        for (final tag in tags.take(4))
          TagBadge(tag, color: context.surfaces.textSecondary),
      ],
    );
  }
}
