import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/user.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/sheets.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import 'create_playlist_dialog.dart';
import 'library_views.dart';

/// Chips of the library page.
enum LibraryChip {
  all('全部'),
  created('创建'),
  collected('收藏'),
  liked('喜欢'),
  local('本地'),
  recent('最近');

  const LibraryChip(this.label);

  final String label;

  /// Chips that need a NetEase account.
  bool get needsAccount =>
      this == all || this == created || this == collected || this == liked;
}

/// 我的音乐: the account's playlists and the on-device collections, filtered
/// by a chip bar. Guests see a sign-in card for the cloud chips.
class LibraryPage extends StatefulWidget {
  const LibraryPage({super.key});

  @override
  State<LibraryPage> createState() => _LibraryPageState();
}

class _LibraryPageState extends State<LibraryPage> {
  LibraryChip _chip = LibraryChip.all;
  UserCollections? _collections;
  String? _error;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    app.session.authRevision.addListener(_onAuth);
    unawaited(_load());
  }

  @override
  void dispose() {
    app.session.authRevision.removeListener(_onAuth);
    super.dispose();
  }

  void _onAuth() => unawaited(_load());

  Future<void> _load() async {
    final generation = ++_generation;
    if (!app.session.value.isLoggedIn) {
      setState(() {
        _collections = UserCollections.empty;
        _error = null;
      });
      return;
    }
    setState(() => _error = null);
    try {
      final collections = await app.library.userCollections();
      if (!mounted || generation != _generation) return;
      setState(() => _collections = collections);
    } on Object catch (error) {
      if (!mounted || generation != _generation) return;
      setState(() => _error = describeError(error));
    }
  }

  Future<void> _refresh() async {
    app.library.clearCaches();
    await Future.wait([_load(), app.library.refreshLikedIds()]);
  }

  Future<void> _create() async {
    if (!app.session.value.isLoggedIn) {
      showToast(context, '登录后才能新建歌单');
      return;
    }
    final playlist = await showCreatePlaylistDialog(context);
    if (playlist == null || !mounted) return;
    showToast(context, '已创建「${playlist.name}」');
    await _load();
  }

  void _menu() {
    unawaited(
      showActionSheet(
        context,
        title: '我的音乐',
        actions: [
          SheetAction(
            icon: Icons.add_rounded,
            label: '新建歌单',
            onSelected: _create,
          ),
          SheetAction(
            icon: Icons.refresh_rounded,
            label: '刷新',
            onSelected: () => unawaited(_refresh()),
          ),
          SheetAction(
            icon: Icons.history_rounded,
            label: '播放历史',
            onSelected: () => openHistory(context),
          ),
        ],
      ),
    );
  }

  void _manage(Playlist playlist) {
    final own = playlist.isMine(app.session.value.profile?.id);
    unawaited(
      showActionSheet(
        context,
        title: playlist.name,
        actions: [
          if (own && !playlist.isLikedSongs)
            SheetAction(
              icon: Icons.delete_outline_rounded,
              label: '删除歌单',
              destructive: true,
              onSelected: () => _delete(playlist),
            ),
          if (!own)
            SheetAction(
              icon: Icons.heart_broken_outlined,
              label: '取消收藏',
              destructive: true,
              onSelected: () => _unsubscribe(playlist),
            ),
        ],
      ),
    );
  }

  Future<void> _delete(Playlist playlist) async {
    final confirmed = await showConfirmDialog(
      context,
      title: '删除歌单',
      message: '确定删除「${playlist.name}」吗？此操作无法撤销。',
      confirmLabel: '删除',
      destructive: true,
    );
    if (!confirmed || !mounted) return;
    await _mutate(() => app.library.deletePlaylist(playlist.id), done: '已删除歌单');
  }

  Future<void> _unsubscribe(Playlist playlist) => _mutate(
    () => app.library.subscribePlaylist(playlist.id, subscribe: false),
    done: '已取消收藏',
  );

  Future<void> _mutate(
    Future<void> Function() action, {
    required String done,
  }) async {
    try {
      await action();
      if (!mounted) return;
      showToast(context, done);
      await _load();
    } on Object catch (error) {
      if (mounted) showToast(context, describeError(error));
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        SizedBox(height: top),
        ContentBox(
          child: PageHeader(
            title: '我的音乐',
            actions: [
              RoundIconButton(
                icon: Icons.more_horiz_rounded,
                tooltip: '更多',
                onPressed: _menu,
              ),
            ],
          ),
        ),
        ContentBox(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: ChipBar<LibraryChip>(
            values: LibraryChip.values,
            selected: _chip,
            labelOf: (chip) => chip.label,
            onSelected: (chip) => setState(() => _chip = chip),
          ),
        ),
        Expanded(
          child: ValueListenableBuilder(
            valueListenable: app.session,
            builder: (context, session, _) => AnimatedSwitcher(
              duration: AppMotion.standard,
              switchInCurve: AppMotion.enter,
              switchOutCurve: AppMotion.exit,
              transitionBuilder: fadeThroughTransition,
              layoutBuilder: topStackLayout,
              child: KeyedSubtree(
                key: ValueKey('${_chip.name}-${session.isLoggedIn}'),
                child: _content(session.isLoggedIn),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _content(bool loggedIn) {
    if (_chip.needsAccount && !loggedIn) {
      return ListView(
        padding: EdgeInsets.only(top: 8, bottom: shellBottomInset(context)),
        children: const [
          ContentBox(child: SignInCard(message: '登录后查看你创建和收藏的歌单、喜欢的歌曲')),
          SizedBox(height: 18),
          ContentBox(
            padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
            child: LibraryShortcuts(),
          ),
        ],
      );
    }
    switch (_chip) {
      case LibraryChip.local:
        return SummaryChipView(
          card: ValueListenableBuilder<List<Song>>(
            valueListenable: app.localLibrary.songs,
            builder: (context, songs, _) => EntryCard(
              icon: Icons.folder_open_rounded,
              title: '本地音乐',
              subtitle: songs.isEmpty
                  ? '导入或扫描设备里的音乐文件'
                  : '${songs.length} 首本地歌曲',
              tint: context.surfaces.peach,
              onTap: () => openLocalMusic(context),
            ),
          ),
        );
      case LibraryChip.recent:
        return ValueListenableBuilder<List<Song>>(
          valueListenable: app.recent.tracks,
          builder: (context, tracks, _) => tracks.isEmpty
              ? const EmptyView(message: '还没有播放记录', icon: Icons.history_rounded)
              : SongListView(
                  songs: tracks,
                  title: '最近播放',
                  footer: Center(
                    child: TextButton(
                      onPressed: () => openHistory(context),
                      child: const Text('查看全部播放历史'),
                    ),
                  ),
                ),
        );
      case LibraryChip.all:
      case LibraryChip.created:
      case LibraryChip.collected:
      case LibraryChip.liked:
        return _cloud();
    }
  }

  Widget _cloud() {
    final collections = _collections;
    if (collections == null && _error == null) {
      return const ContentBox(
        padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
        child: MediaRowSkeletonList(count: 7),
      );
    }
    if (collections == null) {
      return ErrorView(message: _error!, onRetry: _load);
    }
    switch (_chip) {
      case LibraryChip.created:
        return PlaylistGroupView(
          playlists: collections.created,
          onRefresh: _refresh,
          onManage: _manage,
          onCreate: _create,
          emptyMessage: '还没有创建歌单',
        );
      case LibraryChip.collected:
        return PlaylistGroupView(
          playlists: collections.collected,
          onRefresh: _refresh,
          onManage: _manage,
          emptyMessage: '还没有收藏歌单',
        );
      case LibraryChip.liked:
        return LikedSongsView(liked: collections.liked, onRefresh: _refresh);
      default:
        return LibraryOverview(
          collections: collections,
          onRefresh: _refresh,
          onManage: _manage,
          onCreate: _create,
        );
    }
  }
}
