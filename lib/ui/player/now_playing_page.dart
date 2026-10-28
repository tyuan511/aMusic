import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/physics.dart';
import 'package:just_audio/just_audio.dart';

import '../../core/config.dart';
import '../../models/comment_target.dart';
import '../../models/loop_mode.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../services/player_service.dart';
import '../../theme/app_theme.dart';
import '../eq/equalizer_sheet.dart';
import '../shared/comments_view.dart';
import '../shared/playlist_picker.dart';
import '../shortcuts.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/seek_bar.dart';
import '../widgets/song_menu.dart';
import 'lyrics_view.dart';
import 'player_backdrop.dart';
import 'player_panel_controller.dart';
import 'player_sheets.dart';
import 'player_transition.dart';
import 'queue_view.dart';

/// Full screen player.
///
/// Compact (phones): header, circular cover with a 3 line lyric preview (or
/// the full lyrics), transport and a secondary action row; queue and
/// comments open as sheets; pull down to close. Wide (desktop / tablet
/// landscape): cover + info + controls on the left, a 歌词 / 播放队列 / 评论
/// switcher on the right.
class NowPlayingPage extends StatefulWidget {
  const NowPlayingPage({super.key, this.panel = PlayerPanel.cover});

  /// Panel to open on (cover / lyrics / queue / comments).
  final PlayerPanel panel;

  @override
  State<NowPlayingPage> createState() => _NowPlayingPageState();
}

