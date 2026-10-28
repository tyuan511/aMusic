import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../models/playlist.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../services/player_service.dart' show RadioKind;
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/sheets.dart';
import '../login/login_dialog.dart';
import '../shell.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';

/// One card of the home hero carousel.
class HeroItem {
  const HeroItem({
    required this.title,
    required this.description,
    required this.color,
    required this.onTap,
    this.eyebrow,
    this.coverUrl,
    this.icon,
    this.play,
    this.onLike,
    this.liked = false,
    this.onMore,
  });

  final String title;
  final String description;
  final String? eyebrow;
  final Color color;
  final String? coverUrl;

  /// Big glyph shown instead of artwork (FM, heart mode, sign in).
  final IconData? icon;
  final VoidCallback onTap;

  /// Play button; `null` hides it.
  final Widget? play;
  final VoidCallback? onLike;
  final bool liked;
  final VoidCallback? onMore;
}

/// Builds the carousel cards: daily / FM / heart mode (or a sign-in card)
/// followed by up to two featured playlists.
List<HeroItem> buildHeroItems(
  BuildContext context, {
  required bool loggedIn,
  required List<Playlist> featured,
}) {
  final s = context.surfaces;
  final now = DateTime.now();
  final items = <HeroItem>[
    if (loggedIn) ...[
      HeroItem(
        eyebrow: '${now.month} 月 ${now.day} 日',
        title: '每日推荐',
        description: '根据你的听歌口味生成，每天 6:00 更新',
        color: s.lavender,
        icon: Icons.today_rounded,
        onTap: () => openDailyRecommend(context),
        play: CollectionPlayButton(
          sourceId: Playlist.dailyRecommendId,
          sourceTitle: '每日歌曲推荐',
          accent: true,
          size: 52,
          color: s.plum,
          iconColor: Colors.white,
          load: () async =>
              (await app.library.playlistDetail(Playlist.dailyRecommendId))
                  .tracks,
        ),
      ),
      HeroItem(
        eyebrow: 'Personal FM',
        title: '私人漫游',
        description: '一首接一首，为你挑选可能喜欢的歌',
        color: s.peach,
        icon: Icons.radio_rounded,
        onTap: () => _start(context, app.player.startPersonalFm),
        play: _AsyncPlayButton(
          color: const Color(0xFF5A2A10),
          onStart: app.player.startPersonalFm,
        ),
      ),
      HeroItem(
        eyebrow: 'Heartbeat',
        title: '心动模式',
        description: '从你喜欢的音乐出发，智能推荐相似的好歌',
        color: const Color(0xFFFF8FA8),
        icon: Icons.favorite_rounded,
        onTap: () => _startHeart(context),
        play: _AsyncPlayButton(
          color: const Color(0xFF4A1426),
          onStart: () => _startHeart(context),
        ),
      ),
    ] else
      HeroItem(
        eyebrow: 'aMusic',
        title: '登录网易云音乐',
        description: '扫码登录，同步你的歌单、红心与每日推荐',
        color: s.lavender,
        icon: Icons.qr_code_2_rounded,
        onTap: () => showLoginDialog(context),
        play: _AsyncPlayButton(
          color: s.plum,
          icon: Icons.login_rounded,
          onStart: () => showLoginDialog(context),
        ),
      ),
    for (final playlist in featured.take(2))
      HeroItem(
        eyebrow: '精选歌单',
        title: playlist.name,
        description: (playlist.description ?? '').trim().isEmpty
            ? '${playlist.trackCount} 首精选好歌'
            : playlist.description!.trim(),
        color: const Color(0xFF7FD1E8),
        coverUrl: playlist.coverUrl,
        onTap: () => openPlaylist(context, playlist),
        play: CollectionPlayButton(
          sourceId: playlist.id,
          sourceTitle: playlist.name,
          accent: true,
          size: 52,
          color: const Color(0xFF0E3440),
          iconColor: Colors.white,
          load: () async =>
              (await app.library.playlistDetail(playlist.id)).tracks,
        ),
        onLike: loggedIn ? () => _subscribe(context, playlist) : null,
        onMore: () => openPlaylist(context, playlist),
      ),
  ];
  return items;
}

