import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/config.dart';
import '../../core/format.dart';
import '../../models/loop_mode.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../services/player_service.dart';
import '../../theme/app_theme.dart';
import '../player/player_panel_controller.dart';
import '../player/player_transition.dart';
import '../player/player_sheets.dart';
import 'cover_image.dart';
import 'kit.dart';
import 'like_button.dart';
import 'seek_bar.dart';

/// The always visible transport bar, floated by the shell.
///
/// Rebuilds only when the queue, the current track or the transport state
/// changes; position updates go straight to the painters in [SeekBar] and
/// [_ProgressLine].
class MiniPlayer extends StatelessWidget {
  const MiniPlayer({super.key});

  @override
  Widget build(BuildContext context) {
    // A Material ancestor is required by Slider / InkWell inside the bar.
    return MiniPlayerAnchor(
      child: GlassPanel(
        radius: AppMetrics.radiusLg,
        child: Material(
          type: MaterialType.transparency,
          child: LayoutBuilder(
            builder: (context, constraints) =>
                constraints.maxWidth >= Breakpoints.compact
                ? const _WideBar()
                : const _CompactBar(),
          ),
        ),
      ),
    );
  }
}

void _open([PlayerPanel panel = PlayerPanel.cover]) => showPlayerPanel(panel);

// ---------------------------------------------------------------- compact

class _CompactBar extends StatefulWidget {
  const _CompactBar();

  @override
  State<_CompactBar> createState() => _CompactBarState();
}

class _CompactBarState extends State<_CompactBar>
    with SingleTickerProviderStateMixin {
  /// Horizontal swipe offset; past 72 px (or a fling) skips.
  late final AnimationController _drag = AnimationController.unbounded(
    vsync: this,
  );

  @override
  void dispose() {
    _drag.dispose();
    super.dispose();
  }

  void _onDragEnd(DragEndDetails details) {
    final velocity = details.velocity.pixelsPerSecond.dx;
    final offset = _drag.value;
    if (offset < -72 || velocity < -700) {
      app.player.next();
    } else if (offset > 72 || velocity > 700) {
      app.player.previous();
    }
    _drag.animateTo(0, duration: AppMotion.standard, curve: AppMotion.enter);
  }

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder(
      valueListenable: app.player.queue,
      builder: (context, queue, _) {
        final song = queue.current;
        if (song == null) return const _EmptyBar(height: 62);
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: _open,
          onVerticalDragEnd: (details) {
            if ((details.primaryVelocity ?? 0) < -300) _open();
          },
          onHorizontalDragUpdate: (details) =>
              _drag.value += details.delta.dx * 0.6,
          onHorizontalDragEnd: _onDragEnd,
          child: SizedBox(
            height: 62,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(9, 9, 6, 9),
                  child: Row(
                    children: [
                      Expanded(
                        child: AnimatedBuilder(
                          animation: _drag,
                          builder: (context, child) => Transform.translate(
                            offset: Offset(_drag.value, 0),
                            child: Opacity(
                              opacity: (1 - _drag.value.abs() / 160).clamp(
                                0.3,
                                1.0,
                              ),
                              child: child,
                            ),
                          ),
                          child: Row(
                            children: [
                              _Cover(song: song, size: 44, inset: 9),
                              const SizedBox(width: 11),
                              Expanded(child: _TitleSwitcher(song: song)),
                            ],
                          ),
                        ),
                      ),
                      const SleepCountdownChip(dense: true),
                      const SizedBox(width: 4),
                      _PlayButton(size: 40, color: s.lime),
                      RoundIconButton(
                        icon: Icons.skip_next_rounded,
                        tooltip: '下一首',
                        size: 40,
                        color: Colors.transparent,
                        onPressed: app.player.next,
                      ),
                    ],
                  ),
                ),
                Positioned(
                  left: 22,
                  right: 22,
                  bottom: 0,
                  height: 2,
                  child: _ProgressLine(color: s.lime),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ------------------------------------------------------------------- wide

class _WideBar extends StatelessWidget {
  const _WideBar();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.queue,
      builder: (context, queue, _) {
        final song = queue.current;
        if (song == null) return const _EmptyBar(height: 74);
        return SizedBox(
          height: 74,
          child: Row(
            children: [
              Expanded(flex: 3, child: _WideTrackInfo(song: song)),
              Expanded(flex: 5, child: _WideCenter(queue: queue)),
              Expanded(flex: 3, child: _WideTrailing(song: song)),
            ],
          ),
        );
      },
    );
  }
}

class _WideTrackInfo extends StatelessWidget {
  const _WideTrackInfo({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: _open,
      pressedScale: 0.98,
      semanticLabel: '打开播放页',
      child: Padding(
        padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
        child: Row(
          children: [
            _Cover(song: song, size: 58, inset: 8),
            const SizedBox(width: 14),
            Expanded(child: _TitleSwitcher(song: song, large: true)),
          ],
        ),
      ),
    );
  }
}

class _WideCenter extends StatelessWidget {
  const _WideCenter({required this.queue});

  final PlayQueue queue;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final player = app.player;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          ValueListenableBuilder(
            valueListenable: player.radioKind,
            builder: (context, radio, _) => Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                if (radio == RadioKind.fm)
                  RoundIconButton(
                    icon: Icons.thumb_down_alt_outlined,
                    tooltip: '不喜欢',
                    size: 34,
                    color: Colors.transparent,
                    onPressed: player.fmTrash,
                  )
                else
                  RoundIconButton(
                    icon: Icons.shuffle_rounded,
                    tooltip: queue.shuffle ? '关闭随机播放' : '随机播放',
                    size: 34,
                    color: Colors.transparent,
                    iconColor: queue.shuffle ? s.lime : null,
                    onPressed: radio == null ? player.toggleShuffle : null,
                  ),
                const SizedBox(width: 6),
                RoundIconButton(
                  icon: Icons.skip_previous_rounded,
                  tooltip: '上一首',
                  size: 38,
                  color: Colors.transparent,
                  onPressed: player.previous,
                ),
                const SizedBox(width: 8),
                _PlayButton(size: 36, color: s.lime),
                const SizedBox(width: 8),
                RoundIconButton(
                  icon: Icons.skip_next_rounded,
                  tooltip: '下一首',
                  size: 38,
                  color: Colors.transparent,
                  onPressed: player.next,
                ),
                const SizedBox(width: 6),
                RoundIconButton(
                  icon: queue.repeat == LoopMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  tooltip: '循环：${queue.repeat.label}',
                  size: 34,
                  color: Colors.transparent,
                  iconColor: queue.repeat == LoopMode.off ? null : s.lime,
                  onPressed: radio == null ? player.toggleRepeat : null,
                ),
              ],
            ),
          ),
          const SizedBox(height: 2),
          const _WideSeek(),
        ],
      ),
    );
  }
}

