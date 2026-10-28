import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/user.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/sheets.dart';
import '../library/create_playlist_dialog.dart';
import '../login/login_dialog.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';

/// "收藏到歌单" sheet: pick one of the account's own playlists (or create one
/// inline) and add [songs] to it. Guests are asked to sign in first.
Future<void> showAddToPlaylist(BuildContext context, List<Song> songs) async {
  final ids = [
    for (final song in songs)
      if (song.id > 0) song.id,
  ];
  if (ids.isEmpty) return;
  final messenger = ScaffoldMessenger.maybeOf(context);
  if (!app.session.value.isLoggedIn) {
    final ok = await showLoginDialog(context);
    if (!ok || !context.mounted) return;
  }
  final target = await showAppSheet<Playlist>(
    context,
    isScrollControlled: true,
    builder: (context) => _PickerSheet(count: ids.length),
  );
  if (target == null) return;
  try {
    await app.library.addToPlaylist(target.id, ids);
    if (messenger != null) {
      showToastOn(
        messenger,
        ids.length == 1
            ? '已收藏到「${target.name}」'
            : '已将 ${ids.length} 首歌收藏到「${target.name}」',
      );
    }
  } on Object catch (error) {
    if (messenger != null) showToastOn(messenger, describeError(error));
  }
}

/// Own playlists a song may be added to: liked songs first, then created.
List<Playlist> pickablePlaylists(UserCollections collections) => [
  ?collections.liked,
  ...collections.created,
];

class _PickerSheet extends StatefulWidget {
  const _PickerSheet({required this.count});

  final int count;

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  late Future<UserCollections> _future = app.library.userCollections();
  final TextEditingController _name = TextEditingController();
  bool _creating = false;
  bool _busy = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _create() async {
    final invalid = validatePlaylistName(_name.text);
    if (invalid != null) {
      setState(() => _error = invalid);
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final playlist = await app.library.createPlaylist(_name.text.trim());
      if (mounted) Navigator.pop(context, playlist);
    } on Object catch (error) {
      if (mounted) {
        setState(() {
          _busy = false;
          _error = describeError(error);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final height = MediaQuery.sizeOf(context).height;
    return SafeArea(
      top: false,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxHeight: height * 0.75),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 8),
              child: Text(
                widget.count == 1 ? '收藏到歌单' : '收藏 ${widget.count} 首歌到歌单',
                style: context.text.titleMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.standard,
              curve: AppMotion.enter,
              alignment: Alignment.topCenter,
              child: _creating ? _createField(context) : _createRow(context),
            ),
            Flexible(
              child: FutureBuilder<UserCollections>(
                future: _future,
                builder: (context, snapshot) {
                  if (snapshot.hasError) {
                    return ErrorView(
                      compact: true,
                      message: describeError(snapshot.error!),
                      onRetry: () => setState(
                        () => _future = app.library.userCollections(),
                      ),
                    );
                  }
                  if (!snapshot.hasData) {
                    return const MediaRowSkeletonList(
                      count: 4,
                      padding: EdgeInsets.symmetric(horizontal: 10),
                    );
                  }
                  final playlists = pickablePlaylists(snapshot.data!);
                  if (playlists.isEmpty) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(
                        '还没有自建歌单',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: s.textTertiary),
                      ),
                    );
                  }
                  return ListView.builder(
                    shrinkWrap: true,
                    padding: const EdgeInsets.fromLTRB(10, 0, 10, 16),
                    itemCount: playlists.length,
                    itemBuilder: (context, index) {
                      final playlist = playlists[index];
                      return MediaRow(
                        title: playlist.isLikedSongs ? '我喜欢的音乐' : playlist.name,
                        coverUrl: playlist.coverUrl,
                        coverSize: 50,
                        meta: '${playlist.trackCount} 首',
                        badges: [if (playlist.isPrivate) const TagBadge('隐私')],
                        onTap: () => Navigator.pop(context, playlist),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _createRow(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 10),
      child: MediaRow(
        key: const ValueKey('create-row'),
        title: '新建歌单',
        coverSize: 50,
        leading: Container(
          width: 50,
          height: 50,
          decoration: BoxDecoration(
            color: context.surfaces.lime,
            borderRadius: BorderRadius.circular(AppMetrics.radiusSm + 2),
          ),
          child: Icon(Icons.add_rounded, color: context.surfaces.onLime),
        ),
        onTap: () => setState(() => _creating = true),
      ),
    );
  }

  Widget _createField(BuildContext context) {
    return Padding(
      key: const ValueKey('create-field'),
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: TextField(
              controller: _name,
              autofocus: true,
              enabled: !_busy,
              maxLength: kPlaylistNameMax,
              onSubmitted: (_) => _create(),
              decoration: InputDecoration(hintText: '新歌单名称', errorText: _error),
            ),
          ),
          const SizedBox(width: 10),
          Padding(
            padding: const EdgeInsets.only(top: 2),
            child: FilledButton(
              onPressed: _busy ? null : _create,
              child: Text(_busy ? '创建中' : '创建并收藏'),
            ),
          ),
        ],
      ),
    );
  }
}
