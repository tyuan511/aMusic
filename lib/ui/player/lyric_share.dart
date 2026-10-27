import 'dart:io';
import 'dart:ui' as ui;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:gal/gal.dart';

import '../../core/config.dart';
import '../../models/lyric.dart';
import '../../models/song.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';

/// Copies [indices] of [lyric] (with translations) to the clipboard.
Future<void> copyLyricLines(
  BuildContext context,
  Lyric lyric,
  List<int> indices,
) async {
  final text = [
    for (final i in indices)
      if (i >= 0 && i < lyric.lines.length) ...[
        lyric.lines[i].text,
        if ((lyric.lines[i].translation ?? '').isNotEmpty)
          lyric.lines[i].translation!,
      ],
  ].join('\n');
  await Clipboard.setData(ClipboardData(text: text));
  if (!context.mounted) return;
  ScaffoldMessenger.maybeOf(context)
      ?.showSnackBar(const SnackBar(content: Text('歌词已复制')));
}

/// Shows a preview of the lyric card and saves it as PNG.
Future<void> showLyricShareSheet(
  BuildContext context, {
  required Song song,
  required Lyric lyric,
  required List<int> indices,
}) {
  final lines = [
    for (final i in indices)
      if (i >= 0 && i < lyric.lines.length) lyric.lines[i],
  ];
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    builder: (context) => _ShareSheet(song: song, lines: lines),
  );
}

class _ShareSheet extends StatefulWidget {
  const _ShareSheet({required this.song, required this.lines});

  final Song song;
  final List<LyricLine> lines;

  @override
  State<_ShareSheet> createState() => _ShareSheetState();
}

class _ShareSheetState extends State<_ShareSheet> {
  final GlobalKey _boundary = GlobalKey();
  bool _saving = false;