class _NowPlayingPageState extends State<NowPlayingPage>
    with SingleTickerProviderStateMixin {
  late PlayerPanel _panel = widget.panel;
  bool _wide = false;

  /// Sheet panel currently open over the compact page.
  PlayerPanel? _sheet;
  int _sheetToken = 0;

  late final AnimationController _pull = AnimationController.unbounded(
    vsync: this,
  );
  double _height = 800;
  bool _closing = false;

  PlayerPanelController get _controller => PlayerPanelController.instance;

  @override
  void initState() {
    super.initState();
    _controller.isOpen.value = true;
    _controller.visibleResolver = () => _visiblePanel;
    _controller.request.addListener(_onRequest);
    if (widget.panel == PlayerPanel.queue ||
        widget.panel == PlayerPanel.comments) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_wide) _openSheet(widget.panel);
      });
    }
  }

  @override
  void dispose() {
    _controller.request.removeListener(_onRequest);
    _controller.isOpen.value = false;
    _controller.visibleResolver = null;
    _pull.dispose();
    super.dispose();
  }

  PlayerPanel get _compactPanel =>
      _panel == PlayerPanel.lyrics ? PlayerPanel.lyrics : PlayerPanel.cover;

  PlayerPanel get _widePanel =>
      _panel == PlayerPanel.cover ? PlayerPanel.lyrics : _panel;

  PlayerPanel get _visiblePanel =>
      _wide ? _widePanel : (_sheet ?? _compactPanel);

  void _onRequest() {
    final panel = _controller.request.value;
    if (panel == null || !mounted) return;
    _controller.request.value = null;
    _select(panel);
  }

  void _select(PlayerPanel panel) {
    if (_wide) {
      setState(() => _panel = panel);
      return;
    }
    if (panel == PlayerPanel.queue || panel == PlayerPanel.comments) {
      _openSheet(panel);
      return;
    }
    if (_sheet != null) Navigator.of(context).pop();
    setState(() => _panel = panel);
  }

  Future<void> _openSheet(PlayerPanel panel) async {
    if (_sheet == panel) {
      Navigator.of(context).pop();
      return;
    }
    if (_sheet != null) Navigator.of(context).pop();
    final token = ++_sheetToken;
    _sheet = panel;
    if (panel == PlayerPanel.queue) {
      await showQueueSheet(context);
    } else {
      await showCurrentComments(context);
    }
    if (token == _sheetToken) _sheet = null;
  }

  // ---------------------------------------------------------- pull to close

  void _onPullUpdate(DragUpdateDetails details) {
    if (_closing) return;
    _pull.value = math.max(0, _pull.value + details.delta.dy);
  }

  void _onPullEnd(DragEndDetails details) {
    if (_closing) return;
    final velocity = details.velocity.pixelsPerSecond.dy;
    if (_pull.value > _height * 0.22 || velocity > 900) {
      _closing = true;
      // Leave the page where the finger let go: the route transition shrinks
      // it (and flies the cover) back into the mini player from there.
      Navigator.of(context).maybePop();
      return;
    }
    _pull.animateWith(
      SpringSimulation(
        SpringDescription.withDampingRatio(mass: 1, stiffness: 260, ratio: 0.8),
        _pull.value,
        0,
        velocity,
      ),
    );
  }

  Widget _pullRegion(Widget child) => GestureDetector(
    behavior: HitTestBehavior.translucent,
    onVerticalDragUpdate: _onPullUpdate,
    onVerticalDragEnd: _onPullEnd,
    onVerticalDragCancel: () => _onPullEnd(DragEndDetails()),
    child: child,
  );

  KeyEventResult _onKey(FocusNode node, KeyEvent event) {
    final focused = FocusManager.instance.primaryFocus?.context?.widget;
    if (focused is EditableText) return KeyEventResult.ignored;
    return handleAppShortcut(event)
        ? KeyEventResult.handled
        : KeyEventResult.ignored;
  }

  // ------------------------------------------------------------------ build

  @override
  Widget build(BuildContext context) {
    Widget page = Scaffold(
      backgroundColor: context.isDark ? Colors.black : Colors.white,
      body: Stack(
        children: [
          const Positioned.fill(child: PlayerBackdrop()),
          Positioned.fill(
            child: LayoutBuilder(
              builder: (context, constraints) {
                _height = constraints.maxHeight;
                // Short, wide screens (car head units) get the side by side
                // layout too; it scales itself down to fit.
                _wide =
                    constraints.maxWidth >= Breakpoints.compact &&
                    (constraints.maxHeight >= 520 ||
                        (constraints.maxHeight >= 420 &&
                            constraints.maxWidth / constraints.maxHeight >=
                                1.5));
                final body = SafeArea(
                  child: ValueListenableBuilder(
                    valueListenable: app.player.currentSongId,
                    builder: (context, _, _) {
                      final song = app.player.currentSong;
                      if (_wide) return _wideLayout(song);
                      return _compactLayout(song);
                    },
                  ),
                );
                return AnimatedBuilder(
                  animation: _pull,
                  builder: (context, child) {
                    final pulled = math.max(0.0, _pull.value);
                    final t = (pulled / _height).clamp(0.0, 1.0);
                    return Transform.translate(
                      offset: Offset(0, pulled),
                      child: Transform.scale(
                        scale: 1 - 0.06 * t,
                        child: Opacity(opacity: 1 - 0.4 * t, child: child),
                      ),
                    );
                  },
                  child: body,
                );
              },
            ),
          ),
        ],
      ),
    );
    page = AccentScope(accent: app.accent, child: page);
    if (Platforms.isDesktop) {
      page = Focus(autofocus: true, onKeyEvent: _onKey, child: page);
    }
    return page;
  }

  // ---------------------------------------------------------------- compact

  Widget _compactLayout(Song? song) {
    final lyrics = _compactPanel == PlayerPanel.lyrics;
    return Column(
      children: [
        _pullRegion(
          PlayerEntrance(
            delay: 0,
            offset: const Offset(0, -16),
            child: _Header(
              song: song,
              title: lyrics && song != null
                  ? _CompactTrackInfo(
                      song: song,
                      onTap: () => _select(PlayerPanel.cover),
                    )
                  : null,
            ),
          ),
        ),
        Expanded(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 280),
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: (child, animation) => FadeTransition(
              opacity: animation,
              child: ScaleTransition(
                scale: Tween(begin: 0.96, end: 1.0).animate(animation),
                child: child,
              ),
            ),
            child: song == null
                ? const _NothingPlaying(key: ValueKey('empty'))
                : lyrics
                ? const PlayerEntrance(
                    key: ValueKey('lyrics'),
                    delay: 0.1,
                    child: LyricsPanel(),
                  )
                : _pullRegion(
                    _CompactCover(
                      key: const ValueKey('cover'),
                      song: song,
                      onLyrics: () => _select(PlayerPanel.lyrics),
                    ),
                  ),
          ),
        ),
        const PlayerEntrance(
          delay: 0.22,
          child: Padding(
            padding: EdgeInsets.fromLTRB(28, 4, 28, 0),
            child: _Transport(),
          ),
        ),
        PlayerEntrance(
          delay: 0.3,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
            child: _SecondaryActions(song: song),
          ),
        ),
      ],
    );
  }

  // ------------------------------------------------------------------- wide

  Widget _wideLayout(Song? song) {
    final panel = _widePanel;
    return Column(
      children: [
        PlayerEntrance(
          delay: 0,
          offset: const Offset(0, -16),
          child: _Header(song: song),
        ),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(40, 8, 24, 24),
            child: Row(
              children: [
                Expanded(
                  flex: 5,
                  child: song == null
                      ? const _NothingPlaying()
                      : _WideInfo(song: song),
                ),
                const SizedBox(width: 36),
                Expanded(
                  flex: 6,
                  child: PlayerEntrance(
                    delay: 0.16,
                    offset: const Offset(36, 0),
                    child: Column(
                      children: [
                        ChipBar<PlayerPanel>(
                          values: const [
                            PlayerPanel.lyrics,
                            PlayerPanel.queue,
                            PlayerPanel.comments,
                          ],
                          selected: panel,
                          dense: true,
                          padding: EdgeInsets.zero,
                          labelOf: (panel) => switch (panel) {
                            PlayerPanel.queue => '播放队列',
                            PlayerPanel.comments => '评论',
                            _ => '歌词',
                          },
                          onSelected: _select,
                        ),
                        const SizedBox(height: 12),
                        Expanded(
                          child: AnimatedSwitcher(
                            duration: AppMotion.standard,
                            switchInCurve: AppMotion.enter,
                            switchOutCurve: AppMotion.exit,
                            transitionBuilder: (child, animation) =>
                                FadeTransition(
                                  opacity: animation,
                                  child: SlideTransition(
                                    position: Tween(
                                      begin: const Offset(0.025, 0),
                                      end: Offset.zero,
                                    ).animate(animation),
                                    child: child,
                                  ),
                                ),
                            child: KeyedSubtree(
                              key: ValueKey(panel),
                              child: _widePanelBody(panel, song),
                            ),
                          ),
                        ),
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

  Widget _widePanelBody(PlayerPanel panel, Song? song) {
    switch (panel) {
      case PlayerPanel.queue:
        return const QueueView(embedded: true);
      case PlayerPanel.comments:
        if (song == null || song.id <= 0) {
          return const Center(child: Text('本地歌曲没有评论'));
        }
        return CommentsView(
          key: ValueKey(song.id),
          target: CommentTarget(
            CommentResource.song,
            song.id,
            title: song.name,
          ),
          embedded: true,
        );
      case PlayerPanel.cover:
      case PlayerPanel.lyrics:
        return const LyricsPanel();
    }
  }
}

// ------------------------------------------------------------------ header

class _Header extends StatelessWidget {
  const _Header({required this.song, this.title});

  final Song? song;

  /// Shown between the two buttons, e.g. the track on the compact lyrics page.
  final Widget? title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
      child: SizedBox(
        height: 52,
        child: Row(
          children: [
            RoundIconButton(
              icon: Icons.keyboard_arrow_down_rounded,
              tooltip: '收起',
              color: context.playerInk.withValues(alpha: 0.12),
              iconColor: context.playerInk,
              onPressed: () => Navigator.of(context).maybePop(),
            ),
            title == null
                ? const Spacer()
                : Expanded(
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: title,
                    ),
                  ),
            _LikeRoundButton(song: song),
          ],
        ),
      ),
    );
  }
}

class _LikeRoundButton extends StatelessWidget {
  const _LikeRoundButton({required this.song});

  final Song? song;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    return ValueListenableBuilder(
      valueListenable: app.library.likedIds,
      builder: (context, liked, _) {
        final isLiked = song != null && liked.contains(song.id);
        return RoundIconButton(
          icon: isLiked
              ? Icons.favorite_rounded
              : Icons.favorite_border_rounded,
          tooltip: isLiked ? '取消喜欢' : '喜欢',
          color: context.playerInk.withValues(alpha: 0.12),
          iconColor: isLiked ? const Color(0xFFFF5C8A) : context.playerInk,
          onPressed: song == null || song.id <= 0
              ? null
              : () async {
                  final messenger = ScaffoldMessenger.maybeOf(context);
                  final ok = await app.library.toggleLike(
                    song.id,
                    like: !isLiked,
                  );
                  if (!ok) {
                    messenger?.showSnackBar(
                      const SnackBar(content: Text('操作失败，请先登录')),
                    );
                  }
                },
        );
      },
    );
  }
}

// ------------------------------------------------------------------- cover

class _CompactCover extends StatelessWidget {
  const _CompactCover({super.key, required this.song, required this.onLyrics});

  final Song song;
  final VoidCallback onLyrics;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        const below = 96.0 + 104 + 28;
        final size = math.max(
          120.0,
          math.min(constraints.maxWidth - 72, constraints.maxHeight - below),
        );
        return Column(
          children: [
            const Spacer(),
            CircularCover(size: math.min(size, 380), onTap: onLyrics),
            const Spacer(),
            PlayerEntrance(
              delay: 0.12,
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: _TitleBlock(song: song),
              ),
            ),
            const SizedBox(height: 10),
            PlayerEntrance(delay: 0.18, child: LyricsPreview(onTap: onLyrics)),
            const SizedBox(height: 4),
          ],
        );
      },
    );
  }
}

