import 'package:flutter/material.dart';

import '../../models/playlist.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../widgets/kit.dart';
import 'cards.dart';

/// "Cover · title · By 作者 • 24 首 · (play)" row of the reference design.
///
/// The trailing round button loads and plays the playlist in place, with a
/// spinner while loading.
class PlaylistRow extends StatelessWidget {
  const PlaylistRow({
    super.key,
    required this.playlist,
    this.title,
    this.onLongPress,
    this.leading,
    this.showCreator = true,
  });

  final Playlist playlist;

  /// Overrides the playlist name ("我喜欢的音乐").
  final String? title;
  final VoidCallback? onLongPress;
  final Widget? leading;
  final bool showCreator;

  @override
  Widget build(BuildContext context) {
    final creator = playlist.creator.nickname;
    return MediaRow(
      title: title ?? playlist.name,
      subtitle: showCreator && creator.isNotEmpty ? 'By $creator' : null,
      meta: playlist.trackCount > 0 ? '${playlist.trackCount} 首' : null,
      coverUrl: playlist.coverUrl,
      leading: leading,
      badges: [if (playlist.isPrivate) const TagBadge('隐私')],
      onTap: () => openPlaylist(context, playlist),
      onLongPress: onLongPress,
      onSecondaryTap: onLongPress,
      trailing: CollectionPlayButton(
        sourceId: playlist.id,
        sourceTitle: playlist.name,
        load: () async =>
            (await app.library.playlistDetail(playlist.id)).tracks,
      ),
    );
  }
}
