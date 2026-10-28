import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../login/login_dialog.dart';
import 'kit.dart';

/// Heart button bound to the liked-songs set.
///
/// Listens to `library.likedIds` so every visible row updates after one tap.
/// Liking pops the heart and fires a small particle burst; the change is
/// optimistic (the service rolls back on failure and a snackbar explains).
class LikeButton extends StatefulWidget {
  const LikeButton({
    super.key,
    required this.songId,
    this.size = 20,
    this.likedOverride,
    this.onToggled,
  });

  final int songId;
  final double size;

  /// Lets a caller (e.g. the now playing screen) drive the state itself.
  final bool? likedOverride;
  final ValueChanged<bool>? onToggled;

  @override
  State<LikeButton> createState() => _LikeButtonState();
}

class _LikeButtonState extends State<LikeButton>
    with SingleTickerProviderStateMixin {
  late final AnimationController _burst = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 520),
  );

  static const Color _heart = Color(0xFFFF5C7C);

  @override
  void dispose() {
    _burst.dispose();
    super.dispose();
  }

  Future<void> _toggle(bool isLiked) async {
    final messenger = ScaffoldMessenger.maybeOf(context);
    if (!await app.session.ensureSignedIn()) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: const Text('登录后才能收藏歌曲'),
            action: SnackBarAction(
              label: '登录',
              onPressed: () => showLoginDialog(context),
            ),
          ),
        );
      return;
    }
    if (!mounted) return;
    if (!isLiked) _burst.forward(from: 0);
    final ok = await app.library.toggleLike(widget.songId, like: !isLiked);
    widget.onToggled?.call(ok ? !isLiked : isLiked);
    if (!ok) {
      messenger
        ?..hideCurrentSnackBar()
        ..showSnackBar(const SnackBar(content: Text('操作失败，请稍后重试')));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.library.likedIds,
      builder: (context, liked, _) {
        final isLiked = widget.likedOverride ?? liked.contains(widget.songId);
        final size = widget.size;
        return Tooltip(
          message: isLiked ? '取消喜欢' : '喜欢',
          child: Pressable(
            onTap: () => _toggle(isLiked),
            pressedScale: 0.85,
            hoverScale: 1.1,
            semanticLabel: isLiked ? '取消喜欢' : '喜欢',
            child: SizedBox(
              width: size + 16,
              height: size + 16,
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.center,
                children: [
                  Positioned.fill(
                    child: IgnorePointer(
                      child: CustomPaint(
                        painter: _BurstPainter(
                          animation: _burst,
                          colors: [_heart, context.surfaces.lime],
                        ),
                      ),
                    ),
                  ),
                  AnimatedSwitcher(
                    duration: AppMotion.emphasized,
                    switchInCurve: AppMotion.pop,
                    transitionBuilder: (child, animation) =>
                        ScaleTransition(scale: animation, child: child),
                    child: Icon(
                      isLiked
                          ? Icons.favorite_rounded
                          : Icons.favorite_border_rounded,
                      key: ValueKey(isLiked),
                      size: size,
                      color: isLiked ? _heart : context.surfaces.textTertiary,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Eight dots flying outwards and fading, drawn only while animating.
class _BurstPainter extends CustomPainter {
  _BurstPainter({required this.animation, required this.colors})
    : super(repaint: animation);

  final Animation<double> animation;
  final List<Color> colors;

  @override
  void paint(Canvas canvas, Size size) {
    final t = animation.value;
    if (t == 0 || t == 1) return;
    final center = size.center(Offset.zero);
    final eased = Curves.easeOutCubic.transform(t);
    final distance = size.shortestSide * (0.25 + 0.55 * eased);
    final radius = (1 - t) * size.shortestSide * 0.07 + 0.6;
    final paint = Paint();
    for (var i = 0; i < 8; i++) {
      final angle = i * math.pi / 4 + math.pi / 8;
      paint.color = colors[i % colors.length].withValues(alpha: 1 - t);
      canvas.drawCircle(
        center + Offset(math.cos(angle), math.sin(angle)) * distance,
        radius,
        paint,
      );
    }
    // Expanding ring right behind the heart.
    final ring = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6 * (1 - t)
      ..color = colors.first.withValues(alpha: (1 - t) * 0.7);
    canvas.drawCircle(center, size.shortestSide * 0.45 * eased, ring);
  }

  @override
  bool shouldRepaint(_BurstPainter oldDelegate) => oldDelegate.colors != colors;
}

/// Labels for the small tags after a song title, in display order.
///
/// `无版权` (greyed out) wins over everything; otherwise VIP / 试听 / 数字专辑
/// from the fee and SQ / Hi-Res from the best quality the account may stream.
List<String> songBadgeLabels(Song song) {
  if (!song.playable) return const ['无版权'];
  final labels = <String>[];
  switch (song.fee) {
    case SongFee.vip:
      labels.add('VIP');
    case SongFee.trial:
      labels.add('试听');
    case SongFee.album:
      labels.add('数字专辑');
    case SongFee.free:
      break;
  }
  final level = AudioLevel.fromValue(song.maxLevel);
  if (song.maxLevel != null) {
    if (level.bitrate >= AudioLevel.hires.bitrate) {
      labels.add('Hi-Res');
    } else if (level == AudioLevel.lossless) {
      labels.add('SQ');
    }
  }
  return labels;
}

/// Small tags that mark VIP / paid / preview / quality / unavailable tracks.
class SongBadge extends StatelessWidget {
  const SongBadge({super.key, required this.song, this.fontSize = 10});

  final Song song;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final labels = songBadgeLabels(song);
    if (labels.isEmpty) return const SizedBox.shrink();
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < labels.length; i++) ...[
          if (i > 0) const SizedBox(width: 4),
          TagBadge(labels[i], color: badgeColor(context, labels[i])),
        ],
      ],
    );
  }

  /// Horizontal space the tags of [song] need under the current theme, font
  /// and text scale, so a row can decide whether they still fit next to the
  /// title instead of letting them overflow the row.
  static double measureWidth(BuildContext context, Song song) {
    final labels = songBadgeLabels(song);
    if (labels.isEmpty) return 0;
    final style = DefaultTextStyle.of(context).style.merge(TagBadge.textStyle);
    final scaler = MediaQuery.textScalerOf(context);
    var width = 0.0;
    for (var i = 0; i < labels.length; i++) {
      final painter = TextPainter(
        text: TextSpan(text: labels[i], style: style),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      width += painter.width + TagBadge.horizontalInset;
      if (i > 0) width += 4;
    }
    return width;
  }

  /// Tint of a badge label.
  static Color badgeColor(BuildContext context, String label) {
    final s = context.surfaces;
    return switch (label) {
      'VIP' || '数字专辑' => const Color(0xFFE0B76A),
      'SQ' || 'Hi-Res' => context.colors.primary,
      '试听' => s.lavender,
      _ => s.textTertiary,
    };
  }
}