Future<void> _start(BuildContext context, Future<void> Function() start) async {
  try {
    await start();
  } on Object catch (error) {
    if (context.mounted) showToast(context, describeError(error));
  }
}

/// Starts heart mode from the liked songs and opens the player on success.
Future<void> _startHeart(BuildContext context) async {
  await _start(context, app.player.startHeartMode);
  if (context.mounted && app.player.radioKind.value == RadioKind.heart) {
    openPlayer(context);
  }
}

Future<void> _subscribe(BuildContext context, Playlist playlist) async {
  try {
    await app.library.subscribePlaylist(playlist.id, subscribe: true);
    if (context.mounted) showToast(context, '已收藏「${playlist.name}」');
  } on Object catch (error) {
    if (context.mounted) showToast(context, describeError(error));
  }
}

/// Round play button with a spinner while [onStart] runs.
class _AsyncPlayButton extends StatefulWidget {
  const _AsyncPlayButton({
    required this.color,
    required this.onStart,
    this.icon = Icons.play_arrow_rounded,
  });

  final Color color;

  final Future<Object?> Function() onStart;
  final IconData icon;

  @override
  State<_AsyncPlayButton> createState() => _AsyncPlayButtonState();
}

class _AsyncPlayButtonState extends State<_AsyncPlayButton> {
  bool _busy = false;

  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await widget.onStart();
    } on Object catch (error) {
      if (mounted) showToast(context, describeError(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AccentPlayButton(
      playing: false,
      loading: _busy,
      size: 52,
      color: widget.color,
      iconColor: Colors.white,
      onPressed: _run,
    );
  }
}

/// Horizontal carousel of big rounded hero cards; the next card peeks, the
/// artwork moves with a parallax offset and page dots animate.
class HeroCarousel extends StatefulWidget {
  const HeroCarousel({super.key, required this.items});

  final List<HeroItem> items;

  @override
  State<HeroCarousel> createState() => _HeroCarouselState();
}

class _HeroCarouselState extends State<HeroCarousel> {
  PageController? _controller;
  double _fraction = 0;
  final ValueNotifier<int> _page = ValueNotifier(0);

  @override
  void dispose() {
    _controller?.dispose();
    _page.dispose();
    super.dispose();
  }

  PageController _controllerFor(double fraction) {
    if (_controller == null || _fraction != fraction) {
      final initial = _controller?.hasClients ?? false
          ? (_controller!.page ?? 0).round()
          : 0;
      // The PageView still holds the old controller until it rebuilds.
      final old = _controller;
      if (old != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) => old.dispose());
      }
      _fraction = fraction;
      _controller = PageController(
        viewportFraction: fraction,
        initialPage: initial,
      );
    }
    return _controller!;
  }

  @override
  Widget build(BuildContext context) {
    final compact = ShellLayout.compactOf(context);
    final items = widget.items;
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final cardWidth = compact ? width * 0.86 : 460.0;
        final fraction = (cardWidth / width).clamp(0.3, 1.0);
        final controller = _controllerFor(
          double.parse(fraction.toStringAsFixed(2)),
        );
        return Column(
          children: [
            SizedBox(
              height: compact ? 216 : 236,
              child: PageView.builder(
                controller: controller,
                padEnds: false,
                clipBehavior: Clip.none,
                itemCount: items.length,
                onPageChanged: (page) => _page.value = page,
                itemBuilder: (context, index) => Padding(
                  padding: EdgeInsets.only(
                    left: index == 0 ? AppMetrics.gutter : 7,
                    right: index == items.length - 1 ? AppMetrics.gutter : 7,
                  ),
                  child: AnimatedBuilder(
                    animation: controller,
                    builder: (context, child) {
                      var delta = 0.0;
                      if (controller.hasClients &&
                          controller.position.haveDimensions) {
                        delta = (controller.page ?? 0) - index;
                      }
                      return HeroCard(
                        item: items[index],
                        parallax: delta.clamp(-1.0, 1.0),
                      );
                    },
                  ),
                ),
              ),
            ),
            const SizedBox(height: 14),
            ValueListenableBuilder<int>(
              valueListenable: _page,
              builder: (context, page, _) =>
                  PageDots(count: items.length, index: page),
            ),
          ],
        );
      },
    );
  }
}

/// Animated page indicator: the active dot stretches into a lime pill.
class PageDots extends StatelessWidget {
  const PageDots({super.key, required this.count, required this.index});

