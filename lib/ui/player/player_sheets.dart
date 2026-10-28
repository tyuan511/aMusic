import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/comment_target.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/sheets.dart';
import '../shared/comments_view.dart';
import '../widgets/kit.dart';
import 'queue_view.dart';

/// Presets of the sleep timer sheet, in minutes.
const List<int> sleepPresets = [15, 30, 45, 60, 90];

/// Speeds offered by the speed sheet.
const List<double> speedPresets = [0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0];

Future<T?> _sheet<T>(BuildContext context, Widget child, {double? height}) {
  return showAppSheet<T>(
    context,
    isScrollControlled: height != null,
    builder: (context) => height == null
        ? SafeArea(top: false, child: child)
        : FractionallySizedBox(heightFactor: height, child: child),
  );
}

Future<void> showSleepTimerSheet(BuildContext context) =>
    _sheet<void>(context, const _SleepSheet());

Future<void> showSpeedSheet(BuildContext context) =>
    _sheet<void>(context, const _SpeedSheet());

Future<void> showQueueSheet(BuildContext context) =>
    _sheet<void>(context, const QueueView(), height: 0.78);

/// Comments of the current song as a sheet.
Future<void> showCurrentComments(BuildContext context) async {
  final song = app.player.currentSong;
  if (song == null || song.id <= 0) return;
  await showComments(
    context,
    CommentTarget(CommentResource.song, song.id, title: song.name),
  );
}

/// "23:41" style countdown, "本首结束" while waiting for the track end.
String sleepLabel(Duration remaining) =>
    remaining == Duration.zero ? '本首结束' : remaining.clock;

class _SleepSheet extends StatelessWidget {
  const _SleepSheet();

  @override
  Widget build(BuildContext context) {
    final player = app.player;
    return ValueListenableBuilder(
      valueListenable: player.sleepRemaining,
      builder: (context, remaining, _) {
        final active = remaining != null;
        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Text('定时关闭', style: context.text.titleMedium),
                  const Spacer(),
                  AnimatedSwitcher(
                    duration: AppMotion.standard,
                    transitionBuilder: (child, animation) => ScaleTransition(
                      scale: animation,
                      child: FadeTransition(opacity: animation, child: child),
                    ),
                    child: active
                        ? Text(
                            sleepLabel(remaining),
                            key: const ValueKey('on'),
                            style: context.text.titleMedium?.copyWith(
                              color: context.surfaces.lime,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          )
                        : const SizedBox.shrink(key: ValueKey('off')),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Text(
                '时间到后音量会在约 8 秒内渐弱再暂停',
                style: context.text.bodySmall?.copyWith(
                  color: context.surfaces.textTertiary,
                ),
              ),
              const SizedBox(height: 16),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final minutes in sleepPresets)
                    PillChip(
                      label: '$minutes 分钟',
                      selected: false,
                      onTap: () {
                        player.setSleepTimer(Duration(minutes: minutes));
                        Navigator.of(context).pop();
                      },
                    ),
                  PillChip(
                    label: '播完本首',
                    icon: Icons.music_note_rounded,
                    selected: active && remaining == Duration.zero,
                    onTap: () {
                      player.setSleepTimer(Duration.zero, endOfTrack: true);
                      Navigator.of(context).pop();
                    },
                  ),
                ],
              ),
              AnimatedSize(
                duration: AppMotion.standard,
                curve: AppMotion.enter,
                child: active
                    ? Padding(
                        padding: const EdgeInsets.only(top: 18),
                        child: SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            icon: const Icon(Icons.timer_off_outlined),
                            label: const Text('取消定时'),
                            onPressed: () {
                              player.setSleepTimer(null);
                              Navigator.of(context).pop();
                            },
                          ),
                        ),
                      )
                    : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _SpeedSheet extends StatelessWidget {
  const _SpeedSheet();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.speed,
      builder: (context, speed, _) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Text('播放速度', style: context.text.titleMedium),
                const Spacer(),
                AnimatedSwitcher(
                  duration: AppMotion.quick,
                  child: Text(
                    speedLabel(speed),
                    key: ValueKey(speed),
                    style: context.text.titleMedium?.copyWith(
                      color: context.surfaces.lime,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: [
                for (final preset in speedPresets)
                  PillChip(
                    label: speedLabel(preset),
                    selected: (preset - speed).abs() < 0.01,
                    onTap: () => app.player.setSpeed(preset),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// `1.25x`, `1x`.
String speedLabel(double speed) {
  final trimmed = speed
      .toStringAsFixed(2)
      .replaceFirst(RegExp(r'0+$'), '')
      .replaceFirst(RegExp(r'\.$'), '');
  return '${trimmed}x';
}

/// Live countdown pill shown while the sleep timer runs; tap opens the sheet.
class SleepCountdownChip extends StatelessWidget {
  const SleepCountdownChip({super.key, this.dense = false});

  final bool dense;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.sleepRemaining,
      builder: (context, remaining, _) => AnimatedSwitcher(
        duration: AppMotion.standard,
        transitionBuilder: (child, animation) => ScaleTransition(
          scale: CurvedAnimation(parent: animation, curve: AppMotion.pop),
          child: FadeTransition(opacity: animation, child: child),
        ),
        child: remaining == null
            ? const SizedBox.shrink(key: ValueKey('off'))
            : Pressable(
                key: const ValueKey('on'),
                onTap: () => showSleepTimerSheet(context),
                child: Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: dense ? 8 : 10,
                    vertical: dense ? 4 : 6,
                  ),
                  decoration: BoxDecoration(
                    color: context.surfaces.lime.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.bedtime_rounded,
                        size: dense ? 12 : 14,
                        color: context.surfaces.lime,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        sleepLabel(remaining),
                        style: TextStyle(
                          fontSize: dense ? 11 : 12,
                          color: context.surfaces.lime,
                          fontWeight: FontWeight.w600,
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
