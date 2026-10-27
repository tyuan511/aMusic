import 'package:flutter/material.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../services/app.dart';
import '../../services/download_service.dart';
import '../../theme/app_theme.dart';
import '../shell.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';

enum _Tab {
  active('下载中'),
  done('已完成');

  const _Tab(this.label);

  final String label;
}

/// 下载管理. Download queue and finished files.
class DownloadsPage extends StatefulWidget {
  const DownloadsPage({super.key});

  @override
  State<DownloadsPage> createState() => _DownloadsPageState();
}

class _DownloadsPageState extends State<DownloadsPage> {
  _Tab _tab = _Tab.active;
  bool _tabPicked = false;

  void _toast(String message) => ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));

  Future<void> _openFolder() async {
    final ok = await app.downloads.openFolder();
    if (!ok && mounted) {
      final dir = await app.downloads.downloadDirectory();
      _toast('下载目录：${dir.path}');
    }
  }

  Future<void> _clearFinished() async {
    var deleteFiles = false;
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocal) => AlertDialog(
          title: const Text('清空已完成'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('从列表中移除所有已完成的下载。'),
              const SizedBox(height: 8),
              CheckboxListTile(
                value: deleteFiles,
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                title: const Text('同时删除文件'),
                onChanged: (v) => setLocal(() => deleteFiles = v ?? false),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('清空'),
            ),
          ],
        ),
      ),
    );
    if (ok != true) return;
    await app.downloads.clearFinished(deleteFiles: deleteFiles);
    if (mounted) _toast(deleteFiles ? '已清空并删除文件' : '已清空列表');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: app.downloads,
      builder: (context, _) {
        final downloads = app.downloads;
        final tasks = downloads.tasks;
        final finished = downloads.finished;
        // Land on 已完成 when nothing is downloading, until the user picks.
        final tab = _tabPicked || tasks.isNotEmpty || finished.isEmpty
            ? _tab
            : _Tab.done;
        return Column(
          children: [
            PageHeader(
              title: '下载管理',
              actions: [
                if (Platforms.isDesktop)
                  RoundIconButton(
                    icon: Icons.folder_open_rounded,
                    tooltip: '打开下载目录',
                    onPressed: _openFolder,
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 4, bottom: 10),
              child: ChipBar<_Tab>(
                values: _Tab.values,
                selected: tab,
                labelOf: (t) {
                  final count = t == _Tab.active
                      ? tasks.length
                      : finished.length;
                  return count == 0 ? t.label : '${t.label} $count';
                },
                onSelected: (t) => setState(() {
                  _tab = t;
                  _tabPicked = true;
                }),
              ),
            ),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.standard,
                switchInCurve: AppMotion.enter,
                child: KeyedSubtree(
                  key: ValueKey(tab),
                  child: tab == _Tab.active
                      ? _ActiveList(tasks: tasks)
                      : _DoneList(
                          records: finished,
                          onClear: _clearFinished,
                          onToast: _toast,
                        ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}

// ------------------------------------------------------------------ active

class _ActiveList extends StatelessWidget {
  const _ActiveList({required this.tasks});

  final List<DownloadTask> tasks;

  @override
  Widget build(BuildContext context) {
    if (tasks.isEmpty) {
      return const _Empty(
        icon: Icons.downloading_rounded,
        title: '没有进行中的下载',
        subtitle: '在歌曲、歌单或专辑的菜单里选择「下载」',
      );
    }
    final running = tasks
        .where((t) => t.status == DownloadStatus.downloading)
        .length;
    final queued = tasks.where((t) => t.status == DownloadStatus.queued).length;
    final failed = tasks.length - running - queued;
    return ListView(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.gutter - 10,
        0,
        AppMetrics.gutter - 10,
        ShellLayout.bottomInsetOf(context),
      ),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 8),
          child: Row(
            children: [
              Expanded(
                child: DotSeparated(
                  parts: [
                    if (running > 0) '$running 首下载中',
                    if (queued > 0) '$queued 首等待',
                    if (failed > 0) '$failed 首未完成',
                  ],
                ),
              ),
              if (failed > 0) ...[
                PillChip(
                  label: '全部重试',
                  icon: Icons.refresh_rounded,
                  selected: false,
                  dense: true,
                  onTap: app.downloads.retryAllFailed,
                ),
                const SizedBox(width: 8),
                PillChip(
                  label: '清除',
                  selected: false,
                  dense: true,
                  onTap: app.downloads.clearInactive,
                ),
              ],
            ],
          ),
        ),
        for (var i = 0; i < tasks.length; i++)
          EntranceFade(
            key: ValueKey(tasks[i].songId),
            index: i,
            child: _TaskRow(task: tasks[i]),
          ),
      ],
    );
  }
}

class _TaskRow extends StatelessWidget {
  const _TaskRow({required this.task});

  final DownloadTask task;

  String _status() {
    switch (task.status) {
      case DownloadStatus.downloading:
        final total = task.total;
        if (total <= 0) return '连接中…';
        final percent = (task.received * 100 / total).floor();
        return '$percent%  ·  ${_bytes(task.received)} / ${_bytes(total)}';
      case DownloadStatus.queued:
        return task.received > 0 ? '等待续传' : '等待中';
      case DownloadStatus.failed:
        return task.error ?? '下载失败';
      case DownloadStatus.canceled:
        return '已取消';
      case DownloadStatus.done:
        return '已完成';
    }
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final song = task.song;
    final failed = task.status == DownloadStatus.failed;
    final row = MediaRow(
      title: song.displayTitle,
      leading: _ProgressCover(task: task),
      badges: [
        if (task.level != null) TagBadge(task.level!.label, color: s.lavender),
        if (task.downgraded) TagBadge('降级', color: s.peach),
      ],
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (task.isActive)
            RoundIconButton(
              icon: Icons.close_rounded,
              tooltip: '取消',
              size: 38,
              onPressed: () => app.downloads.cancel(task.songId),
            )
          else ...[
            RoundIconButton(
              icon: Icons.refresh_rounded,
              tooltip: '重试',
              size: 38,
              active: failed,
              onPressed: () => app.downloads.retry(task.songId),
            ),
            const SizedBox(width: 8),
            RoundIconButton(
              icon: Icons.delete_outline_rounded,
              tooltip: '移除',
              size: 38,
              onPressed: () => app.downloads.remove(task.songId),
            ),
          ],
        ],
      ),
      subtitle: song.artistText,
      onTap: failed ? () => app.downloads.retry(task.songId) : null,
    );
    final status = _status();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        row,
        Padding(
          padding: const EdgeInsets.fromLTRB(84, 0, 10, 6),
          child: AnimatedSwitcher(
            duration: AppMotion.quick,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.centerLeft,
              children: [...previous, ?current],
            ),
            child: Text(
              status,
              // Only re-animate on status changes, not on every byte.
              key: ValueKey(status.contains('%') ? 'progress' : status),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(
                color: failed ? context.colors.error : s.textTertiary,
                fontFeatures: const [FontFeature.tabularFigures()],
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Cover with an animated progress ring around it.
class _ProgressCover extends StatelessWidget {
  const _ProgressCover({required this.task});

  final DownloadTask task;

  static const double _size = 58;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final fraction = task.fraction;
    final downloading = task.status == DownloadStatus.downloading;
    final failed = task.status == DownloadStatus.failed;
    return SizedBox(
      width: _size,
      height: _size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Padding(
            padding: const EdgeInsets.all(6),
            child: AnimatedOpacity(
              duration: AppMotion.standard,
              opacity: downloading ? 1 : 0.55,
              child: CoverImage(
                url: task.song.album.picUrl,
                size: 140,
                width: _size - 12,
                height: _size - 12,
                radius: (_size - 12) / 2,
              ),
            ),
          ),
          TweenAnimationBuilder<double>(
            tween: Tween(end: fraction ?? 0),
            duration: AppMotion.emphasized,
            curve: AppMotion.enter,
            builder: (context, value, _) => SizedBox(
              width: _size,
              height: _size,
              child: CircularProgressIndicator(
                value: downloading && fraction == null ? null : value,
                strokeWidth: 3,
                strokeCap: StrokeCap.round,
                backgroundColor: s.chip,
                color: failed ? context.colors.error : s.lime,
              ),
            ),
          ),
          AnimatedSwitcher(
            duration: AppMotion.quick,
            transitionBuilder: (child, animation) =>
                ScaleTransition(scale: animation, child: child),
            child: switch (task.status) {
              DownloadStatus.queued => _Glyph(
                key: const ValueKey('queued'),
                icon: Icons.schedule_rounded,
                color: s.textSecondary,
              ),
              DownloadStatus.failed => _Glyph(
                key: const ValueKey('failed'),
                icon: Icons.error_outline_rounded,
                color: context.colors.error,
              ),
              DownloadStatus.canceled => _Glyph(
                key: const ValueKey('canceled'),
                icon: Icons.block_rounded,
                color: s.textSecondary,
              ),
              _ => const SizedBox.shrink(key: ValueKey('none')),
            },
          ),
        ],
      ),
    );
  }
}

class _Glyph extends StatelessWidget {
  const _Glyph({super.key, required this.icon, required this.color});

  final IconData icon;
  final Color color;

  @override
  Widget build(BuildContext context) => Container(
    width: 26,
    height: 26,
    decoration: BoxDecoration(
      color: context.surfaces.card.withValues(alpha: 0.85),
      shape: BoxShape.circle,
    ),
    child: Icon(icon, size: 16, color: color),
  );
}

// -------------------------------------------------------------------- done

class _DoneList extends StatelessWidget {
  const _DoneList({
    required this.records,
    required this.onClear,
    required this.onToast,
  });

  final List<DownloadRecord> records;
  final VoidCallback onClear;
  final ValueChanged<String> onToast;

  @override
  Widget build(BuildContext context) {
    if (records.isEmpty) {
      return const _Empty(
        icon: Icons.library_music_outlined,
        title: '还没有下载的歌曲',
        subtitle: '下载后可离线播放，文件带有封面与歌词标签',
      );
    }
    final songs = [for (final r in records) r.song];
    final total = records.fold<int>(0, (sum, r) => sum + r.size);
    return ListenableBuilder(
      listenable: app.player.currentSongId,
      builder: (context, _) {
        final current = app.player.currentSongId.value;
        return ListView(
          padding: EdgeInsets.fromLTRB(
            AppMetrics.gutter - 10,
            0,
            AppMetrics.gutter - 10,
            ShellLayout.bottomInsetOf(context),
          ),
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(10, 0, 10, 10),
              child: Row(
                children: [
                  AccentPlayButton(
                    playing: false,
                    size: 52,
                    onPressed: () =>
                        app.player.playSongs(songs, sourceTitle: '下载管理'),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '播放全部',
                          style: context.text.titleSmall?.copyWith(
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 3),
                        DotSeparated(
                          parts: ['${records.length} 首', _bytes(total)],
                        ),
                      ],
                    ),
                  ),
                  PillChip(
                    label: '清空',
                    icon: Icons.delete_sweep_rounded,
                    selected: false,
                    dense: true,
                    onTap: onClear,
                  ),
                ],
              ),
            ),
            for (var i = 0; i < records.length; i++)
              EntranceFade(
                key: ValueKey(records[i].song.id),
                index: i,
                child: _DoneRow(
                  record: records[i],
                  highlighted: current == records[i].song.id,
                  onPlay: () => app.player.playSongs(
                    songs,
                    index: i,
                    sourceTitle: '下载管理',
                  ),
                  onToast: onToast,
                ),
              ),
          ],
        );
      },
    );
  }
}

