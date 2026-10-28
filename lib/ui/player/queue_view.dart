import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/song.dart';
import '../../services/app.dart';
import '../../services/player_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import '../widgets/playing_indicator.dart';
import '../widgets/song_menu.dart';

/// The play queue: drag to reorder, swipe to remove, tap to play. Scrolls
/// to the current track when opened.
class QueueView extends StatefulWidget {
  const QueueView({super.key, this.embedded = false});

  /// Transparent, for the now playing side panel.
  final bool embedded;

  static const double rowExtent = 64;

  @override
  State<QueueView> createState() => _QueueViewState();
}

class _QueueViewState extends State<QueueView> {
  final ScrollController _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _scrollToCurrent());
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _scrollToCurrent() {
    if (!mounted || !_scroll.hasClients) return;
    final index = app.player.queue.value.index;
    final viewport = _scroll.position.viewportDimension;
    final target =
        (index * QueueView.rowExtent - viewport / 2 + QueueView.rowExtent / 2)
            .clamp(0.0, _scroll.position.maxScrollExtent);
    _scroll.animateTo(target, duration: AppMotion.page, curve: AppMotion.enter);
  }

  Future<void> _confirmClear() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清空播放队列？'),
        content: const Text('队列中的歌曲会被移除，当前播放会停止。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('清空'),
          ),
        ],
      ),
    );
    if (ok ?? false) await app.player.clearQueue();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.queue,
      builder: (context, queue, _) {
        return Column(
          children: [
            _Header(queue: queue, onClear: _confirmClear),
            Expanded(
              child: AnimatedSwitcher(
                duration: AppMotion.standard,
                child: queue.isEmpty
                    ? const _EmptyQueue()
                    : _QueueList(queue: queue, controller: _scroll),
              ),
            ),
          ],
        );
      },
    );
  }
}

class _Header extends StatelessWidget {
  const _Header({required this.queue, required this.onClear});

  final PlayQueue queue;
  final VoidCallback onClear;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 12, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '播放队列',
                  style: context.text.titleMedium?.copyWith(fontSize: 18),
                ),
                const SizedBox(height: 3),
                DotSeparated(
                  parts: [
                    if (queue.sourceTitle != null) '来自 ${queue.sourceTitle}',
                    '${queue.length} 首',
                  ],
                ),
              ],
            ),
          ),
          ValueListenableBuilder(
            valueListenable: app.player.radioMode,
            builder: (context, radio, _) => radio
                ? const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: TagBadge('电台'),
                  )
                : const SizedBox.shrink(),
          ),
          RoundIconButton(
            icon: Icons.delete_sweep_outlined,
            tooltip: '清空队列',
            size: 40,
            color: s.chip.withValues(alpha: 0.7),
            onPressed: queue.isEmpty ? null : onClear,
          ),
        ],
      ),
    );
  }
}

class _QueueList extends StatelessWidget {
  const _QueueList({required this.queue, required this.controller});

  final PlayQueue queue;
  final ScrollController controller;

  @override
  Widget build(BuildContext context) {
    // Stable keys even when a song is queued twice.
    final seen = <int, int>{};
    final keys = [
      for (final song in queue.songs)
        ValueKey('${song.id}#${seen[song.id] = (seen[song.id] ?? -1) + 1}'),
    ];
    return ReorderableListView.builder(
      scrollController: controller,
      buildDefaultDragHandles: false,
      padding: const EdgeInsets.fromLTRB(8, 0, 8, 24),
      itemCount: queue.length,
      itemExtent: QueueView.rowExtent,
      proxyDecorator: (child, index, animation) => AnimatedBuilder(
        animation: animation,
        builder: (context, child) => Transform.scale(
          scale: 1 + 0.03 * Curves.easeOut.transform(animation.value),
          child: Material(
            color: context.surfaces.cardHover,
            elevation: 10 * animation.value,
            shadowColor: Colors.black54,
            borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
            child: child,
          ),
        ),
        child: child,
      ),
      // `newIndex` is already adjusted for the removed item.
      onReorderItem: app.player.moveInQueue,
      itemBuilder: (context, index) {
        final song = queue.songs[index];
        return Dismissible(
          key: keys[index],
          direction: DismissDirection.endToStart,
          resizeDuration: AppMotion.standard,
          movementDuration: AppMotion.standard,
          background: const _RemoveBackground(),
          onDismissed: (_) => app.player.removeFromQueue(index),
          child: _QueueRow(
            song: song,
            index: index,
            isCurrent: index == queue.index,
          ),
        );
      },
    );
  }
}

class _RemoveBackground extends StatelessWidget {
  const _RemoveBackground();

  @override
  Widget build(BuildContext context) {
    return Container(
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.only(right: 24),
      decoration: BoxDecoration(
        color: context.colors.error.withValues(alpha: 0.18),
        borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
      ),
      child: Icon(Icons.remove_circle_outline, color: context.colors.error),
    );
  }
}

class _QueueRow extends StatelessWidget {
  const _QueueRow({
    required this.song,
    required this.index,
    required this.isCurrent,
  });

  final Song song;
  final int index;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return AnimatedContainer(
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      decoration: BoxDecoration(
        color: s.lime.withValues(alpha: isCurrent ? 0.12 : 0),
        borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
      ),
      child: Pressable(
        pressedScale: 0.98,
        onTap: () => app.player.playAt(index),
        onLongPress: () => showSongMenu(context, song),
        onSecondaryTap: () => showSongMenu(context, song),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8),
          child: Row(
            children: [
              SizedBox(
                width: 44,
                height: 44,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    CoverImage(
                      url: song.album.picUrl,
                      size: 120,
                      radius: AppMetrics.radiusSm,
                    ),
                    if (isCurrent)
                      DecoratedBox(
                        decoration: BoxDecoration(
                          color: Colors.black.withValues(alpha: 0.5),
                          borderRadius: BorderRadius.circular(
                            AppMetrics.radiusSm,
                          ),
                        ),
                        child: Center(
                          child: ValueListenableBuilder(
                            valueListenable: app.player.playback,
                            builder: (context, playback, _) => PlayingIndicator(
                              color: s.lime,
                              playing: playback.playing,
                              size: 14,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      song.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodyMedium?.copyWith(
                        fontWeight: FontWeight.w500,
                        color: isCurrent
                            ? s.lime
                            : (song.playable
                                  ? context.colors.onSurface
                                  : s.textTertiary),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      song.artistText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: context.text.bodySmall?.copyWith(
                        color: s.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              Text(
                song.duration.clock,
                style: context.text.bodySmall?.copyWith(
                  color: s.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
              ReorderableDragStartListener(
                index: index,
                child: MouseRegion(
                  cursor: SystemMouseCursors.grab,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(12, 12, 4, 12),
                    child: Icon(
                      Icons.drag_handle_rounded,
                      size: 20,
                      color: s.textTertiary,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _EmptyQueue extends StatelessWidget {
  const _EmptyQueue();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.queue_music_rounded,
            size: 40,
            color: context.surfaces.textTertiary,
          ),
          const SizedBox(height: 10),
          Text(
            '播放队列是空的',
            style: context.text.bodyMedium?.copyWith(
              color: context.surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}