  final int count;
  final int index;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    if (count <= 1) return const SizedBox.shrink();
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        for (var i = 0; i < count; i++)
          AnimatedContainer(
            duration: AppMotion.standard,
            curve: AppMotion.enter,
            margin: const EdgeInsets.symmetric(horizontal: 3),
            width: i == index ? 22 : 7,
            height: 7,
            decoration: BoxDecoration(
              color: i == index
                  ? s.lime
                  : s.textTertiary.withValues(alpha: 0.4),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
      ],
    );
  }
}

/// Lavender "Discover weekly" style card: title, two-line description, deep
/// round play button, small actions and artwork bleeding from the right.
class HeroCard extends StatelessWidget {
  const HeroCard({super.key, required this.item, this.parallax = 0});

  final HeroItem item;

  /// -1 … 1 distance from the settled page; shifts the artwork.
  final double parallax;

  @override
  Widget build(BuildContext context) {
    final dark =
        ThemeData.estimateBrightnessForColor(item.color) == Brightness.dark;
    final fg = dark ? Colors.white : const Color(0xFF16101C);
    return Pressable(
      onTap: item.onTap,
      pressedScale: 0.98,
      hoverScale: 1.01,
      semanticLabel: item.title,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(AppMetrics.radiusLg + 4),
        child: DecoratedBox(
          decoration: BoxDecoration(color: item.color),
          child: Stack(
            children: [
              Positioned(
                right: -36 + parallax * 40,
                top: 18,
                bottom: -22,
                child: Transform.rotate(
                  angle: 0.14,
                  child: AspectRatio(
                    aspectRatio: 1,
                    child: _Artwork(item: item, fg: fg),
                  ),
                ),
              ),
              Positioned.fill(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: [item.color, item.color.withValues(alpha: 0)],
                      stops: const [0.42, 0.8],
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(22, 20, 18, 18),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (item.eyebrow != null)
                      Text(
                        item.eyebrow!,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.65),
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.6,
                        ),
                      ),
                    const SizedBox(height: 4),
                    FractionallySizedBox(
                      widthFactor: 0.66,
                      child: Text(
                        item.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg,
                          fontSize: 25,
                          height: 1.2,
                          fontWeight: FontWeight.w600,
                          letterSpacing: -0.5,
                        ),
                      ),
                    ),
                    const SizedBox(height: 6),
                    FractionallySizedBox(
                      widthFactor: 0.6,
                      child: Text(
                        item.description,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: fg.withValues(alpha: 0.72),
                          fontSize: 13,
                          height: 1.4,
                        ),
                      ),
                    ),
                    const Spacer(),
                    Row(
                      children: [
                        ?item.play,
                        const SizedBox(width: 6),
                        if (item.onLike != null)
                          _CardIcon(
                            icon: Icons.favorite_border_rounded,
                            tooltip: '收藏',
                            color: fg,
                            onTap: item.onLike!,
                          ),
                        if (item.onMore != null)
                          _CardIcon(
                            icon: Icons.more_horiz_rounded,
                            tooltip: '更多',
                            color: fg,
                            onTap: item.onMore!,
                          ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Artwork extends StatelessWidget {
  const _Artwork({required this.item, required this.fg});

  final HeroItem item;
  final Color fg;

  @override
  Widget build(BuildContext context) {
    if (item.coverUrl != null) {
      return DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.25),
              blurRadius: 24,
              offset: const Offset(-6, 10),
            ),
          ],
        ),
        child: CoverImage(
          url: item.coverUrl,
          size: 400,
          radius: AppMetrics.radiusLg,
        ),
      );
    }
    return DecoratedBox(
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.42),
            Colors.white.withValues(alpha: 0.0),
          ],
        ),
      ),
      child: Center(
        child: Icon(item.icon, size: 96, color: fg.withValues(alpha: 0.22)),
      ),
    );
  }
}

class _CardIcon extends StatelessWidget {
  const _CardIcon({
    required this.icon,
    required this.tooltip,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String tooltip;
  final Color color;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Pressable(
        onTap: onTap,
        hoverScale: 1.12,
        semanticLabel: tooltip,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 21, color: color.withValues(alpha: 0.8)),
        ),
      ),
    );
  }
}
