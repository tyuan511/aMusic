import 'package:flutter/material.dart';

import '../../models/lyric.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../widgets/kit.dart';
import 'lyric_share.dart';
import 'lyric_source.dart';
import 'lyrics_viewport.dart';

/// The full lyrics panel of the current song: spring scrolled viewport,
/// selection (copy / share as image), import / remove a local `.lrc` and
/// the translation / romaji toggles.
class LyricsPanel extends StatelessWidget {
  const LyricsPanel({super.key, this.textAlign = TextAlign.start});

  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return CurrentLyricBuilder(
      builder: (context, songId, lyric) {
        final Widget child;
        if (songId == null) {
          child = const _LyricMessage(
            key: ValueKey('none'),
            icon: Icons.music_note_rounded,
            text: '选首歌开始吧',
          );
        } else if (lyric == null) {
          child = const _LyricSkeleton(key: ValueKey('loading'));
        } else if (lyric.isEmpty) {
          child = _LyricMessage(
            key: ValueKey('empty-$songId'),
            icon: lyric.pureMusic
                ? Icons.graphic_eq_rounded
                : Icons.lyrics_outlined,
            text: lyric.pureMusic ? '纯音乐，请欣赏' : '这首歌暂时没有歌词',
            action: PillChip(
              label: '导入歌词',
              icon: Icons.file_open_outlined,
              selected: false,
              dense: true,
              onTap: () {
                final song = app.player.currentSong;
                if (song != null) importLyricFile(context, song);
              },
            ),
          );
        } else {
          child = _LyricsBody(
            key: ValueKey(lyric),
            lyric: lyric,
            textAlign: textAlign,
          );
        }
        return AnimatedSwitcher(
          duration: AppMotion.emphasized,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          child: child,
        );
      },
    );
  }
}

class _LyricsBody extends StatelessWidget {
  const _LyricsBody({super.key, required this.lyric, required this.textAlign});

  final Lyric lyric;
  final TextAlign textAlign;

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        Positioned.fill(
          child: LyricsViewport(
            lyric: lyric,
            textAlign: textAlign,
            selectionToolbarBuilder: (context, selected, clear) =>
                LyricSelectionToolbar(
                  count: selected.length,
                  onClose: clear,
                  onCopy: () async {
                    await copyLyricLines(context, lyric, selected);
                    clear();
                  },
                  onShare: () async {
                    final song = app.player.currentSong;
                    if (song == null) return;
                    await showLyricShareSheet(
                      context,
                      song: song,
                      lyric: lyric,
                      indices: selected,
                    );
                    clear();
                  },
                ),
          ),
        ),
        Positioned(top: 4, right: 8, child: _LyricMenuButton(lyric: lyric)),
      ],
    );
  }
}

class _LyricMenuButton extends StatelessWidget {
  const _LyricMenuButton({required this.lyric});

  final Lyric lyric;

  @override
  Widget build(BuildContext context) {
    return RoundIconButton(
      icon: Icons.more_horiz_rounded,
      tooltip: '歌词选项',
      size: 36,
      color: Colors.white.withValues(alpha: 0.1),
      iconColor: Colors.white.withValues(alpha: 0.85),
      onPressed: () => showLyricOptions(context, lyric),
    );
  }
}

/// Bottom sheet with lyric options for the current song.
Future<void> showLyricOptions(BuildContext context, Lyric lyric) {
  final song = app.player.currentSong;
  return showModalBottomSheet<void>(
    context: context,
    useSafeArea: true,
    builder: (sheetContext) => ValueListenableBuilder(
      valueListenable: app.settings,
      builder: (context, settings, _) => SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (lyric.hasTranslation)
              SwitchListTile(
                title: const Text('显示翻译'),
                value: settings.showTranslation,
                onChanged: app.settings.setShowTranslation,
              ),
            if (lyric.hasRomaji)
              SwitchListTile(
                title: const Text('显示音译'),
                value: settings.showRomaji,
                onChanged: app.settings.setShowRomaji,
              ),
            SwitchListTile(
              title: const Text('远处歌词模糊'),
              value: settings.lyricBlur,
              onChanged: (value) =>
                  app.settings.update((s) => s.copyWith(lyricBlur: value)),
            ),
            if (song != null)
              ListTile(
                leading: const Icon(Icons.file_open_outlined),
                title: const Text('导入本地歌词 (.lrc)'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  importLyricFile(context, song);
                },
              ),
            if (song != null && lyric.imported)
              ListTile(
                leading: const Icon(Icons.restore_rounded),
                title: const Text('移除导入的歌词'),
                subtitle: const Text('恢复使用云端歌词'),
                onTap: () {
                  Navigator.of(sheetContext).pop();
                  app.lyrics.removeImported(song.id);
                },
              ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    ),
  );
}

/// Three centred lines under the cover; tap opens the lyrics panel.
class LyricsPreview extends StatelessWidget {
  const LyricsPreview({super.key, this.onTap, this.height = 104});

  final VoidCallback? onTap;
  final double height;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: height,
      child: CurrentLyricBuilder(
        builder: (context, songId, lyric) {
          final Widget child;
          if (lyric == null || lyric.isEmpty) {
            child = GestureDetector(
              key: ValueKey('msg-${lyric?.pureMusic}-$songId'),
              behavior: HitTestBehavior.opaque,
              onTap: onTap,
              child: Center(
                child: Text(
                  lyric == null ? '' : (lyric.pureMusic ? '纯音乐，请欣赏' : '暂无歌词'),
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.5),
                    fontSize: 14,
                  ),
                ),
              ),
            );
          } else {
            child = LyricsViewport(
              key: ValueKey(lyric),
              lyric: lyric,
              layout: LyricsLayout.preview,
              textAlign: TextAlign.center,
              onTap: onTap,
            );
          }
          return AnimatedSwitcher(duration: AppMotion.standard, child: child);
        },
      ),
    );
  }
}

/// Kept for older call sites: the full panel.
class CurrentLyrics extends StatelessWidget {
  const CurrentLyrics({super.key});

  @override
  Widget build(BuildContext context) => const LyricsPanel();
}

class _LyricMessage extends StatelessWidget {
  const _LyricMessage({
    super.key,
    required this.icon,
    required this.text,
    this.action,
  });

  final IconData icon;
  final String text;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 40, color: Colors.white.withValues(alpha: 0.4)),
          const SizedBox(height: 12),
          Text(
            text,
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
          if (action != null) ...[const SizedBox(height: 16), action!],
        ],
      ),
    );
  }
}

class _LyricSkeleton extends StatelessWidget {
  const _LyricSkeleton({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 80, 28, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final width in const [220.0, 160.0, 250.0, 190.0, 140.0]) ...[
            Skeleton(width: width, height: 22),
            const SizedBox(height: 22),
          ],
        ],
      ),
    );
  }
}