  Future<void> _save() async {
    setState(() => _saving = true);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final navigator = Navigator.of(context);
    try {
      final bytes = await _capture();
      final saved = await _write(bytes);
      if (!saved) return;
      navigator.pop();
      messenger?.showSnackBar(const SnackBar(content: Text('歌词卡片已保存')));
    } on Object catch (error) {
      messenger?.showSnackBar(SnackBar(content: Text('保存失败：$error')));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  Future<Uint8List> _capture() async {
    // Let the cover finish decoding before rasterising.
    await WidgetsBinding.instance.endOfFrame;
    final boundary =
        _boundary.currentContext!.findRenderObject()! as RenderRepaintBoundary;
    final image = await boundary.toImage(pixelRatio: 3);
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return data!.buffer.asUint8List();
  }

  /// Gallery on phones, a save dialog on desktop. `false` when cancelled.
  Future<bool> _write(Uint8List bytes) async {
    final name =
        'lyric_${widget.song.id}_${DateTime.now().millisecondsSinceEpoch}';
    if (Platforms.isMobile) {
      if (!await Gal.hasAccess()) await Gal.requestAccess();
      await Gal.putImageBytes(bytes, name: name);
      return true;
    }
    final location = await getSaveLocation(
      suggestedName: '$name.png',
      acceptedTypeGroups: const [
        XTypeGroup(
          label: 'PNG',
          extensions: ['png'],
          uniformTypeIdentifiers: ['public.png'],
        ),
      ],
    );
    if (location == null) return false;
    await File(location.path).writeAsBytes(bytes, flush: true);
    return true;
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('分享歌词', style: context.text.titleMedium),
            const SizedBox(height: 16),
            Flexible(
              child: SingleChildScrollView(
                child: Center(
                  child: RepaintBoundary(
                    key: _boundary,
                    child: LyricCard(song: widget.song, lines: widget.lines),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('取消'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _saving ? null : _save,
                    icon: AnimatedSwitcher(
                      duration: AppMotion.quick,
                      child: _saving
                          ? const SizedBox(
                              key: ValueKey('busy'),
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Icon(
                              Icons.download_rounded,
                              key: ValueKey('idle'),
                              size: 18,
                            ),
                    ),
                    label: Text(Platforms.isMobile ? '保存到相册' : '保存图片'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// The shareable card: cover, title, artist and the selected lines over the
/// album colours.
class LyricCard extends StatelessWidget {
  const LyricCard({super.key, required this.song, required this.lines});

  final Song song;
  final List<LyricLine> lines;

  @override
  Widget build(BuildContext context) {
    final palette = app.accent.palette.value;
    final accent = app.accent.value ?? context.surfaces.lavender;
    final colors = palette.length >= 3
        ? [palette[0], palette[1], palette[2]]
        : [accent, Color.lerp(accent, Colors.black, 0.5)!, Colors.black];
    return Container(
      width: 340,
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            for (final color in colors) Color.lerp(color, Colors.black, 0.35)!,
          ],
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              CoverImage(
                url: song.album.picUrl,
                size: 200,
                width: 56,
                height: 56,
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
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      song.artistText,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.7),
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 26),
          for (final line in lines) ...[
            Text(
              line.text,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 20,
                height: 1.35,
                fontWeight: FontWeight.w600,
              ),
            ),
            if ((line.translation ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 3),
                child: Text(
                  line.translation!,
                  style: TextStyle(
                    color: Colors.white.withValues(alpha: 0.72),
                    fontSize: 14,
                  ),
                ),
              ),
            const SizedBox(height: 12),
          ],
          const SizedBox(height: 14),
          Row(
            children: [
              Icon(
                Icons.graphic_eq_rounded,
                size: 14,
                color: Colors.white.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 6),
              Text(
                AppConfig.appName,
                style: TextStyle(
                  color: Colors.white.withValues(alpha: 0.6),
                  fontSize: 12,
                  letterSpacing: 0.4,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lets the user pick an `.lrc` for [song] and stores it as its lyric.
Future<void> importLyricFile(BuildContext context, Song song) async {
  final messenger = ScaffoldMessenger.maybeOf(context);
  try {
    // Android pickers filter by MIME type, which `.lrc` does not have.
    final groups = Platforms.isAndroid
        ? const <XTypeGroup>[]
        : const [
            XTypeGroup(
              label: '歌词',
              extensions: ['lrc', 'txt'],
              uniformTypeIdentifiers: ['public.plain-text', 'public.text'],
            ),
          ];
    final file = await openFile(acceptedTypeGroups: groups);
    if (file == null) return;
    final bytes = await file.readAsBytes();
    await app.lyrics.importLrc(song.id, bytes);
    messenger?.showSnackBar(const SnackBar(content: Text('已使用导入的歌词')));
  } on FormatException catch (error) {
    messenger?.showSnackBar(SnackBar(content: Text(error.message)));
  } on Object catch (error) {
    messenger?.showSnackBar(SnackBar(content: Text('导入失败：$error')));
  }
}

/// Toolbar shown while lyric lines are selected.
class LyricSelectionToolbar extends StatelessWidget {
  const LyricSelectionToolbar({
    super.key,
    required this.count,
    required this.onCopy,
    required this.onShare,
    required this.onClose,
  });

  final int count;
  final VoidCallback onCopy;
  final VoidCallback onShare;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return GlassPanel(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
      child: Row(
        children: [
          RoundIconButton(
            icon: Icons.close_rounded,
            tooltip: '取消选择',
            size: 38,
            color: Colors.transparent,
            onPressed: onClose,
          ),
          const SizedBox(width: 4),
          Expanded(
            child: AnimatedSwitcher(
              duration: AppMotion.quick,
              child: Text(
                '已选 $count 行',
                key: ValueKey(count),
                style: context.text.labelLarge,
              ),
            ),
          ),
          RoundIconButton(
            icon: Icons.copy_rounded,
            tooltip: '复制',
            size: 38,
            onPressed: onCopy,
          ),
          const SizedBox(width: 8),
          RoundIconButton(
            icon: Icons.image_outlined,
            tooltip: '分享为图片',
            size: 38,
            active: true,
            onPressed: onShare,
          ),
        ],
      ),
    );
  }
}