/// Cover thumbnail and title for the header of the compact lyrics page; tapping
/// it goes back to the cover.
class _CompactTrackInfo extends StatelessWidget {
  const _CompactTrackInfo({required this.song, required this.onTap});

  final Song song;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Pressable(
      onTap: onTap,
      pressedScale: 0.98,
      child: Row(
        children: [
          CoverImage(
            url: song.album.picUrl,
            size: 120,
            width: 40,
            height: 40,
            radius: AppMetrics.radiusSm,
          ),
          const SizedBox(width: 10),
          Expanded(child: _TitleBlock(song: song, compact: true)),
        ],
      ),
    );
  }
}

/// Big rounded-square album art. Scales to 0.92 when paused with a spring and
/// cross-fades on track change.
class CircularCover extends StatelessWidget {
  const CircularCover({super.key, required this.size, this.onTap});

  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.currentSongId,
      builder: (context, _, _) {
        final url = app.player.currentSong?.album.picUrl;
        return Pressable(
          onTap: onTap,
          pressedScale: 0.97,
          semanticLabel: '查看歌词',
          child: _PlayingSpring(
            // Flies to / from the mini player's cover.
            child: NowPlayingCoverHero(
              url: url,
              isPlayer: true,
              accent: AccentScope.maybeOf(context) ?? context.surfaces.lavender,
              child: SizedBox.square(
                dimension: size,
                child: AnimatedSwitcher(
                  duration: AppMotion.emphasized,
                  switchInCurve: AppMotion.enter,
                  switchOutCurve: AppMotion.exit,
                  transitionBuilder: (child, animation) => FadeTransition(
                    opacity: animation,
                    child: ScaleTransition(
                      scale: Tween(begin: 0.9, end: 1.0).animate(animation),
                      child: child,
                    ),
                  ),
                  child: _Disc(key: ValueKey(url), url: url, size: size),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _Disc extends StatelessWidget {
  const _Disc({super.key, required this.url, required this.size});

  final String? url;
  final double size;

  @override
  Widget build(BuildContext context) {
    final accent = AccentScope.maybeOf(context) ?? context.surfaces.lavender;
    final radius = BorderRadius.circular(AppMetrics.radiusLg);
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 40,
            offset: const Offset(0, 22),
          ),
          BoxShadow(
            color: accent.withValues(alpha: 0.32),
            blurRadius: 70,
            spreadRadius: -8,
          ),
        ],
      ),
      position: DecorationPosition.background,
      child: ClipRRect(
        borderRadius: radius,
        child: DecoratedBox(
          position: DecorationPosition.foreground,
          decoration: BoxDecoration(
            borderRadius: radius,
            border: Border.all(
              color: context.playerInk.withValues(alpha: 0.08),
              width: 1,
            ),
          ),
          child: CoverImage(
            url: url,
            size: (size * 2).clamp(300, 1000).round(),
            width: size,
            height: size,
            radius: 0,
          ),
        ),
      ),
    );
  }
}

/// 1.0 while playing, 0.92 when paused, moved by a spring. While playing the
/// cover also breathes by a subtle ~2% on the shared ~30 fps [AmbientClock]
/// (not at all in low performance mode).
class _PlayingSpring extends StatefulWidget {
  const _PlayingSpring({required this.child});

  final Widget child;

  @override
  State<_PlayingSpring> createState() => _PlayingSpringState();
}

class _PlayingSpringState extends State<_PlayingSpring>
    with TickerProviderStateMixin, AmbientMotion {
  static final SpringDescription _spring = SpringDescription.withDampingRatio(
    mass: 1,
    stiffness: 180,
    ratio: 0.62,
  );

  late final AnimationController _scale = AnimationController.unbounded(
    vsync: this,
    value: _target,
  );

  /// 0 - 1 breath; driven by [onAmbientTick], eased out by itself.
  late final AnimationController _breath = AnimationController(vsync: this);

  /// One way of the breath (in, then out over as long again).
  static const int _breathMs = 3200;
  final Stopwatch _breathClock = Stopwatch();
  int _breathOffsetMs = 0;

  double get _target => app.player.playback.value.playing ? 1.0 : 0.92;

  bool _breathing = false;

  @override
  void initState() {
    super.initState();
    app.player.playback.addListener(_onPlayback);
    app.settings.addListener(_syncBreath);
    _syncBreath();
  }

  @override
  void dispose() {
    app.player.playback.removeListener(_onPlayback);
    app.settings.removeListener(_syncBreath);
    _breath.dispose();
    _scale.dispose();
    super.dispose();
  }

  double _last = -1;

  // Hot reload keeps the old state without re-running initState.
  @override
  void reassemble() {
    super.reassemble();
    _breathing = false;
    _syncBreath();
  }

  void _syncBreath() {
    final breathe =
        app.player.playback.value.playing && !app.settings.value.lowPerformance;
    if (breathe == _breathing) return;
    _breathing = breathe;
    if (breathe) {
      // Continue from wherever the ease out left the cover.
      _breath.stop();
      _breathOffsetMs = (_breath.value * _breathMs).round();
      _breathClock
        ..reset()
        ..start();
    } else {
      _breathClock.stop();
      _breath.animateTo(0, duration: AppMotion.standard, curve: Curves.easeOut);
    }
    runAmbient(breathe);
  }

  @override
  void onAmbientTick() {
    final ms =
        (_breathClock.elapsedMilliseconds + _breathOffsetMs) % (_breathMs * 2);
    _breath.value = ms < _breathMs ? ms / _breathMs : 2 - ms / _breathMs;
  }

  void _onPlayback() {
    final target = _target;
    if (target == _last) return;
    _last = target;
    _syncBreath();
    _scale.animateWith(
      SpringSimulation(_spring, _scale.value, target, _scale.velocity),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: Listenable.merge([_scale, _breath]),
      child: widget.child,
      builder: (context, child) => Transform.scale(
        scale:
            _scale.value *
            (1 + 0.02 * Curves.easeInOut.transform(_breath.value)),
        child: child,
      ),
    );
  }
}

// ---------------------------------------------------------------- titles

class _TitleBlock extends StatelessWidget {
  const _TitleBlock({required this.song, this.compact = false});

  final Song song;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final centred = !compact;
    return AnimatedSwitcher(
      duration: AppMotion.standard,
      switchInCurve: AppMotion.enter,
      switchOutCurve: AppMotion.exit,
      // The default stack centres its children, which pushed the compact
      // (left-aligned) title away from the cover thumbnail.
      layoutBuilder: (current, previous) => Stack(
        alignment: compact ? Alignment.centerLeft : Alignment.center,
        children: [...previous, ?current],
      ),
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: SlideTransition(
          position: Tween(
            begin: const Offset(0, 0.15),
            end: Offset.zero,
          ).animate(animation),
          child: child,
        ),
      ),
      child: Column(
        key: ValueKey(song.id),
        crossAxisAlignment: compact
            ? CrossAxisAlignment.start
            : CrossAxisAlignment.center,
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            song.name,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            textAlign: centred ? TextAlign.center : TextAlign.start,
            style: TextStyle(
              color: context.playerInk,
              fontSize: compact ? 16 : 22,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.3,
            ),
          ),
          SizedBox(height: compact ? 2 : 6),
          _ArtistLine(song: song, centred: centred, small: compact),
          if (!compact) ...[const SizedBox(height: 8), const _QualityChip()],
        ],
      ),
    );
  }
}

