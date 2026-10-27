import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;

import 'package:file_selector/file_selector.dart';
import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/config.dart';
import '../../core/prefs.dart';
import '../../data/net_image.dart';
import '../../models/song.dart';
import '../../models/playlist.dart' show UserProfile;
import '../../models/user.dart';
import '../../services/app.dart';
import '../../services/download_service.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../login/login_dialog.dart';
import '../shell.dart';
import '../ui_scale.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import 'settings_widgets.dart';
import 'update_dialog.dart';

/// 设置. Grouped cards (max 760 wide) with a staggered entrance.
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const PageHeader(title: '设置'),
        Expanded(
          child: ValueListenableBuilder<SettingsState>(
            valueListenable: app.settings,
            builder: (context, settings, _) => ListView(
              padding: EdgeInsets.fromLTRB(
                AppMetrics.gutter,
                8,
                AppMetrics.gutter,
                ShellLayout.bottomInsetOf(context) + 16,
              ),
              children: [
                Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 760),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const _AccountGroup(index: 0),
                        _AppearanceGroup(settings: settings, index: 1),
                        _PlaybackGroup(settings: settings, index: 2),
                        _LyricsGroup(settings: settings, index: 3),
                        _DownloadGroup(settings: settings, index: 4),
                        _StorageGroup(settings: settings, index: 5),
                        _AboutGroup(settings: settings, index: 6),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

void _toast(BuildContext context, String message) {
  ScaffoldMessenger.maybeOf(context)
    ?..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(message)));
}

void _update(SettingsState Function(SettingsState s) change) =>
    app.settings.update(change);

// ------------------------------------------------------------------ account

class _AccountGroup extends StatelessWidget {
  const _AccountGroup({required this.index});

  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: '账号',
      icon: Icons.person_rounded,
      index: index,
      children: [
        ValueListenableBuilder(
          valueListenable: app.session,
          builder: (context, session, _) => AnimatedSwitcher(
            duration: AppMotion.standard,
            child: session.profile == null
                ? _SignedOut(key: const ValueKey('out'), error: session.error)
                : _ProfileCard(
                    key: ValueKey(session.profile!.id),
                    profile: session.profile!,
                  ),
          ),
        ),
      ],
    );
  }
}

class _SignedOut extends StatelessWidget {
  const _SignedOut({super.key, this.error});

  final String? error;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Row(
        children: [
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(color: s.chip, shape: BoxShape.circle),
            child: Icon(Icons.person_outline_rounded, color: s.textSecondary),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '未登录',
                  style: context.text.titleMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  error ?? '登录后同步歌单、每日推荐与红心',
                  style: context.text.bodySmall?.copyWith(
                    color: error == null
                        ? s.textTertiary
                        : context.colors.error,
                  ),
                ),
              ],
            ),
          ),
          FilledButton(
            onPressed: () => showLoginDialog(context),
            child: const Text('登录'),
          ),
        ],
      ),
    );
  }
}

class _ProfileCard extends StatefulWidget {
  const _ProfileCard({super.key, required this.profile});

  final UserProfile profile;

  @override
  State<_ProfileCard> createState() => _ProfileCardState();
}

class _ProfileCardState extends State<_ProfileCard> {
  late final Future<UserDetail?> _detail = app.library
      .userDetail(widget.profile.id)
      .then<UserDetail?>((detail) => detail)
      .catchError((Object _) => null);
  bool _signingOut = false;

