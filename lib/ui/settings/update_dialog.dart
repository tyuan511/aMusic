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
                  const SizedBox(height: 18),
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
                          await app.updates.skip(release.version);
                          navigator.pop();
                        },
                        child: const Text('跳过此版本'),
                      ),
                      FilledButton.icon(
                        onPressed: () => _open(context),
                        icon: const Icon(Icons.open_in_new_rounded, size: 18),
                        label: const Text('前往下载'),
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
