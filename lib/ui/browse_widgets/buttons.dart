import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../models/song.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../widgets/kit.dart';
import 'sheets.dart';

/// Play buttons of the browsing screens.

/// Loads the songs a play button should start.
typedef SongsLoader = Future<List<Song>> Function();

/// Starts playback of a collection that still has to be loaded.
///
/// Shows a spinner while [load] runs, flips to pause while the queue playing
/// is this collection ([sourceId]) and toggles play/pause then.
class CollectionPlayButton extends StatefulWidget {
  const CollectionPlayButton({
    super.key,
    required this.sourceId,
    required this.sourceTitle,
    required this.load,
    this.size = 38,
    this.accent = false,
    this.color,
    this.iconColor,
  });

  final int sourceId;
  final String sourceTitle;
  final SongsLoader load;
  final double size;

  /// Lime fill (hero cards) instead of charcoal (list rows).
  final bool accent;

  /// Fill / glyph overrides of the [accent] style (plum on lavender cards).
  final Color? color;
  final Color? iconColor;

  @override
  State<CollectionPlayButton> createState() => _CollectionPlayButtonState();
}

class _CollectionPlayButtonState extends State<CollectionPlayButton> {
  bool _loading = false;

  bool get _isSource => app.player.queue.value.sourceId == widget.sourceId;

  Future<void> _onPressed() async {
    if (_loading) return;
    if (_isSource && !app.player.queue.value.isEmpty) {
      await app.player.togglePlayPause();
      return;
    }
    setState(() => _loading = true);
    try {
      final songs = (await widget.load())
          .where((song) => song.playable)
          .toList();
      if (!mounted) return;
      if (songs.isEmpty) {
        showToast(context, '没有可播放的歌曲');
        return;
      }
      unawaited(
        app.player.playSongs(
          songs,
          sourceTitle: widget.sourceTitle,
          sourceId: widget.sourceId,
        ),
      );
    } on Object catch (error) {
      if (mounted) showToast(context, describeError(error));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge([app.player.queue, app.player.playback]),
      builder: (context, _) {
        final playing = _isSource && app.player.playback.value.playing;
        if (widget.accent) {
          return AccentPlayButton(
            playing: playing,
            loading: _loading,
            size: widget.size,
            color: widget.color,
            iconColor: widget.iconColor,
            onPressed: _onPressed,
          );
        }
        return _RoundLoadingPlay(
          size: widget.size,
          loading: _loading,
          playing: playing,
          onPressed: _onPressed,
        );
      },
    );
  }
}

class _RoundLoadingPlay extends StatelessWidget {
  const _RoundLoadingPlay({
    required this.size,
    required this.loading,
    required this.playing,
    required this.onPressed,
  });

  final double size;
  final bool loading;
  final bool playing;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final fg = playing ? s.onLime : context.colors.onSurface;
    return Pressable(
      onTap: onPressed,
      hoverScale: 1.1,
      semanticLabel: playing ? '暂停' : '播放',
      child: AnimatedContainer(
        duration: AppMotion.standard,
        width: size,
        height: size,
        decoration: BoxDecoration(
          color: playing ? s.lime : s.chip,
          shape: BoxShape.circle,
        ),
        child: AnimatedSwitcher(
          duration: AppMotion.quick,
          transitionBuilder: (child, animation) =>
              ScaleTransition(scale: animation, child: child),
          child: loading
              ? Padding(
                  key: const ValueKey('loading'),
                  padding: EdgeInsets.all(size * 0.3),
                  child: CircularProgressIndicator(strokeWidth: 2, color: fg),
                )
              : Icon(
                  playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  key: ValueKey(playing),
                  size: size * 0.5,
                  color: fg,
                ),
        ),
      ),
    );
  }
}

/// Lime pill "播放全部" style button.
class LimePillButton extends StatelessWidget {
  const LimePillButton({
    super.key,
    required this.label,
    required this.icon,
    this.onPressed,
    this.loading = false,
  });

  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final enabled = onPressed != null;
    final fg = enabled ? s.onLime : s.textTertiary;
    return Pressable(
      onTap: onPressed,
      hoverScale: 1.03,
      semanticLabel: label,
      child: AnimatedContainer(
        duration: AppMotion.standard,
        curve: AppMotion.enter,
        height: 48,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        decoration: BoxDecoration(
          color: enabled ? s.lime : s.chip,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
          boxShadow: enabled
              ? [
                  BoxShadow(
                    color: s.glow,
                    blurRadius: 18,
                    offset: const Offset(0, 6),
                  ),
                ]
              : null,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            AnimatedSwitcher(
              duration: AppMotion.quick,
              child: loading
                  ? SizedBox(
                      key: const ValueKey('loading'),
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: fg,
                      ),
                    )
                  : Icon(icon, key: ValueKey(icon), size: 22, color: fg),
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: context.text.labelLarge?.copyWith(
                color: fg,
                fontSize: 15,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
