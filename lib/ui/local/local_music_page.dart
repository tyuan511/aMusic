import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../local/local_track.dart';
import '../../models/song.dart';
import '../../services/app.dart';
import '../../services/local_library_service.dart';
import '../../theme/app_theme.dart';
import '../shell.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

enum _View {
  songs('歌曲'),
  artists('歌手'),
  albums('专辑');

  const _View(this.label);

  final String label;
}

enum _Sort {
  added('最近添加'),
  title('标题'),
  artist('歌手'),
  duration('时长');

  const _Sort(this.label);

  final String label;
}

/// 本地音乐. Scanned / imported audio files.
class LocalMusicPage extends StatefulWidget {
  const LocalMusicPage({super.key});

  @override
  State<LocalMusicPage> createState() => _LocalMusicPageState();
}

class _LocalMusicPageState extends State<LocalMusicPage> {
  final TextEditingController _filter = TextEditingController();
  _View _view = _View.songs;
  _Sort _sort = _Sort.added;

  /// Artist / album opened from the grouped views.
  String? _group;
  bool _showMissing = false;

  LocalLibraryService get _library => app.localLibrary;

  @override
  void initState() {
    super.initState();
    _filter.addListener(() => setState(() {}));
    // First visit with an empty library: scan right away.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_library.songs.value.isEmpty &&
          _library.missing.value.isEmpty &&
          !_library.isScanning &&
          _library.permission.value != LocalPermission.denied &&
          _library.permission.value != LocalPermission.permanentlyDenied) {
        _library.scan();
      }
    });
  }

  @override
  void dispose() {
    _filter.dispose();
    super.dispose();
  }

  void _toast(String message) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _addFolder() async {
    try {
      await _library.addFolder();
    } on Object catch (error) {
      _toast('无法添加文件夹：$error');
    }
  }

  Future<void> _import() async {
    try {
      final added = await _library.importFiles();
      if (added == 0 && mounted) _toast('没有导入新的歌曲');
    } on Object catch (error) {
      _toast('导入失败：$error');
    }
  }

  List<Song> _filtered(List<Song> songs) {
    final query = _filter.text.trim().toLowerCase();
    Iterable<Song> result = songs;
    if (_group != null) {
      result = result.where(
        (song) => _view == _View.artists
            ? song.artists.any((a) => a.name == _group)
            : song.album.name == _group,
      );
    }
    if (query.isNotEmpty) {
      result = result.where(
        (song) =>
            song.name.toLowerCase().contains(query) ||
            song.artistText.toLowerCase().contains(query) ||
            song.album.name.toLowerCase().contains(query),
      );
    }
    final list = result.toList();
    switch (_sort) {
      case _Sort.added:
        break; // Service order: most recently added first.
      case _Sort.title:
        list.sort(
          (a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()),
        );
      case _Sort.artist:
        list.sort(
          (a, b) =>
              a.artistText.toLowerCase().compareTo(b.artistText.toLowerCase()),
        );
      case _Sort.duration:
        list.sort((a, b) => a.duration.compareTo(b.duration));
    }
    if (_group != null && _view == _View.albums && _sort == _Sort.added) {
      list.sort((a, b) => (a.no ?? 999).compareTo(b.no ?? 999));
    }
    return list;
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        PageHeader(
          title: '本地音乐',
          actions: [
            ValueListenableBuilder<LocalScanState>(
              valueListenable: _library.scanState,
              builder: (context, scan, _) => RoundIconButton(
                icon: Icons.radar_rounded,
                tooltip: '扫描',
                active: scan.scanning,
                onPressed: scan.scanning ? null : _library.scan,
              ),
            ),
            RoundIconButton(
              icon: Icons.create_new_folder_rounded,
              tooltip: '添加文件夹',
              onPressed: _addFolder,
            ),
            RoundIconButton(
              icon: Icons.file_open_rounded,
              tooltip: '导入文件',
              onPressed: _import,
            ),
          ],
        ),
        const _ScanBanner(),
        Expanded(
          child: ValueListenableBuilder<LocalPermission>(
            valueListenable: _library.permission,
            builder: (context, permission, _) =>
                ValueListenableBuilder<List<Song>>(
                  valueListenable: _library.songs,
                  builder: (context, songs, _) =>
                      ValueListenableBuilder<List<LocalTrack>>(
                        valueListenable: _library.missing,
                        builder: (context, missing, _) =>
                            _body(context, permission, songs, missing),
                      ),
                ),
          ),
        ),
      ],
    );
  }

  Widget _body(
    BuildContext context,
    LocalPermission permission,
    List<Song> songs,
    List<LocalTrack> missing,
  ) {
    final denied =
        permission == LocalPermission.denied ||
        permission == LocalPermission.permanentlyDenied;
    if (songs.isEmpty && missing.isEmpty) {
      return AnimatedSwitcher(
        duration: AppMotion.standard,
        child: denied
            ? _PermissionState(
                key: const ValueKey('denied'),
                permanent: permission == LocalPermission.permanentlyDenied,
                onPickFolder: _addFolder,
              )
            : ValueListenableBuilder<LocalScanState>(
                key: const ValueKey('empty'),
                valueListenable: _library.scanState,
                builder: (context, scan, _) => scan.scanning
                    ? const MediaRowSkeletonList(
                        count: 6,
                        padding: EdgeInsets.symmetric(
                          horizontal: AppMetrics.gutter - 10,
                        ),
                      )
                    : _EmptyState(onAddFolder: _addFolder, onImport: _import),
              ),
      );
    }

    final bottom = ShellLayout.bottomInsetOf(context);
    final visible = _filtered(songs);
    final grouping = _view != _View.songs && _group == null;
    return CustomScrollView(
      slivers: [
        if (denied)
          SliverToBoxAdapter(
            child: _PermissionBanner(
              permanent: permission == LocalPermission.permanentlyDenied,
            ),
          ),
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 12),
            child: ChipBar<_View>(
              values: _View.values,
              selected: _view,
              labelOf: (v) => v.label,
              onSelected: (v) => setState(() {
                _view = v;
                _group = null;
              }),
            ),
          ),
        ),
        SliverToBoxAdapter(child: _toolbar(context, songs, visible, grouping)),
        if (grouping)
          _GroupSliver(
            songs: visible,
            byArtist: _view == _View.artists,
            onOpen: (name) => setState(() => _group = name),
          )
        else if (visible.isEmpty)
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(40),
              child: Center(
                child: Text(
                  '没有匹配的歌曲',
                  style: context.text.bodyMedium?.copyWith(
                    color: context.surfaces.textTertiary,
                  ),
                ),
              ),
            ),
          )
        else
          _SongSliver(songs: visible, onToast: _toast),
        if (missing.isNotEmpty)
          SliverToBoxAdapter(
            child: _MissingSection(
              missing: missing,
              expanded: _showMissing,
              onToggle: () => setState(() => _showMissing = !_showMissing),
              onCleanup: () async {
                final removed = await _library.cleanupMissing();
                _toast('已清理 $removed 首');
              },
            ),
          ),
        SliverToBoxAdapter(child: _FoldersSection(onAdd: _addFolder)),
        SliverToBoxAdapter(child: SizedBox(height: bottom)),
      ],
    );
  }

  Widget _toolbar(
    BuildContext context,
    List<Song> all,
    List<Song> visible,
    bool grouping,
  ) {
    final s = context.surfaces;
    final total = visible.fold<Duration>(
      Duration.zero,
      (sum, song) => sum + song.duration,
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        0,
        AppMetrics.gutter,
        10,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 44,
                  child: TextField(
                    controller: _filter,
                    textInputAction: TextInputAction.search,
                    decoration: InputDecoration(
                      hintText: '筛选歌曲、歌手、专辑',
                      prefixIcon: Icon(
                        Icons.search_rounded,
                        size: 20,
                        color: s.textSecondary,
                      ),
                      suffixIcon: _filter.text.isEmpty
                          ? null
                          : IconButton(
                              tooltip: '清除',
                              icon: const Icon(Icons.close_rounded, size: 18),
                              onPressed: _filter.clear,
                            ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(
                          AppMetrics.radiusPill,
                        ),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 10),
              MenuAnchor(
                menuChildren: [
                  for (final sort in _Sort.values)
                    MenuItemButton(
                      leadingIcon: AnimatedOpacity(
                        duration: AppMotion.quick,
                        opacity: sort == _sort ? 1 : 0,
                        child: Icon(
                          Icons.check_rounded,
                          size: 18,
                          color: s.lime,
                        ),
                      ),
                      onPressed: () => setState(() => _sort = sort),
                      child: Text(sort.label),
                    ),
                ],
                builder: (context, controller, _) => RoundIconButton(
                  icon: Icons.sort_rounded,
                  tooltip: '排序：${_sort.label}',
                  size: 44,
                  onPressed: () => controller.isOpen
                      ? controller.close()
                      : controller.open(),
                ),
              ),
            ],
          ),
          if (!grouping) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                AccentPlayButton(
                  playing: false,
                  size: 48,
                  onPressed: visible.isEmpty
                      ? null
                      : () => app.player.playSongs(
                          visible,
                          sourceTitle: _group ?? '本地音乐',
                        ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: AppMotion.quick,
                        child: Text(
                          _group ?? '播放全部',
                          key: ValueKey(_group),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                      const SizedBox(height: 3),
                      DotSeparated(
                        parts: [
                          '${visible.length} 首',
                          if (total > Duration.zero) total.clock,
                        ],
                      ),
                    ],
                  ),
                ),
                if (_group != null)
                  PillChip(
                    label: '返回${_view.label}',
                    icon: Icons.arrow_back_rounded,
                    selected: false,
                    dense: true,
                    onTap: () => setState(() => _group = null),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

// --------------------------------------------------------------- scan state

class _ScanBanner extends StatelessWidget {
  const _ScanBanner();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder<LocalScanState>(
      valueListenable: app.localLibrary.scanState,
      builder: (context, scan, _) {
        final visible = scan.scanning || scan.message != null;
        return AnimatedSize(
          duration: AppMotion.standard,
          curve: AppMotion.enter,
          child: !visible
              ? const SizedBox(width: double.infinity)
              : Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppMetrics.gutter,
                    0,
                    AppMetrics.gutter,
                    10,
                  ),
                  child: AnimatedContainer(
                    duration: AppMotion.standard,
                    padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
                    decoration: BoxDecoration(
                      color: scan.scanning
                          ? s.lime.withValues(alpha: 0.12)
                          : s.card,
                      borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
                      border: Border.all(color: s.hairline),
                    ),
                    child: Row(
                      children: [
                        AnimatedSwitcher(
                          duration: AppMotion.quick,
                          child: scan.scanning
                              ? SizedBox(
                                  key: const ValueKey('spin'),
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: s.lime,
                                  ),
                                )
                              : Icon(
                                  Icons.check_circle_rounded,
                                  key: const ValueKey('done'),
                                  size: 20,
                                  color: s.lime,
                                ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                scan.scanning
                                    ? '正在扫描… 已找到 ${scan.found} 首'
                                    : scan.message!,
                                style: context.text.bodyMedium?.copyWith(
                                  fontWeight: FontWeight.w500,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                              ),
                              if (scan.scanning && scan.current != null) ...[
                                const SizedBox(height: 2),
                                Text(
                                  scan.current!,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: context.text.bodySmall?.copyWith(
                                    color: s.textTertiary,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ),
                        if (scan.scanning)
                          TextButton(
                            onPressed: app.localLibrary.cancelScan,
                            child: const Text('取消'),
                          ),
                      ],
                    ),
                  ),
                ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- lists

class _SongSliver extends StatelessWidget {
  const _SongSliver({required this.songs, required this.onToast});

  final List<Song> songs;
  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
      sliver: ValueListenableBuilder<int?>(
        valueListenable: app.player.currentSongId,
        builder: (context, current, _) => SliverList.builder(
          itemCount: songs.length,
          itemBuilder: (context, index) => EntranceFade(
            key: ValueKey(songs[index].id),
            index: index,
            child: _LocalSongRow(
              song: songs[index],
              highlighted: current == songs[index].id,
              onPlay: () => app.player.playSongs(
                songs,
                index: index,
                sourceTitle: '本地音乐',
              ),
              onToast: onToast,
            ),
          ),
        ),
      ),
    );
  }
}

class _LocalSongRow extends StatelessWidget {
  const _LocalSongRow({
    required this.song,
    required this.highlighted,
    required this.onPlay,
    required this.onToast,
  });

  final Song song;
  final bool highlighted;
  final VoidCallback onPlay;
  final ValueChanged<String> onToast;

  Future<void> _confirmDelete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('将从磁盘永久删除「${song.name}」，无法恢复。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: context.colors.error,
              foregroundColor: context.colors.onError,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await app.localLibrary.deleteFile(song.id);
      onToast('已删除文件');
    } on Object catch (error) {
      onToast('删除失败：$error');
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final track = app.localLibrary.trackFor(song.id);
    return MediaRow(
      title: song.name,
      subtitle: song.artistText,
      meta: [
        if (song.album.name.isNotEmpty) song.album.name,
        if (song.duration > Duration.zero) song.duration.clock,
      ].join('  ·  '),
      coverUrl: song.album.picUrl,
      highlighted: highlighted,
      onTap: onPlay,
      badges: [
        if (track != null && track.format.isNotEmpty)
          TagBadge(
            track.format.toUpperCase(),
            color: track.format == 'flac' || track.format == 'wav'
                ? s.lime
                : s.textTertiary,
          ),
      ],
      trailing: MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.play_arrow_rounded, size: 18),
            onPressed: onPlay,
            child: const Text('播放'),
          ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.queue_music_rounded, size: 18),
            onPressed: () => app.player.playNext(song),
            child: const Text('下一首播放'),
          ),
          if (Platforms.isDesktop)
            MenuItemButton(
              leadingIcon: const Icon(Icons.folder_open_rounded, size: 18),
              onPressed: () async {
                final ok = await app.localLibrary.showInFolder(song.id);
                if (!ok && track != null) onToast(track.path);
              },
              child: const Text('在文件夹中显示'),
            ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.playlist_remove_rounded, size: 18),
            onPressed: () async {
              await app.localLibrary.remove(song.id);
              onToast('已从本地音乐移除');
            },
            child: const Text('从列表移除'),
          ),
          MenuItemButton(
            leadingIcon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: context.colors.error,
            ),
            onPressed: () => _confirmDelete(context),
            child: Text('删除文件', style: TextStyle(color: context.colors.error)),
          ),
        ],
        builder: (context, controller, _) => RoundIconButton(
          icon: Icons.more_horiz_rounded,
          tooltip: '更多',
          size: 38,
          onPressed: () =>
              controller.isOpen ? controller.close() : controller.open(),
        ),
      ),
    );
  }
}

