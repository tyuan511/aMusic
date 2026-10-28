import 'dart:io';

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/format.dart';
import '../../services/app.dart';
import '../../services/update_service.dart';
import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// "发现新版本" dialog: release notes plus 稍后 / 跳过此版本 / 前往下载.
Future<void> showUpdateDialog(BuildContext context, AppRelease release) {
  return showGeneralDialog<void>(
    context: context,
    barrierDismissible: true,
    barrierLabel: '关闭',
    barrierColor: Colors.black.withValues(alpha: 0.5),
    transitionDuration: AppMotion.emphasized,
    pageBuilder: (context, _, _) => _UpdateDialog(release: release),
    transitionBuilder: (context, animation, _, child) {
      final curved = CurvedAnimation(parent: animation, curve: AppMotion.enter);
      return FadeTransition(
        opacity: curved,
        child: ScaleTransition(
          scale: Tween(begin: 0.94, end: 1.0).animate(curved),
          child: child,
        ),
      );
    },
  );
}

class _UpdateDialog extends StatelessWidget {
  const _UpdateDialog({required this.release});

  final AppRelease release;

  Future<void> _open(BuildContext context) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final ok = await launchUrl(
      Uri.parse(release.url),
      mode: LaunchMode.externalApplication,
    );
    if (!ok) {
      messenger?.showSnackBar(const SnackBar(content: Text('无法打开浏览器')));
      return;
    }
    navigator.pop();
  }

  Future<void> _install(BuildContext context, File file) async {
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.maybeOf(context);
    final error = await app.updates.install(file);
    if (error != null) {
      messenger?.showSnackBar(SnackBar(content: Text('无法打开安装包：$error')));
      return;
    }
    navigator.pop();
  }

  Widget _primary(BuildContext context, UpdateDownload state) {
    final installable = app.updates.installerFor(release) != null;
    if (!installable) {
      return FilledButton.icon(
        onPressed: () => _open(context),
        icon: const Icon(Icons.open_in_new_rounded, size: 18),
        label: const Text('前往下载'),
      );
    }
    return switch (state.status) {
      UpdateDownloadStatus.downloading => OutlinedButton(
        onPressed: app.updates.cancelDownload,
        child: const Text('取消下载'),
      ),
      UpdateDownloadStatus.ready => FilledButton.icon(
        onPressed: () => _install(context, state.file!),
        icon: const Icon(Icons.install_desktop_rounded, size: 18),
        label: const Text('立即安装'),
      ),
      UpdateDownloadStatus.failed => Wrap(
        spacing: 8,
        children: [
          TextButton(
            onPressed: () => _open(context),
            child: const Text('浏览器下载'),
          ),
          FilledButton.icon(
            onPressed: () => app.updates.startDownload(release),
            icon: const Icon(Icons.refresh_rounded, size: 18),
            label: const Text('重试'),
          ),
        ],
      ),
      UpdateDownloadStatus.idle => FilledButton.icon(
        onPressed: () => app.updates.startDownload(release),
        icon: const Icon(Icons.download_rounded, size: 18),
        label: const Text('下载更新'),
      ),
    };
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final notes = release.notes.isEmpty ? '暂无更新说明' : release.notes;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 460, maxHeight: 560),
          child: Material(
            type: MaterialType.transparency,
            child: GlassPanel(
              radius: AppMetrics.radiusLg,
              color: s.card.withValues(alpha: 0.96),
              padding: const EdgeInsets.fromLTRB(24, 22, 24, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                          color: s.lime,
                          shape: BoxShape.circle,
                          boxShadow: [BoxShadow(color: s.glow, blurRadius: 18)],
                        ),
                        child: Icon(
                          Icons.rocket_launch_rounded,
                          color: s.onLime,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '发现新版本',
                              style: context.text.titleMedium?.copyWith(
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 3),
                            DotSeparated(
                              parts: [
                                'v${release.version}',
                                if (release.publishedAt != null)
                                  release.publishedAt!.toLocal().date,
                              ],
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  if (release.name != null &&
                      release.name!.isNotEmpty &&
                      release.name != 'v${release.version}') ...[
                    const SizedBox(height: 14),
                    Text(release.name!, style: context.text.titleSmall),
                  ],
                  const SizedBox(height: 12),
                  Flexible(
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: s.chip.withValues(alpha: 0.6),
                        borderRadius: BorderRadius.circular(
                          AppMetrics.radiusSm,
                        ),
                      ),
                      child: SingleChildScrollView(
                        child: SelectableText(
                          notes,
                          style: context.text.bodySmall?.copyWith(
                            color: s.textSecondary,
                            height: 1.6,
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  ValueListenableBuilder<UpdateDownload>(
                    valueListenable: app.updates.download,
                    builder: (context, state, _) =>
                        _DownloadStatus(state: state),
                  ),
                  const SizedBox(height: 14),
                  Wrap(
                    alignment: WrapAlignment.end,
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      TextButton(
                        onPressed: () {
                          app.updates.dismiss();
                          Navigator.of(context).pop();
                        },
                        child: const Text('稍后'),
                      ),
                      TextButton(
                        onPressed: () async {
                          final navigator = Navigator.of(context);
                          app.updates.cancelDownload();
                          await app.updates.skip(release.version);
                          navigator.pop();
                        },
                        child: const Text('跳过此版本'),
                      ),
                      ValueListenableBuilder<UpdateDownload>(
                        valueListenable: app.updates.download,
                        builder: (context, state, _) =>
                            _primary(context, state),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _DownloadStatus extends StatelessWidget {
  const _DownloadStatus({required this.state});

  final UpdateDownload state;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final style = context.text.bodySmall?.copyWith(color: s.textSecondary);
    return AnimatedSize(
      duration: AppMotion.standard,
      curve: AppMotion.enter,
      alignment: Alignment.topCenter,
      child: switch (state.status) {
        UpdateDownloadStatus.idle => const SizedBox(width: double.infinity),
        UpdateDownloadStatus.downloading => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            LinearProgressIndicator(
              value: state.progress > 0 ? state.progress : null,
              minHeight: 4,
              borderRadius: BorderRadius.circular(2),
            ),
            const SizedBox(height: 6),
            Text(
              '${state.channel ?? ''} · 下载中 ${(state.progress * 100).round()}%',
              style: style,
            ),
          ],
        ),
        UpdateDownloadStatus.ready => Text(
          '已下载并校验完成，可以安装',
          style: style?.copyWith(color: s.lime),
        ),
        UpdateDownloadStatus.failed => Text(
          '下载失败：${state.error ?? '未知错误'}。可在设置里切换更新源',
          style: style?.copyWith(color: Theme.of(context).colorScheme.error),
        ),
      },
    );
  }
}