  Future<void> _signOut() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('退出登录'),
        content: const Text('退出后将无法同步歌单与红心，确定退出？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('退出'),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() => _signingOut = true);
    await app.session.signOut();
    app.library.clearCaches();
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final profile = widget.profile;
    return FutureBuilder<UserDetail?>(
      future: _detail,
      builder: (context, snapshot) {
        final detail = snapshot.data;
        final vip = detail?.isVip ?? profile.isVip;
        return Padding(
          padding: const EdgeInsets.all(18),
          child: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(
                    color: vip ? s.lime : s.hairline,
                    width: 2,
                  ),
                ),
                child: ClipOval(
                  child: CoverImage(
                    url: detail?.avatarUrl ?? profile.avatarUrl,
                    size: 180,
                    width: 56,
                    height: 56,
                    radius: 0,
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(
                          child: Text(
                            detail?.nickname ?? profile.nickname,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.titleMedium?.copyWith(
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                        AnimatedSwitcher(
                          duration: AppMotion.standard,
                          child: detail == null
                              ? const SizedBox.shrink()
                              : Padding(
                                  padding: const EdgeInsets.only(left: 8),
                                  child: TagBadge(
                                    'Lv.${detail.level}',
                                    color: s.lavender,
                                  ),
                                ),
                        ),
                        if (vip) ...[
                          const SizedBox(width: 6),
                          TagBadge('黑胶VIP', color: s.lime),
                        ],
                      ],
                    ),
                    const SizedBox(height: 5),
                    AnimatedSwitcher(
                      duration: AppMotion.standard,
                      child: detail == null
                          ? snapshot.connectionState == ConnectionState.waiting
                                ? const Skeleton(width: 160, height: 11)
                                : Text(
                                    'ID ${profile.id}',
                                    style: context.text.bodySmall?.copyWith(
                                      color: s.textTertiary,
                                    ),
                                  )
                          : DotSeparated(
                              parts: [
                                '听歌 ${detail.listenSongs} 首',
                                '关注 ${detail.follows}',
                                '粉丝 ${detail.followeds}',
                              ],
                            ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              AnimatedSwitcher(
                duration: AppMotion.quick,
                child: _signingOut
                    ? const SizedBox(
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : OutlinedButton(
                        onPressed: _signOut,
                        child: const Text('退出登录'),
                      ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// --------------------------------------------------------------- appearance

class _AppearanceGroup extends StatefulWidget {
  const _AppearanceGroup({required this.settings, required this.index});

  final SettingsState settings;
  final int index;

  @override
  State<_AppearanceGroup> createState() => _AppearanceGroupState();
}

class _AppearanceGroupState extends State<_AppearanceGroup> {
  /// Slider value while dragging; the UI scale is only applied on release so
  /// the slider does not move under the finger.
  double? _dragScale;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    // The real screen, not the already scaled MediaQuery of this subtree.
    final detected = UiScale.autoScaleFor(
      MediaQueryData.fromView(View.of(context)),
    );
    final auto = settings.autoUiScale;
    final scale = _dragScale ?? (auto ? detected : settings.uiScale);
    return SettingsGroup(
      title: '外观',
      icon: Icons.palette_rounded,
      index: widget.index,
      children: [
        SettingsTile(
          label: '主题',
          trailing: SegmentedButton<ThemeMode>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: ThemeMode.dark, label: Text('深色')),
              ButtonSegment(value: ThemeMode.light, label: Text('浅色')),
              ButtonSegment(value: ThemeMode.system, label: Text('跟随系统')),
            ],
            selected: {settings.themeMode},
            onSelectionChanged: (v) =>
                _update((s) => s.copyWith(themeMode: v.first)),
          ),
        ),
        SettingsTile(
          label: '布局',
          subtitle: '自动按窗口宽度切换桌面 / 手机布局',
          trailing: SegmentedButton<LayoutMode>(
            showSelectedIcon: false,
            segments: [
              for (final mode in LayoutMode.values)
                ButtonSegment(value: mode, label: Text(mode.label)),
            ],
            selected: {settings.layoutMode},
            onSelectionChanged: (v) =>
                _update((s) => s.copyWith(layoutMode: v.first)),
          ),
        ),
        SettingsTile(
          label: '自动缩放',
          subtitle: '按屏幕自动选择界面大小，当前检测为 ${(detected * 100).round()}%',
          trailing: Switch(
            value: auto,
            onChanged: (value) => _update(
              (s) => s.copyWith(
                autoUiScale: value,
                // Start the manual slider from what the user sees now.
                uiScale: value ? null : detected,
              ),
            ),
          ),
        ),
        SliderTile(
          label: '界面缩放',
          subtitle: auto ? '关闭自动缩放后可手动调整' : '松手后生效',
          value: scale,
          min: UiScale.min,
          max: UiScale.max,
          divisions: 19,
          enabled: !auto,
          valueLabel: '${(scale * 100).round()}%',
          onChanged: (value) => setState(() => _dragScale = value),
          onChangeEnd: (value) {
            setState(() => _dragScale = null);
            _update((s) => s.copyWith(uiScale: value));
          },
        ),
        SettingsTile(
          label: '动态背景',
          subtitle: '播放页根据封面颜色流动',
          trailing: Switch(
            value: settings.dynamicBackground,
            onChanged: (v) => _update((s) => s.copyWith(dynamicBackground: v)),
          ),
        ),
      ],
    );
  }
}

// ----------------------------------------------------------------- playback

String _levelHint(AudioLevel level) => switch (level) {
  AudioLevel.standard ||
  AudioLevel.higher ||
  AudioLevel.exhigh => '${level.bitrate ~/ 1000} kbps',
  AudioLevel.lossless => 'FLAC 无损，可能需要会员',
  _ => '需要黑胶会员，否则自动降级',
};

class _PlaybackGroup extends StatelessWidget {
  const _PlaybackGroup({required this.settings, required this.index});

  final SettingsState settings;
  final int index;

  @override
  Widget build(BuildContext context) {
    return SettingsGroup(
      title: '播放',
      icon: Icons.graphic_eq_rounded,
      index: index,
      children: [
        SettingsTile(
          label: '在线播放音质',
          subtitle: _levelHint(settings.audioLevel),
          trailing: ChoiceButton<AudioLevel>(
            value: settings.audioLevel,
            values: AudioLevel.values,
            labelOf: (level) => level.label,
            onSelected: (level) =>
                _update((s) => s.copyWith(audioLevel: level)),
          ),
        ),
        SettingsTile(
          label: '下载音质',
          subtitle: _levelHint(settings.downloadLevel),
          trailing: ChoiceButton<AudioLevel>(
            value: settings.downloadLevel,
            values: AudioLevel.values,
            labelOf: (level) => level.label,
            onSelected: (level) =>
                _update((s) => s.copyWith(downloadLevel: level)),
          ),
        ),
        _SpeedTile(speed: settings.playbackSpeed),
        SettingsTile(
          label: '启动后自动播放',
          subtitle: '打开应用时继续播放上次的歌曲',
          trailing: Switch(
            value: settings.autoPlay,
            onChanged: (v) => _update((s) => s.copyWith(autoPlay: v)),
          ),
        ),
        SettingsTile(
          label: '上报播放记录',
          subtitle: '同步听歌排行，改善每日推荐',
          trailing: Switch(
            value: settings.reportPlays,
            onChanged: (v) => _update((s) => s.copyWith(reportPlays: v)),
          ),
        ),
        if (Platforms.supportsImmersive)
          SettingsTile(
            label: '全屏沉浸',
            subtitle: '隐藏状态栏与导航栏',
            trailing: Switch(
              value: settings.immersive,
              onChanged: (v) => _update((s) => s.copyWith(immersive: v)),
            ),
          ),
      ],
    );
  }
}

class _SpeedTile extends StatefulWidget {
  const _SpeedTile({required this.speed});

  final double speed;

  @override
  State<_SpeedTile> createState() => _SpeedTileState();
}

class _SpeedTileState extends State<_SpeedTile> {
  double? _drag;

  @override
  Widget build(BuildContext context) {
    final value = _drag ?? widget.speed;
    return SliderTile(
      label: '播放速度',
      value: value,
      min: 0.5,
      max: 2.0,
      divisions: 30,
      valueLabel: '${value.toStringAsFixed(2)}×',
      onChanged: (v) => setState(() => _drag = v),
      onChangeEnd: (v) {
        setState(() => _drag = null);
        app.player.setSpeed(v);
      },
      footer: Align(
        alignment: Alignment.centerRight,
        child: AnimatedOpacity(
          duration: AppMotion.quick,
          opacity: (value - 1).abs() > 0.001 ? 1 : 0,
          child: TextButton(
            onPressed: () => app.player.setSpeed(1),
            child: const Text('恢复 1.0×'),
          ),
        ),
      ),
    );
  }
}

// ------------------------------------------------------------------- lyrics

class _LyricsGroup extends StatefulWidget {
  const _LyricsGroup({required this.settings, required this.index});

  final SettingsState settings;
  final int index;

  @override
  State<_LyricsGroup> createState() => _LyricsGroupState();
}

class _LyricsGroupState extends State<_LyricsGroup> {
  double? _size;
  double? _resume;

  @override
  Widget build(BuildContext context) {
    final settings = widget.settings;
    final size = _size ?? settings.lyricFontSize;
    final resume = _resume ?? settings.lyricResumeSeconds;
    return SettingsGroup(
      title: '歌词',
      icon: Icons.lyrics_rounded,
      index: widget.index,
      children: [
        SliderTile(
          label: '字号',
          value: size,
          min: 16,
          max: 44,
          divisions: 28,
          valueLabel: '${size.round()}',
          onChanged: (v) => setState(() => _size = v),
          onChangeEnd: (v) {
            setState(() => _size = null);
            _update((s) => s.copyWith(lyricFontSize: v.roundToDouble()));
          },
          footer: _LyricPreview(
            size: size,
            weight: settings.lyricFontWeight,
            blur: settings.lyricBlur,
            translation: settings.showTranslation,
          ),
        ),
        SettingsTile(
          label: '字重',
          trailing: SegmentedButton<int>(
            showSelectedIcon: false,
            segments: const [
              ButtonSegment(value: 400, label: Text('常规')),
              ButtonSegment(value: 500, label: Text('中等')),
              ButtonSegment(value: 600, label: Text('半粗')),
              ButtonSegment(value: 700, label: Text('粗体')),
            ],
            selected: {settings.lyricFontWeight},
            onSelectionChanged: (v) =>
                _update((s) => s.copyWith(lyricFontWeight: v.first)),
          ),
        ),
        SettingsTile(
          label: '景深模糊',
          subtitle: '远离当前行的歌词逐渐模糊',
          trailing: Switch(
            value: settings.lyricBlur,
            onChanged: (v) => _update((s) => s.copyWith(lyricBlur: v)),
          ),
        ),
        SettingsTile(
          label: '显示翻译',
          trailing: Switch(
            value: settings.showTranslation,
            onChanged: (v) => _update((s) => s.copyWith(showTranslation: v)),
          ),
        ),
        SettingsTile(
          label: '显示音译',
          subtitle: '日语等歌词的罗马音',
          trailing: Switch(
            value: settings.showRomaji,
            onChanged: (v) => _update((s) => s.copyWith(showRomaji: v)),
          ),
        ),
        SliderTile(
          label: '手动滚动后恢复跟随',
          value: resume,
          min: 1,
          max: 10,
          divisions: 18,
          valueLabel: '${resume.toStringAsFixed(1)} 秒',
          onChanged: (v) => setState(() => _resume = v),
          onChangeEnd: (v) {
            setState(() => _resume = null);
            _update((s) => s.copyWith(lyricResumeSeconds: v));
          },
        ),
      ],
    );
  }
}

/// Live preview of the lyric style: an active line between two dimmed ones.
class _LyricPreview extends StatelessWidget {
  const _LyricPreview({
    required this.size,
    required this.weight,
    required this.blur,
    required this.translation,
  });

  final double size;
  final int weight;
  final bool blur;
  final bool translation;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final fontWeight = FontWeight.values[(weight ~/ 100 - 1).clamp(0, 8)];
    Widget dim(String text) => AnimatedOpacity(
      duration: AppMotion.standard,
      opacity: 0.35,
      child: ImageFiltered(
        enabled: blur,
        imageFilter: ImageFilter.blur(sigmaX: 1.6, sigmaY: 1.6),
        child: AnimatedDefaultTextStyle(
          duration: AppMotion.standard,
          curve: AppMotion.enter,
          style: TextStyle(
            fontSize: size * 0.8,
            fontWeight: fontWeight,
            color: context.colors.onSurface,
            height: 1.3,
          ),
          child: Text(text, maxLines: 1, overflow: TextOverflow.ellipsis),
        ),
      ),
    );
    return Container(
      margin: const EdgeInsets.only(top: 6),
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            s.plum.withValues(alpha: context.isDark ? 0.55 : 0.18),
            s.chip.withValues(alpha: 0.6),
          ],
        ),
        borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          dim('风吹过山谷的时候'),
          const SizedBox(height: 8),
          AnimatedDefaultTextStyle(
            duration: AppMotion.standard,
            curve: AppMotion.enter,
            style: TextStyle(
              fontSize: size,
              fontWeight: fontWeight,
              color: context.colors.onSurface,
              height: 1.3,
            ),
            child: const Text(
              '我听见你在唱歌',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          AnimatedSize(
            duration: AppMotion.standard,
            curve: AppMotion.enter,
            child: translation
                ? Padding(
                    padding: const EdgeInsets.only(top: 4),
                    child: Text(
                      'I hear you singing',
                      style: TextStyle(
                        fontSize: size * 0.55,
                        color: s.textSecondary,
                      ),
                    ),
                  )
                : const SizedBox(width: double.infinity),
          ),
          const SizedBox(height: 8),
          dim('像很久以前那样'),
        ],
      ),
    );
  }
}

// ----------------------------------------------------------------- download

class _DownloadGroup extends StatefulWidget {
  const _DownloadGroup({required this.settings, required this.index});

  final SettingsState settings;
  final int index;

  @override
  State<_DownloadGroup> createState() => _DownloadGroupState();
}

class _DownloadGroupState extends State<_DownloadGroup> {
  late Future<String> _path = _resolve();

  Future<String> _resolve() async =>
      (await app.downloads.downloadDirectory()).path;

  @override
  void didUpdateWidget(_DownloadGroup oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.settings.downloadDirectory !=
        widget.settings.downloadDirectory) {
      _path = _resolve();
    }
  }

  Future<void> _pick() async {
    final current = await _path;
    final picked = await getDirectoryPath(
      initialDirectory: current,
      confirmButtonText: '选择',
    );
    if (picked == null || !mounted) return;
    try {
      await DownloadService.probeWritable(Directory(picked));
    } on Object catch (error) {
      if (mounted) _toast(context, '$error');
      return;
    }
    _update((s) => s.copyWith(downloadDirectory: picked));
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final custom = widget.settings.downloadDirectory != null;
    return SettingsGroup(
      title: '下载',
      icon: Icons.download_rounded,
      index: widget.index,
      children: [
        SettingsTile(
          label: '下载目录',
          below: FutureBuilder<String>(
            future: _path,
            builder: (context, snapshot) => AnimatedSwitcher(
              duration: AppMotion.standard,
              child: Container(
                key: ValueKey(snapshot.data),
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: s.chip.withValues(alpha: 0.6),
                  borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
                ),
                child: Row(
                  children: [
                    Icon(Icons.folder_rounded, size: 18, color: s.lime),
                    const SizedBox(width: 10),
                    Expanded(
                      child: SelectableText(
                        snapshot.data ?? '…',
                        maxLines: 2,
                        style: context.text.bodySmall?.copyWith(
                          color: s.textSecondary,
                        ),
                      ),
                    ),
                    if (!custom)
                      Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: TagBadge('默认', color: s.textTertiary),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(14, 6, 14, 10),
          child: Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              if (Platforms.isDesktop)
                PillChip(
                  label: '更改目录',
                  icon: Icons.drive_folder_upload_rounded,
                  selected: false,
                  dense: true,
                  onTap: _pick,
                ),
              if (custom)
                PillChip(
                  label: '恢复默认',
                  icon: Icons.restart_alt_rounded,
                  selected: false,
                  dense: true,
                  onTap: () =>
                      _update((s) => s.copyWith(clearDownloadDirectory: true)),
                ),
              if (Platforms.isDesktop)
                PillChip(
                  label: '打开文件夹',
                  icon: Icons.open_in_new_rounded,
                  selected: false,
                  dense: true,
                  onTap: () async {
                    final ok = await app.downloads.openFolder();
                    if (!ok && context.mounted) _toast(context, '无法打开文件夹');
                  },
                ),
            ],
          ),
        ),
      ],
    );
  }
}

// ------------------------------------------------------------------ storage

String _bytes(int bytes) {
  if (bytes < 1024) return '$bytes B';
  if (bytes < 1024 * 1024) return '${(bytes / 1024).toStringAsFixed(0)} KB';
  if (bytes < 1024 * 1024 * 1024) {
    return '${(bytes / 1024 / 1024).toStringAsFixed(1)} MB';
  }
  return '${(bytes / 1024 / 1024 / 1024).toStringAsFixed(2)} GB';
}

Future<int> _directorySize(Directory dir) async {
  if (!await dir.exists()) return 0;
  var total = 0;
  var count = 0;
  await for (final entity in dir.list(recursive: true, followLinks: false)) {
    if (entity is File) {
      try {
        total += await entity.length();
      } on FileSystemException {
        // Skip.
      }
    }
    if (++count % 200 == 0) await Future<void>.delayed(Duration.zero);
  }
  return total;
}

class _StorageGroup extends StatefulWidget {
  const _StorageGroup({required this.settings, required this.index});

  final SettingsState settings;
  final int index;

  @override
  State<_StorageGroup> createState() => _StorageGroupState();
}

class _StorageGroupState extends State<_StorageGroup> {
  late Future<int> _images = _imageSize();
  late Future<int> _audio = _audioSize();
  bool _clearingImages = false;
  bool _clearingAudio = false;

  static const List<int> _budgets = [0, 256, 512, 1024, 2048, 4096];

  Future<int> _imageSize() async {
    try {
      final base = await getApplicationCacheDirectory();
      return await _directorySize(
        Directory('${base.path}${Platform.pathSeparator}images'),
      );
    } on Object {
      return 0;
    }
  }

  Future<int> _audioSize() async {
    try {
      return await app.player.cacheSize();
    } on Object {
      return 0;
    }
  }

  Future<void> _clearImages() async {
    setState(() => _clearingImages = true);
    try {
      await ImageByteCache.instance.clear();
      PaintingBinding.instance.imageCache.clear();
    } on Object catch (error) {
      if (mounted) _toast(context, '清除失败：$error');
    }
    if (!mounted) return;
    setState(() {
      _clearingImages = false;
      _images = _imageSize();
    });
    _toast(context, '图片缓存已清除');
  }

  Future<void> _clearAudio() async {
    setState(() => _clearingAudio = true);
    try {
      await app.player.clearCache();
    } on Object catch (error) {
      if (mounted) _toast(context, '清除失败：$error');
    }
    if (!mounted) return;
    setState(() {
      _clearingAudio = false;
      _audio = _audioSize();
    });
    _toast(context, '音频缓存已清除');
  }

  Widget _size(Future<int> future) => FutureBuilder<int>(
    future: future,
    builder: (context, snapshot) => AnimatedSwitcher(
      duration: AppMotion.standard,
      child: snapshot.hasData
          ? Text(
              _bytes(snapshot.data!),
              key: ValueKey(snapshot.data),
              style: context.text.bodySmall?.copyWith(
                color: context.surfaces.textTertiary,
              ),
            )
          : const Skeleton(width: 56, height: 11),
    ),
  );

  Widget _clearButton(bool busy, VoidCallback onTap) => AnimatedSwitcher(
    duration: AppMotion.quick,
    child: busy
        ? const SizedBox(
            width: 22,
            height: 22,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : PillChip(label: '清除', selected: false, dense: true, onTap: onTap),
  );

  @override
  Widget build(BuildContext context) {
    final budget = widget.settings.audioCacheMb;
    return SettingsGroup(
      title: '存储',
      icon: Icons.storage_rounded,
      index: widget.index,
      children: [
        SettingsTile(
          label: '图片缓存',
          below: _size(_images),
          trailing: _clearButton(_clearingImages, _clearImages),
        ),
        SettingsTile(
          label: '音频缓存',
          below: _size(_audio),
          trailing: _clearButton(_clearingAudio, _clearAudio),
        ),
        SettingsTile(
          label: '音频缓存上限',
          subtitle: budget == 0 ? '不缓存播放过的歌曲' : '超出后自动清理最早的缓存',
          trailing: ChoiceButton<int>(
            value: _budgets.contains(budget) ? budget : 512,
            values: _budgets,
            labelOf: (mb) =>
                mb == 0 ? '关闭' : (mb >= 1024 ? '${mb ~/ 1024} GB' : '$mb MB'),
            onSelected: (mb) => _update((s) => s.copyWith(audioCacheMb: mb)),
          ),
        ),
      ],
    );
  }
}

// -------------------------------------------------------------------- about

class _AboutGroup extends StatefulWidget {
  const _AboutGroup({required this.settings, required this.index});

  final SettingsState settings;
  final int index;

  @override
  State<_AboutGroup> createState() => _AboutGroupState();
}

class _AboutGroupState extends State<_AboutGroup> {
  late final Future<PackageInfo?> _info = PackageInfo.fromPlatform()
      .then<PackageInfo?>((info) => info)
      .catchError((Object _) => null);
  bool _checking = false;
  String? _result;

  Future<void> _check() async {
    setState(() {
      _checking = true;
      _result = null;
    });
    try {
      final release = await app.updates.checkNow();
      if (!mounted) return;
      setState(() {
        _checking = false;
        _result = release == null ? '已是最新版本' : '发现新版本 v${release.version}';
      });
      if (release != null) await showUpdateDialog(context, release);
    } on Object catch (error) {
      if (!mounted) return;
      setState(() {
        _checking = false;
        _result = '检查失败：${error.toString().replaceFirst('Exception: ', '')}';
      });
    }
  }

  Future<void> _openUrl(String url) async {
    final ok = await launchUrl(
      Uri.parse(url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok && mounted) _toast(context, '无法打开链接');
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return SettingsGroup(
      title: '关于',
      icon: Icons.info_outline_rounded,
      index: widget.index,
      children: [
        FutureBuilder<PackageInfo?>(
          future: _info,
          builder: (context, snapshot) {
            final info = snapshot.data;
            final version = info == null
                ? '…'
                : 'v${info.version}${info.buildNumber.isEmpty ? '' : ' (${info.buildNumber})'}';
            return SettingsTile(
              label: AppConfig.appName,
              subtitle: '网易云音乐第三方客户端 · $version',
              trailing: AnimatedSwitcher(
                duration: AppMotion.quick,
                child: _checking
                    ? const SizedBox(
                        key: ValueKey('checking'),
                        width: 22,
                        height: 22,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : PillChip(
                        key: const ValueKey('check'),
                        label: '检查更新',
                        icon: Icons.system_update_alt_rounded,
                        selected: false,
                        dense: true,
                        onTap: _check,
                      ),
              ),
              below: AnimatedSize(
                duration: AppMotion.standard,
                curve: AppMotion.enter,
                child: _result == null
                    ? const SizedBox(width: double.infinity)
                    : Text(
                        _result!,
                        style: context.text.bodySmall?.copyWith(color: s.lime),
                      ),
              ),
            );
          },
        ),
        SettingsTile(
          label: '自动检查更新',
          subtitle: '每天最多检查一次 GitHub Releases',
          trailing: Switch(
            value: widget.settings.checkUpdates,
            onChanged: (v) => _update((s) => s.copyWith(checkUpdates: v)),
          ),
        ),
        SettingsTile(
          label: 'GitHub',
          subtitle: UpdateService.repo,
          trailing: Icon(
            Icons.open_in_new_rounded,
            size: 18,
            color: s.textSecondary,
          ),
          onTap: () => _openUrl(UpdateService.repoPage),
        ),
        SettingsTile(
          label: '开源许可',
          trailing: Icon(Icons.chevron_right_rounded, color: s.textSecondary),
          onTap: () async {
            final info = await _info;
            if (!context.mounted) return;
            showLicensePage(
              context: context,
              applicationName: AppConfig.appName,
              applicationVersion: info?.version,
            );
          },
        ),
        SettingsTile(
          label: '致谢',
          below: Text(
            'Lazer（MIT）：下载、本地音乐与更新检查的参考实现\n'
            'AMLL（Apple Music-like Lyrics）：歌词界面的灵感来源\n'
            'NeteaseCloudMusicApi：接口参考',
            style: context.text.bodySmall?.copyWith(
              color: s.textSecondary,
              height: 1.7,
            ),
          ),
        ),
      ],
    );
  }
}