/// Opens [open] after closing the player, so detail pages land in the shell.
void _openFromPlayer(BuildContext context, void Function(BuildContext) open) {
  Navigator.of(context).maybePop();
  WidgetsBinding.instance.addPostFrameCallback((_) {
    final root = rootNavigatorKey.currentContext;
    if (root != null) open(root);
  });
}

class _ArtistLine extends StatelessWidget {
  const _ArtistLine({
    required this.song,
    required this.centred,
    required this.small,
  });

  final Song song;
  final bool centred;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final style = TextStyle(
      color: context.playerInk.withValues(alpha: 0.68),
      fontSize: small ? 12.5 : 14.5,
      fontWeight: FontWeight.w500,
    );
    final artists = song.artists.take(3).toList();
    Widget link(String text, VoidCallback? onTap) => Pressable(
      onTap: onTap,
      pressedScale: 0.96,
      child: Text(text, style: style, maxLines: 1),
    );
    final parts = <Widget>[
      if (artists.isEmpty) Text('未知歌手', style: style),
      for (var i = 0; i < artists.length; i++) ...[
        if (i > 0) Text(' / ', style: style),
        link(
          artists[i].name,
          artists[i].id > 0
              ? () => _openFromPlayer(
                  context,
                  (root) => openArtist(root, artists[i].id),
                )
              : null,
        ),
      ],
      if (song.artists.length > 3) Text(' 等', style: style),
      if (!small && song.album.name.isNotEmpty) ...[
        Text('  ·  ', style: style.copyWith(fontSize: 10)),
        Flexible(
          child: Pressable(
            onTap: song.album.id > 0
                ? () => _openFromPlayer(
                    context,
                    (root) => openAlbum(root, song.album.id),
                  )
                : null,
            pressedScale: 0.96,
            child: Text(
              song.album.name,
              style: style,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    ];
    return Row(
      mainAxisSize: MainAxisSize.min,
      mainAxisAlignment: centred
          ? MainAxisAlignment.center
          : MainAxisAlignment.start,
      children: [
        for (final part in parts)
          part is Flexible ? part : Flexible(flex: 0, child: part),
      ],
    );
  }
}

/// Granted quality and the 试听 badge.
class _QualityChip extends StatelessWidget {
  const _QualityChip();

  static String _hint(AudioLevel level) => switch (level) {
    AudioLevel.standard ||
    AudioLevel.higher ||
    AudioLevel.exhigh => '${level.bitrate ~/ 1000} kbps',
    AudioLevel.lossless => 'FLAC',
    _ => '会员音质',
  };

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.player.playback,
      builder: (context, playback, _) {
        final level = playback.level;
        final badge = AnimatedSwitcher(
          duration: AppMotion.standard,
          child: level == null && !playback.isTrial
              ? const SizedBox(key: ValueKey('none'), height: 17)
              : Row(
                  key: ValueKey('$level${playback.isTrial}'),
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (level != null)
                      TagBadge(
                        AudioLevel.fromValue(level).label,
                        color: context.surfaces.lime,
                      ),
                    if (playback.isTrial) ...[
                      const SizedBox(width: 6),
                      TagBadge('试听', color: context.surfaces.peach),
                    ],
                  ],
                ),
        );
        if (level == null && !playback.isTrial) return badge;

        return ValueListenableBuilder(
          valueListenable: app.settings,
          builder: (context, settings, _) => MenuAnchor(
            style: MenuStyle(
              backgroundColor: WidgetStatePropertyAll(context.surfaces.card),
              shape: WidgetStatePropertyAll(
                RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AppMetrics.radiusSm),
                  side: BorderSide(color: context.surfaces.hairline),
                ),
              ),
            ),
            menuChildren: [
              for (final option in AudioLevel.values)
                MenuItemButton(
                  onPressed: () => app.settings.setAudioLevel(option),
                  leadingIcon: AnimatedOpacity(
                    duration: AppMotion.quick,
                    opacity: option == settings.audioLevel ? 1 : 0,
                    child: Icon(
                      Icons.check_rounded,
                      size: 18,
                      color: context.surfaces.lime,
                    ),
                  ),
                  child: SizedBox(
                    width: 170,
                    child: Row(
                      children: [
                        Text(option.label),
                        const Spacer(),
                        Text(
                          _hint(option),
                          style: context.text.bodySmall?.copyWith(
                            color: context.surfaces.textTertiary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
            ],
            builder: (context, controller, _) => Tooltip(
              message: '音源品质：${settings.audioLevel.label}，点击调整',
              child: Pressable(
                onTap: () =>
                    controller.isOpen ? controller.close() : controller.open(),
                semanticLabel: '调整音源品质',
                pressedScale: 0.96,
                child: badge,
              ),
            ),
          ),
        );
      },
    );
  }
}

// -------------------------------------------------------------- transport

class _Transport extends StatelessWidget {
  const _Transport();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SeekBar(
          color: s.lime,
          height: 36,
          trackColor: context.playerInk.withValues(alpha: 0.2),
          spectrum: true,
        ),
        SeekTimeRow(
          style: TextStyle(
            color: context.playerInk.withValues(alpha: 0.6),
            fontSize: 12,
            fontFeatures: const [FontFeature.tabularFigures()],
          ),
        ),
        const SizedBox(height: 10),
        const _MainControls(),
      ],
    );
  }
}

class _MainControls extends StatelessWidget {
  const _MainControls();

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final player = app.player;
    return ValueListenableBuilder(
      valueListenable: player.queue,
      builder: (context, queue, _) => ValueListenableBuilder(
        valueListenable: player.radioKind,
        builder: (context, radio, _) {
          final empty = queue.isEmpty;
          final Widget left = radio == RadioKind.fm
              ? RoundIconButton(
                  icon: Icons.thumb_down_alt_outlined,
                  tooltip: '不喜欢',
                  size: 46,
                  color: Colors.transparent,
                  iconColor: context.playerInk.withValues(alpha: 0.8),
                  onPressed: player.fmTrash,
                )
              : RoundIconButton(
                  icon: Icons.shuffle_rounded,
                  tooltip: queue.shuffle ? '关闭随机播放' : '随机播放',
                  size: 46,
                  color: Colors.transparent,
                  iconColor: queue.shuffle
                      ? s.lime
                      : context.playerInk.withValues(alpha: 0.7),
                  onPressed: empty || radio != null
                      ? null
                      : player.toggleShuffle,
                );
          return Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              left,
              RoundIconButton(
                icon: Icons.skip_previous_rounded,
                tooltip: '上一首',
                size: 58,
                color: context.playerInk.withValues(alpha: 0.1),
                iconColor: context.playerInk,
                onPressed: empty ? null : player.previous,
              ),
              ValueListenableBuilder(
                valueListenable: player.playback,
                builder: (context, playback, _) => AccentPlayButton(
                  size: 78,
                  playing: playback.playing,
                  loading: playback.loading && !playback.playing,
                  onPressed: empty ? null : player.togglePlayPause,
                ),
              ),
              RoundIconButton(
                icon: Icons.skip_next_rounded,
                tooltip: '下一首',
                size: 58,
                color: context.playerInk.withValues(alpha: 0.1),
                iconColor: context.playerInk,
                onPressed: empty ? null : player.next,
              ),
              Builder(
                builder: (context) => RoundIconButton(
                  icon: Icons.queue_music_rounded,
                  tooltip: '播放队列',
                  size: 46,
                  color: Colors.transparent,
                  iconColor: context.playerInk.withValues(alpha: 0.7),
                  onPressed: () => showPlayerPanel(PlayerPanel.queue),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// Repeat · heart mode · add to playlist · equalizer · speed · more. The sleep
/// timer and comments live in the more menu; a running countdown stays visible.
class _SecondaryActions extends StatelessWidget {
  const _SecondaryActions({required this.song});

  final Song? song;

  @override
  Widget build(BuildContext context) {
    final song = this.song;
    final player = app.player;
    final s = context.surfaces;
    final online = song != null && song.id > 0;
    // Every slot is a fixed 40pt box and the gaps are equal, so the icons sit
    // on an even grid whatever the speed label or countdown chip shows.
    return Center(
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 344),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            ValueListenableBuilder(
              valueListenable: player.queue,
              builder: (context, queue, _) => ValueListenableBuilder(
                valueListenable: player.radioMode,
                builder: (context, radio, _) => _IconAction(
                  icon: queue.repeat == LoopMode.one
                      ? Icons.repeat_one_rounded
                      : Icons.repeat_rounded,
                  tooltip: '循环：${queue.repeat.label}',
                  color: queue.repeat == LoopMode.off ? null : s.lime,
                  onTap: queue.isEmpty || radio ? null : player.toggleRepeat,
                ),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: player.radioKind,
              builder: (context, radio, _) => _IconAction(
                icon: radio == RadioKind.heart
                    ? Icons.favorite_rounded
                    : Icons.favorite_border_rounded,
                tooltip: radio == RadioKind.heart ? '关闭心动模式' : '心动模式',
                color: radio == RadioKind.heart ? s.lime : null,
                onTap: radio == RadioKind.fm || !app.session.value.isLoggedIn
                    ? null
                    : player.toggleHeartMode,
              ),
            ),
            _IconAction(
              icon: Icons.playlist_add_rounded,
              tooltip: '收藏到歌单',
              onTap: online ? () => showAddToPlaylist(context, [song]) : null,
            ),
            ValueListenableBuilder(
              valueListenable: player.sleepRemaining,
              builder: (context, remaining, _) => remaining == null
                  ? const SizedBox.shrink()
                  : const SleepCountdownChip(),
            ),
            const _VolumeAction(),
            ValueListenableBuilder(
              valueListenable: app.eq,
              builder: (context, eq, _) => _IconAction(
                icon: Icons.equalizer_rounded,
                tooltip: '音效与均衡器',
                color: eq.settings.isActive ? s.lime : null,
                onTap: () => showEqualizerSheet(context),
              ),
            ),
            ValueListenableBuilder(
              valueListenable: player.speed,
              builder: (context, speed, _) => (speed - 1).abs() < 0.01
                  ? _IconAction(
                      icon: Icons.speed_rounded,
                      tooltip: '播放速度',
                      onTap: () => showSpeedSheet(context),
                    )
                  : Pressable(
                      onTap: () => showSpeedSheet(context),
                      child: SizedBox(
                        width: 40,
                        height: 40,
                        child: Center(
                          child: Text(
                            speedLabel(speed),
                            style: TextStyle(
                              color: s.lime,
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ),
                    ),
            ),
            _IconAction(
              icon: Icons.more_horiz_rounded,
              tooltip: '更多',
              onTap: song == null
                  ? null
                  : () => showSongMenu(context, song, sleepTimer: true),
            ),
          ],
        ),
      ),
    );
  }
}

/// Volume icon that mutes on a long press and opens a slider popover on tap.
class _VolumeAction extends StatelessWidget {
  const _VolumeAction();

  @override
  Widget build(BuildContext context) {
    final player = app.player;
    final s = context.surfaces;
    return ValueListenableBuilder(
      valueListenable: player.volume,
      builder: (context, volume, _) {
        final icon = volume == 0
            ? Icons.volume_off_rounded
            : volume < 0.5
            ? Icons.volume_down_rounded
            : Icons.volume_up_rounded;
        return GestureDetector(
          onLongPress: player.toggleMute,
          child: PopupMenuButton<void>(
            tooltip: '音量（长按静音）',
            padding: EdgeInsets.zero,
            position: PopupMenuPosition.over,
            color: s.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            itemBuilder: (_) => [
              PopupMenuItem<void>(
                enabled: false,
                padding: const EdgeInsets.symmetric(horizontal: 8),
                child: SizedBox(
                  width: 180,
                  child: Row(
                    children: [
                      ValueListenableBuilder(
                        valueListenable: player.volume,
                        builder: (context, v, _) => Icon(
                          v == 0
                              ? Icons.volume_off_rounded
                              : Icons.volume_down_rounded,
                          size: 18,
                          color: s.textSecondary,
                        ),
                      ),
                      Expanded(
                        child: ValueListenableBuilder(
                          valueListenable: player.volume,
                          builder: (context, v, _) => SliderTheme(
                            data: SliderTheme.of(context).copyWith(
                              trackHeight: 3,
                              activeTrackColor: s.lime,
                              inactiveTrackColor: s.textTertiary.withValues(
                                alpha: 0.25,
                              ),
                              thumbColor: s.lime,
                              overlayShape: SliderComponentShape.noOverlay,
                              thumbShape: const RoundSliderThumbShape(
                                enabledThumbRadius: 6,
                              ),
                            ),
                            child: Slider(
                              value: v,
                              onChanged: player.setVolume,
                            ),
                          ),
                        ),
                      ),
                      Icon(
                        Icons.volume_up_rounded,
                        size: 18,
                        color: s.textSecondary,
                      ),
                    ],
                  ),
                ),
              ),
            ],
            child: SizedBox(
              width: 40,
              height: 40,
              child: Icon(
                icon,
                size: 22,
                color: volume == 0
                    ? s.lime
                    : context.playerInk.withValues(alpha: 0.78),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _IconAction extends StatelessWidget {
  const _IconAction({
    required this.icon,
    required this.tooltip,
    this.onTap,
    this.color,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback? onTap;
  final Color? color;

  @override
  Widget build(BuildContext context) {
    final fg = onTap == null
        ? context.playerInk.withValues(alpha: 0.3)
        : (color ?? context.playerInk.withValues(alpha: 0.78));
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        pressedScale: 0.88,
        hoverScale: 1.08,
        child: SizedBox(
          width: 40,
          height: 40,
          child: Stack(
            alignment: Alignment.center,
            children: [
              AnimatedSwitcher(
                duration: AppMotion.quick,
                transitionBuilder: (child, animation) => ScaleTransition(
                  scale: CurvedAnimation(
                    parent: animation,
                    curve: AppMotion.pop,
                  ),
                  child: child,
                ),
                child: Icon(icon, key: ValueKey(icon), size: 22, color: fg),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// -------------------------------------------------------------------- wide

class _WideInfo extends StatelessWidget {
  const _WideInfo({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final cover = math.max(
          160.0,
          math.min(
            math.min(constraints.maxWidth - 40, 440.0),
            constraints.maxHeight - 344,
          ),
        );
        return Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 460),
            // Shrinks the column when the height cannot hold it, instead of
            // overflowing.
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: SizedBox(
                width: math.min(constraints.maxWidth, 460),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularCover(size: cover),
                    const SizedBox(height: 28),
                    PlayerEntrance(delay: 0.1, child: _TitleBlock(song: song)),
                    const SizedBox(height: 18),
                    const PlayerEntrance(delay: 0.18, child: _Transport()),
                    const SizedBox(height: 22),
                    PlayerEntrance(
                      delay: 0.26,
                      child: _SecondaryActions(song: song),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _NothingPlaying extends StatelessWidget {
  const _NothingPlaying({super.key});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.music_note_rounded,
            size: 48,
            color: context.playerInk.withValues(alpha: 0.35),
          ),
          const SizedBox(height: 12),
          Text(
            '选首歌开始吧',
            style: TextStyle(
              color: context.playerInk.withValues(alpha: 0.7),
              fontSize: 15,
            ),
          ),
        ],
      ),
    );
  }
}