class _GroupSliver extends StatelessWidget {
  const _GroupSliver({
    required this.songs,
    required this.byArtist,
    required this.onOpen,
  });

  final List<Song> songs;
  final bool byArtist;
  final ValueChanged<String> onOpen;

  @override
  Widget build(BuildContext context) {
    final groups = <String, List<Song>>{};
    for (final song in songs) {
      if (byArtist) {
        for (final artist in song.artists) {
          groups.putIfAbsent(artist.name, () => []).add(song);
        }
      } else {
        groups.putIfAbsent(song.album.name, () => []).add(song);
      }
    }
    final names = groups.keys.toList()
      ..sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    if (names.isEmpty) {
      return const SliverToBoxAdapter(child: SizedBox.shrink());
    }
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
      sliver: SliverList.builder(
        itemCount: names.length,
        itemBuilder: (context, index) {
          final name = names[index];
          final items = groups[name]!;
          final cover = items
              .map((s) => s.album.picUrl)
              .firstWhere((url) => url != null, orElse: () => null);
          return EntranceFade(
            key: ValueKey('$byArtist$name'),
            index: index,
            child: MediaRow(
              title: name,
              subtitle: byArtist ? '歌手' : items.first.artistText,
              meta: '${items.length} 首',
              coverUrl: cover,
              circleCover: byArtist,
              onTap: () => onOpen(name),
              trailing: RowPlayButton(
                onPressed: () => app.player.playSongs(items, sourceTitle: name),
              ),
            ),
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------- missing files

class _MissingSection extends StatelessWidget {
  const _MissingSection({
    required this.missing,
    required this.expanded,
    required this.onToggle,
    required this.onCleanup,
  });

  final List<LocalTrack> missing;
  final bool expanded;
  final VoidCallback onToggle;
  final VoidCallback onCleanup;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        18,
        AppMetrics.gutter,
        0,
      ),
      child: Container(
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
          border: Border.all(color: s.peach.withValues(alpha: 0.35)),
        ),
        child: Column(
          children: [
            Pressable(
              onTap: onToggle,
              pressedScale: 0.99,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 10, 12),
                child: Row(
                  children: [
                    Icon(Icons.link_off_rounded, size: 20, color: s.peach),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        '${missing.length} 首歌曲的文件已不存在',
                        style: context.text.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    PillChip(
                      label: '清理',
                      selected: false,
                      dense: true,
                      onTap: onCleanup,
                    ),
                    AnimatedRotation(
                      turns: expanded ? 0.5 : 0,
                      duration: AppMotion.standard,
                      child: Icon(
                        Icons.expand_more_rounded,
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ),
            AnimatedSize(
              duration: AppMotion.standard,
              curve: AppMotion.enter,
              alignment: Alignment.topCenter,
              child: !expanded
                  ? const SizedBox(width: double.infinity)
                  : Padding(
                      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          for (final track in missing.take(50))
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 4),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${track.artist} - ${track.title}',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodySmall,
                                  ),
                                  Text(
                                    track.path,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: context.text.bodySmall?.copyWith(
                                      color: s.textTertiary,
                                      fontSize: 11,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          if (missing.length > 50)
                            Text(
                              '… 另有 ${missing.length - 50} 首',
                              style: context.text.bodySmall?.copyWith(
                                color: s.textTertiary,
                              ),
                            ),
                        ],
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- folders

class _FoldersSection extends StatelessWidget {
  const _FoldersSection({required this.onAdd});

  final VoidCallback onAdd;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ListenableBuilder(
      listenable: app.localLibrary,
      builder: (context, _) {
        final library = app.localLibrary;
        final folders = library.folders;
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            24,
            AppMetrics.gutter,
            8,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '扫描范围',
                style: context.text.titleSmall?.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  PillChip(
                    label: '系统音乐文件夹',
                    icon: library.scansDefaultFolders
                        ? Icons.check_rounded
                        : Icons.add_rounded,
                    selected: library.scansDefaultFolders,
                    dense: true,
                    onTap: () async {
                      await library.setScansDefaultFolders(
                        !library.scansDefaultFolders,
                      );
                      await library.scan();
                    },
                  ),
                  for (final folder in folders)
                    _FolderChip(
                      folder: folder,
                      onRemove: () => library.removeFolder(folder),
                    ),
                  RoundIconButton(
                    icon: Icons.add_rounded,
                    tooltip: '添加文件夹',
                    size: 36,
                    onPressed: onAdd,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                '支持 MP3、FLAC、M4A、AAC、OGG、Opus、WAV',
                style: context.text.bodySmall?.copyWith(color: s.textTertiary),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _FolderChip extends StatelessWidget {
  const _FolderChip({required this.folder, required this.onRemove});

  final String folder;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final name = folder
        .replaceAll('\\', '/')
        .split('/')
        .lastWhere((part) => part.isNotEmpty, orElse: () => folder);
    return Tooltip(
      message: folder,
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 4, 4, 4),
        decoration: BoxDecoration(
          color: s.chip,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.folder_rounded, size: 15, color: s.lime),
            const SizedBox(width: 6),
            Text(name, style: context.text.labelLarge),
            const SizedBox(width: 2),
            IconButton(
              tooltip: '移除',
              visualDensity: VisualDensity.compact,
              iconSize: 16,
              onPressed: onRemove,
              icon: Icon(Icons.close_rounded, color: s.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

// ------------------------------------------------------------ empty states

class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.onAddFolder, required this.onImport});

  final VoidCallback onAddFolder;
  final VoidCallback onImport;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.library_music_rounded,
      title: '还没有本地音乐',
      subtitle: '扫描系统音乐文件夹，或添加存放歌曲的文件夹',
      actions: [
        FilledButton.icon(
          onPressed: app.localLibrary.scan,
          icon: const Icon(Icons.radar_rounded, size: 18),
          label: const Text('扫描'),
        ),
        OutlinedButton.icon(
          onPressed: onAddFolder,
          icon: const Icon(Icons.create_new_folder_rounded, size: 18),
          label: const Text('添加文件夹'),
        ),
        OutlinedButton.icon(
          onPressed: onImport,
          icon: const Icon(Icons.file_open_rounded, size: 18),
          label: const Text('导入文件'),
        ),
      ],
    );
  }
}

class _PermissionState extends StatelessWidget {
  const _PermissionState({
    super.key,
    required this.permanent,
    required this.onPickFolder,
  });

  final bool permanent;
  final VoidCallback onPickFolder;

  @override
  Widget build(BuildContext context) {
    return _CenteredMessage(
      icon: Icons.lock_outline_rounded,
      title: '需要读取音乐的权限',
      subtitle: permanent
          ? '权限已被拒绝，请在系统设置中允许访问音乐和音频，或者手动选择文件夹'
          : '允许访问音乐和音频后才能扫描本机歌曲，也可以手动选择文件夹',
      actions: [
        FilledButton.icon(
          onPressed: () async {
            if (permanent) {
              await app.localLibrary.openPermissionSettings();
              return;
            }
            if (await app.localLibrary.requestPermission()) {
              await app.localLibrary.scan();
            }
          },
          icon: Icon(
            permanent ? Icons.settings_rounded : Icons.refresh_rounded,
            size: 18,
          ),
          label: Text(permanent ? '打开设置' : '重新授权'),
        ),
        OutlinedButton.icon(
          onPressed: onPickFolder,
          icon: const Icon(Icons.folder_open_rounded, size: 18),
          label: const Text('选择文件夹'),
        ),
      ],
    );
  }
}

class _PermissionBanner extends StatelessWidget {
  const _PermissionBanner({required this.permanent});

  final bool permanent;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        0,
        AppMetrics.gutter,
        8,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        decoration: BoxDecoration(
          color: s.peach.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.lock_outline_rounded, size: 18, color: s.peach),
            const SizedBox(width: 10),
            const Expanded(child: Text('未授予音乐权限，系统音乐文件夹无法扫描')),
            TextButton(
              onPressed: () async {
                if (permanent) {
                  await app.localLibrary.openPermissionSettings();
                } else if (await app.localLibrary.requestPermission()) {
                  await app.localLibrary.scan();
                }
              },
              child: Text(permanent ? '打开设置' : '授权'),
            ),
          ],
        ),
      ),
    );
  }
}

class _CenteredMessage extends StatelessWidget {
  const _CenteredMessage({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.actions,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final List<Widget> actions;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Center(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          32,
          24,
          32,
          ShellLayout.bottomInsetOf(context),
        ),
        child: EntranceFade(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 420),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: s.chip,
                    shape: BoxShape.circle,
                    boxShadow: [BoxShadow(color: s.glow, blurRadius: 32)],
                  ),
                  child: Icon(icon, size: 38, color: s.lime),
                ),
                const SizedBox(height: 18),
                Text(
                  title,
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: context.text.bodySmall?.copyWith(
                    color: s.textTertiary,
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 20),
                Wrap(
                  alignment: WrapAlignment.center,
                  spacing: 10,
                  runSpacing: 10,
                  children: actions,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
