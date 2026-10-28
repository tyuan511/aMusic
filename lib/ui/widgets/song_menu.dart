import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../core/errors.dart';
import '../../models/comment_target.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../services/local_library_service.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/sheets.dart';
import '../player/player_sheets.dart';
import '../shared/comments_view.dart';
import '../shared/playlist_picker.dart';
import 'cover_image.dart';
import 'like_button.dart';

/// Actions for a single track, as a bottom sheet on every form factor.
///
/// [removeFrom] enables "从歌单删除" when it is a playlist the signed in
/// account owns; [onRemoved] runs after the server confirmed the removal.
Future<void> showSongMenu(
  BuildContext context,
  Song song, {
  Playlist? removeFrom,
  VoidCallback? onRemoved,
  bool sleepTimer = false,
  bool speed = false,
}) {
  // Actions run after the sheet closed, against the page that opened it.
  final pageContext = context;
  final messenger = ScaffoldMessenger.maybeOf(context);
  final cloud = !LocalLibraryService.isLocalId(song.id);
  final uid = app.session.value.profile?.id;
  final canRemove =
      cloud &&
      removeFrom != null &&
      !removeFrom.isDailyRecommend &&
      removeFrom.isMine(uid);

  void toast(String message) {
    if (messenger != null) showToastOn(messenger, message);
  }

  final actions = <SheetAction>[
    SheetAction(
      icon: Icons.playlist_play_rounded,
      label: '下一首播放',
      onSelected: () {
        unawaited(app.player.playNext(song));
        toast('将在当前歌曲后播放');
      },
    ),
    SheetAction(
      icon: Icons.queue_music_rounded,
      label: '加入播放队列',
      onSelected: () {
        unawaited(app.player.addToQueue(song));
        toast('已添加到播放队列');
      },
    ),
    if (cloud) ...[
      SheetAction(
        icon: Icons.library_add_rounded,
        label: '收藏到歌单',
        onSelected: () => showAddToPlaylist(pageContext, [song]),
      ),
      SheetAction(
        icon: Icons.chat_bubble_outline_rounded,
        label: '评论',
        onSelected: () => showComments(
          pageContext,
          CommentTarget(CommentResource.song, song.id, title: song.name),
        ),
      ),
    ],
    if (speed)
      SheetAction(
        icon: Icons.speed_rounded,
        label: (app.player.speed.value - 1).abs() < 0.01
            ? '播放速度'
            : '播放速度：${speedLabel(app.player.speed.value)}',
        onSelected: () => showSpeedSheet(pageContext),
      ),
    if (sleepTimer)
      SheetAction(
        icon: Icons.bedtime_outlined,
        label: '定时关闭',
        onSelected: () => showSleepTimerSheet(pageContext),
      ),
    if (song.artists.any((artist) => artist.id > 0))
      SheetAction(
        icon: Icons.person_outline_rounded,
        label: song.artists.length > 1 ? '查看歌手' : '歌手：${song.artistText}',
        onSelected: () => _openArtists(pageContext, song),
      ),
    if (song.album.id > 0)
      SheetAction(
        icon: Icons.album_outlined,
        label: '专辑：${song.album.name}',
        onSelected: () =>
            openAlbum(pageContext, song.album.id, preview: song.album),
      ),
    SheetAction(
      icon: Icons.content_copy_rounded,
      label: '复制歌名',
      onSelected: () {
        unawaited(
          Clipboard.setData(
            ClipboardData(text: '${song.name} - ${song.artistText}'),
          ),
        );
        toast('已复制歌名');
      },
    ),
    if (cloud)
      SheetAction(
        icon: Icons.link_rounded,
        label: '复制链接',
        onSelected: () {
          unawaited(Clipboard.setData(ClipboardData(text: songLink(song.id))));
          toast('已复制链接');
        },
      ),
    if (canRemove)
      SheetAction(
        icon: Icons.delete_outline_rounded,
        label: '从歌单删除',
        destructive: true,
        onSelected: () => _remove(pageContext, song, removeFrom, onRemoved),
      ),
  ];

  return showActionSheet(
    context,
    header: _MenuHeader(song: song, cloud: cloud),
    actions: actions,
  );
}

/// Public web link of a song.
String songLink(int id) => 'https://music.163.com/song?id=$id';

Future<void> _openArtists(BuildContext context, Song song) async {
  final artists = song.artists.where((artist) => artist.id > 0).toList();
  if (artists.isEmpty || !context.mounted) return;
  if (artists.length == 1) {
    openArtist(context, artists.first.id, preview: artists.first);
    return;
  }
  await showActionSheet(
    context,
    title: '选择歌手',
    actions: [
      for (final artist in artists)
        SheetAction(
          icon: Icons.person_rounded,
          label: artist.name,
          onSelected: () => openArtist(context, artist.id, preview: artist),
        ),
    ],
  );
}

Future<void> _remove(
  BuildContext context,
  Song song,
  Playlist playlist,
  VoidCallback? onRemoved,
) async {
  final confirmed = await showConfirmDialog(
    context,
    title: '从歌单删除',
    message: '确定把《${song.name}》从「${playlist.name}」中删除吗？',
    confirmLabel: '删除',
    destructive: true,
  );
  if (!confirmed || !context.mounted) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    await app.library.removeFromPlaylist(playlist.id, [song.id]);
    if (messenger != null) showToastOn(messenger, '已从歌单删除');
    onRemoved?.call();
  } on Object catch (error) {
    if (messenger != null) showToastOn(messenger, describeError(error));
  }
}

class _MenuHeader extends StatelessWidget {
  const _MenuHeader({required this.song, required this.cloud});

  final Song song;
  final bool cloud;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 12, 12),
      child: Row(
        children: [
          CoverImage(
            url: song.album.picUrl,
            size: 160,
            width: 54,
            height: 54,
            radius: AppMetrics.radiusSm,
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  song.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  song.artistText,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: context.text.bodySmall?.copyWith(
                    color: context.surfaces.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          if (cloud) LikeButton(songId: song.id, size: 22),
        ],
      ),
    );
  }
}