class _DoneRow extends StatelessWidget {
  const _DoneRow({
    required this.record,
    required this.highlighted,
    required this.onPlay,
    required this.onToast,
  });

  final DownloadRecord record;
  final bool highlighted;
  final VoidCallback onPlay;
  final ValueChanged<String> onToast;

  Future<void> _delete(BuildContext context) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除文件'),
        content: Text('确定删除「${record.song.name}」的本地文件？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await app.downloads.remove(record.song.id, deleteFile: true);
    onToast('已删除');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final song = record.song;
    return MediaRow(
      title: song.displayTitle,
      subtitle: song.artistText,
      meta: [
        if (song.duration > Duration.zero) song.duration.clock,
        _bytes(record.size),
      ].join('  ·  '),
      coverUrl: song.album.picUrl,
      highlighted: highlighted,
      onTap: onPlay,
      badges: [
        if (record.level != null)
          TagBadge(record.level!.label, color: s.lavender),
        if (record.downgraded) TagBadge('降级', color: s.peach),
      ],
      trailing: MenuAnchor(
        menuChildren: [
          MenuItemButton(
            leadingIcon: const Icon(Icons.play_arrow_rounded, size: 18),
            onPressed: onPlay,
            child: const Text('播放'),
          ),
          if (Platforms.isDesktop)
            MenuItemButton(
              leadingIcon: const Icon(Icons.folder_open_rounded, size: 18),
              onPressed: () async {
                final ok = await app.downloads.reveal(song.id);
                if (!ok) onToast(record.path);
              },
              child: const Text('在文件夹中显示'),
            ),
          MenuItemButton(
            leadingIcon: const Icon(Icons.playlist_remove_rounded, size: 18),
            onPressed: () => app.downloads.remove(song.id),
            child: const Text('从列表移除'),
          ),
          MenuItemButton(
            leadingIcon: Icon(
              Icons.delete_outline_rounded,
              size: 18,
              color: context.colors.error,
            ),
            onPressed: () => _delete(context),
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

// ------------------------------------------------------------------ shared

String _bytes(int bytes) {
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

class _Empty extends StatelessWidget {
  const _Empty({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Center(
      child: EntranceFade(
        child: Padding(
          padding: EdgeInsets.only(
            bottom: ShellLayout.bottomInsetOf(context),
            left: 32,
            right: 32,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 84,
                height: 84,
                decoration: BoxDecoration(
                  color: s.chip,
                  shape: BoxShape.circle,
                  boxShadow: [BoxShadow(color: s.glow, blurRadius: 30)],
                ),
                child: Icon(icon, size: 36, color: s.lime),
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
                style: context.text.bodySmall?.copyWith(color: s.textTertiary),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