class _WideSeek extends StatelessWidget {
  const _WideSeek();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final style = TextStyle(
      fontSize: 11,
      color: s.textTertiary,
      fontFeatures: const [FontFeature.tabularFigures()],
    );
    return ValueListenableBuilder(
      valueListenable: app.player.position,
      builder: (context, state, child) {
        final duration = state.duration > Duration.zero
            ? state.duration
            : (app.player.currentSong?.duration ?? Duration.zero);
        return Row(
          children: [
            SizedBox(
              width: 42,
              child: Text(
                state.position.clock,
                textAlign: TextAlign.right,
                maxLines: 1,
                softWrap: false,
                style: style,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(child: child!),
            const SizedBox(width: 8),
            SizedBox(
              width: 42,
              child: Text(
                duration.clock,
                maxLines: 1,
                softWrap: false,
                style: style,
              ),
            ),
          ],
        );
      },
      child: SeekBar(color: s.lime, height: 18),
    );
  }
}

class _WideTrailing extends StatelessWidget {
  const _WideTrailing({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final player = app.player;
    return Padding(
      padding: const EdgeInsets.only(right: 14),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          const SleepCountdownChip(),
          const SizedBox(width: 4),
          if (song.id > 0) LikeButton(songId: song.id, size: 20),
          RoundIconButton(
            icon: Icons.queue_music_rounded,
            tooltip: '播放队列 (Q)',
            size: 36,
            color: Colors.transparent,
            onPressed: () => _open(PlayerPanel.queue),
          ),
          ValueListenableBuilder(
            valueListenable: player.volume,
            builder: (context, volume, _) => RoundIconButton(
              icon: volume == 0
                  ? Icons.volume_off_rounded
                  : volume < 0.5
                  ? Icons.volume_down_rounded
                  : Icons.volume_up_rounded,
              tooltip: volume == 0 ? '取消静音 (M)' : '静音 (M)',
              size: 36,
              color: Colors.transparent,
              onPressed: player.toggleMute,
            ),
          ),
          Flexible(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 110),
              child: const _VolumeSlider(),
            ),
          ),
        ],
      ),
    );
  }
}

class _VolumeSlider extends StatelessWidget {
  const _VolumeSlider();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return ValueListenableBuilder(
      valueListenable: app.player.volume,
      builder: (context, volume, _) => SliderTheme(
        data: SliderTheme.of(context).copyWith(
          trackHeight: 3,
          activeTrackColor: s.lime,
          inactiveTrackColor: s.textTertiary.withValues(alpha: 0.25),
          thumbColor: s.lime,
          overlayShape: SliderComponentShape.noOverlay,
          thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 5),
        ),
        child: Semantics(
          label: '音量',
          child: Slider(value: volume, onChanged: app.player.setVolume),
        ),
      ),
    );
  }
}

// ----------------------------------------------------------------- shared

class _Cover extends StatelessWidget {
  const _Cover({required this.song, required this.size, required this.inset});

  final Song song;
  final double size;

  /// Gap between the cover and the bar's edge; the corner radius is the bar's
  /// minus this so both curves share a centre.
  final double inset;

  @override
  Widget build(BuildContext context) {
    // Flies to / from the disc on the now playing page.
    return NowPlayingCoverHero(
      url: song.album.picUrl,
      isPlayer: false,
      child: SizedBox.square(
        dimension: size,
        child: AnimatedSwitcher(
          duration: AppMotion.emphasized,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          child: CoverImage(
            key: ValueKey(song.album.picUrl),
            url: song.album.picUrl,
            size: 160,
            width: size,
            height: size,
            radius: AppMetrics.radiusLg - inset,
          ),
        ),
      ),
    );
  }
}

class _TitleSwitcher extends StatelessWidget {
  const _TitleSwitcher({required this.song, this.large = false});

  final Song song;
  final bool large;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return AnimatedSwitcher(
      duration: AppMotion.standard,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      layoutBuilder: (current, previous) => Stack(
        alignment: Alignment.centerLeft,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.25),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(song.id),
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodyMedium?.copyWith(
              fontWeight: FontWeight.w600,
              fontSize: large ? 15 : 14,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            song.artistText,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: context.text.bodySmall?.copyWith(color: s.textSecondary),
          ),
        ],
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  const _PlayButton({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.playback,
      builder: (context, playback, _) => AccentPlayButton(
        size: size,
        color: color,
        iconColor: context.surfaces.onLime,
        playing: playback.playing,
        loading: playback.loading && !playback.playing,
        onPressed: app.player.togglePlayPause,
      ),
    );
  }
}

/// 2 px progress line under the compact bar.
class _ProgressLine extends StatefulWidget {
  const _ProgressLine({required this.color});

  final Color color;

  @override
  State<_ProgressLine> createState() => _ProgressLineState();
}

class _ProgressLineState extends State<_ProgressLine> {
  late final ProgressPulse _pulse = ProgressPulse(() {
    final player = app.player;
    final known = player.position.value.duration;
    final duration = known > Duration.zero
        ? known
        : (player.currentSong?.duration ?? Duration.zero);
    return ProgressPulse.intervalFor(duration, _pixels);
  });

  double _pixels = 0;
  bool _visible = true;

  @override
  void initState() {
    super.initState();
    app.player.playback.addListener(_sync);
    _sync();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final visible = TickerMode.valuesOf(context).enabled;
    if (visible != _visible) {
      _visible = visible;
      _sync();
    }
  }

  @override
  void dispose() {
    app.player.playback.removeListener(_sync);
    _pulse.dispose();
    super.dispose();
  }

  void _sync() {
    final playing = app.player.playback.value.playing && _visible;
    if (playing && !_pulse.isActive) {
      _pulse.start();
    } else if (!playing && _pulse.isActive) {
      _pulse.stop();
      setState(() {});
    }
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        _pixels = constraints.maxWidth * MediaQuery.devicePixelRatioOf(context);
        return RepaintBoundary(
          child: CustomPaint(
            size: constraints.biggest,
            painter: _LinePainter(
              repaint: _pulse,
              color: widget.color,
              track: context.surfaces.textTertiary.withValues(alpha: 0.2),
            ),
          ),
        );
      },
    );
  }
}

class _LinePainter extends CustomPainter {
  _LinePainter({
    required Listenable repaint,
    required this.color,
    required this.track,
  }) : super(repaint: repaint);

  final Color color;
  final Color track;

  @override
  void paint(Canvas canvas, Size size) {
    final player = app.player;
    final known = player.position.value.duration;
    final duration = known > Duration.zero
        ? known
        : (player.currentSong?.duration ?? Duration.zero);
    final position = player.clock.now();
    final fraction = duration.inMilliseconds <= 0
        ? 0.0
        : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);
    final radius = Radius.circular(size.height / 2);
    canvas
      ..drawRRect(
        RRect.fromRectAndRadius(Offset.zero & size, radius),
        Paint()..color = track,
      )
      ..drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(0, 0, size.width * fraction, size.height),
          radius,
        ),
        Paint()..color = color,
      );
  }

  @override
  bool shouldRepaint(_LinePainter oldDelegate) =>
      oldDelegate.color != color || oldDelegate.track != track;
}

class _EmptyBar extends StatelessWidget {
  const _EmptyBar({required this.height});

  final double height;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return SizedBox(
      height: height,
      child: Row(
        children: [
          SizedBox(width: height > 70 ? 22 : 14),
          Container(
            width: height - 22,
            height: height - 22,
            decoration: BoxDecoration(
              color: s.chip,
              borderRadius: BorderRadius.circular(AppMetrics.radiusLg - 11),
            ),
            child: Icon(Icons.music_note_rounded, color: s.textTertiary),
          ),
          const SizedBox(width: 12),
          Text(
            '选首歌开始吧',
            style: context.text.bodyMedium?.copyWith(color: s.textSecondary),
          ),
        ],
      ),
    );
  }
}
