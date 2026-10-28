import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../services/local_library_service.dart';
import '../../theme/app_theme.dart';
import 'cover_image.dart';
import 'kit.dart';
import 'like_button.dart';
import 'playing_indicator.dart';
import 'song_menu.dart';

/// Widest the album column gets; it shrinks down to [_kAlbumColumnMinWidth]
/// before being dropped, so the column fades out while the window is resized
/// instead of popping out at one specific width.
const double _kAlbumColumnMaxWidth = 180;
const double _kAlbumColumnMinWidth = 104;

/// Width of the duration column.
const double _kDurationColumnWidth = 52;

/// Title space the optional columns may never eat into, so the title always
/// renders a few characters plus its tags.
const double _kMinTitleWidth = 96;

/// Width of the trailing "more" button (icon 20 + padding 8).
const double _kMoreButtonWidth = 36;

/// Width of the like button (icon 19 + 16 padding); zero when hidden.
const double _kLikeButtonWidth = 35;

/// Horizontal row padding.
const double _kRowPadding = 10 * 2;

/// Gap between the leading cover/number and the title.
const double _kLeadingGap = 14;

/// Gap in front of the album column.
const double _kAlbumGap = 12;

/// Gap in front of the like button.
const double _kTrailingGap = 6;

/// Space set aside for the quality tags (the widest pair of them plus their
/// gap). Reserved even for songs without tags so every row of a grid keeps its
/// columns aligned.
const double _kBadgeReserve = 118;

/// One row of a song list.
///
/// Cover (or track number) + title with badges + artists, an album column on
/// rows wide enough for it, duration, like and more. The row listens to
/// `player.currentSongId` only (so a track change re-tints the two affected
/// rows and position ticks never reach it); the playing indicator inside the
/// current row is the only thing bound to the play/pause state.
///
/// Every optional column is decided from the row's own width (never from the
/// window width) so the same row works inside a multi-column grid, and so a
/// resize can never leave a column in a space that cannot hold it.
class SongTile extends StatefulWidget {
  const SongTile({
    super.key,
    required this.song,
    this.onTap,
    this.index,
    this.showAlbum = false,
    this.showDuration = true,
    this.height = 64,
    this.removeFrom,
    this.onRemoved,
    this.numberLabel,
  });

  final Song song;
  final VoidCallback? onTap;

  /// Optional track number rendered instead of the cover.
  final int? index;
  final bool showAlbum;
  final bool showDuration;
  final double height;

  /// Own playlist this row belongs to: enables "从歌单删除" in the menu.
  final Playlist? removeFrom;
  final VoidCallback? onRemoved;

  /// Overrides the `index + 1` label (album rows use "1-03" style numbers).
  final String? numberLabel;

  @override
  State<SongTile> createState() => _SongTileState();
}

class _SongTileState extends State<SongTile> {
  bool _hovering = false;

  void _openMenu() => showSongMenu(
    context,
    widget.song,
    removeFrom: widget.removeFrom,
    onRemoved: widget.onRemoved,
  );

  @override
  Widget build(BuildContext context) {
    final song = widget.song;
    return LayoutBuilder(
      builder: (context, constraints) => _build(context, song, constraints),
    );
  }

  Widget _build(BuildContext context, Song song, BoxConstraints constraints) {
    // A row inside a grid gets its column width here, in the very same layout
    // pass that paints it: no stale window width, so nothing overflows while
    // the window is being resized.
    final width = constraints.hasBoundedWidth
        ? constraints.maxWidth
        : MediaQuery.sizeOf(context).width;

    // The optional columns are filled in order of importance — title, its
    // tags, duration, album — and only with the space that is actually left.
    final leading = (widget.height - 16).clamp(36.0, 52.0);
    final like = LocalLibraryService.isLocalId(song.id)
        ? 0.0
        : _kLikeButtonWidth;
    final fixed =
        _kRowPadding +
        leading +
        _kLeadingGap +
        _kTrailingGap +
        like +
        _kMoreButtonWidth;
    var free = width - fixed;

    final showDuration =
        widget.showDuration &&
        free >= _kBadgeReserve + _kMinTitleWidth + _kDurationColumnWidth;
    if (showDuration) free -= _kDurationColumnWidth;

    final albumWidth = widget.showAlbum
        ? (free - _kBadgeReserve - _kMinTitleWidth - _kAlbumGap).clamp(
            0.0,
            _kAlbumColumnMaxWidth,
          )
        : 0.0;
    final showAlbum = albumWidth >= _kAlbumColumnMinWidth;

    return ValueListenableBuilder(
      valueListenable: app.player.currentSongId,
      builder: (context, currentId, _) {
        final isCurrent = currentId != null && currentId == song.id;
        final s = context.surfaces;
        final tint = isCurrent
            ? s.lime.withValues(alpha: context.isDark ? 0.10 : 0.16)
            // Fade from/to the hover colour at zero alpha, not
            // Colors.transparent (transparent black): lerping through that
            // flashes a darker tint before the hover colour settles.
            : s.cardHover.withValues(alpha: _hovering ? null : 0);
        return MouseRegion(
          onEnter: (_) => setState(() => _hovering = true),
          onExit: (_) => setState(() => _hovering = false),
          child: AnimatedContainer(
            duration: AppMotion.standard,
            curve: AppMotion.enter,
            height: widget.height,
            decoration: BoxDecoration(
              color: tint,
              borderRadius: BorderRadius.circular(AppMetrics.radiusMd - 4),
            ),
            child: Pressable(
              pressedScale: 0.985,
              onTap: widget.onTap,
              onLongPress: _openMenu,
              onSecondaryTap: _openMenu,
              child: AnimatedOpacity(
                duration: AppMotion.standard,
                opacity: song.playable ? 1 : 0.45,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: _kRowPadding / 2,
                  ),
                  child: Row(
                    children: [
                      _Leading(
                        song: song,
                        index: widget.index,
                        numberLabel: widget.numberLabel,
                        isCurrent: isCurrent,
                        hovering: _hovering,
                        size: leading,
                      ),
                      const SizedBox(width: _kLeadingGap),
                      Expanded(
                        child: _Titles(song: song, isCurrent: isCurrent),
                      ),
                      if (showAlbum) ...[
                        const SizedBox(width: _kAlbumGap),
                        SizedBox(
                          width: albumWidth,
                          child: _AlbumLink(song: song),
                        ),
                      ],
                      if (showDuration)
                        SizedBox(
                          width: _kDurationColumnWidth,
                          child: Text(
                            song.duration == Duration.zero
                                ? ''
                                : song.duration.clock,
                            textAlign: TextAlign.right,
                            style: context.text.bodySmall?.copyWith(
                              color: s.textTertiary,
                              fontFeatures: const [
                                FontFeature.tabularFigures(),
                              ],
                            ),
                          ),
                        ),
                      const SizedBox(width: _kTrailingGap),
                      if (!LocalLibraryService.isLocalId(song.id))
                        LikeButton(songId: song.id, size: 19),
                      _MoreButton(onPressed: _openMenu),
                    ],
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

class _MoreButton extends StatelessWidget {
  const _MoreButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: '更多操作',
      child: Pressable(
        onTap: onPressed,
        hoverScale: 1.1,
        semanticLabel: '更多操作',
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Icon(
            Icons.more_horiz_rounded,
            size: 20,
            color: context.surfaces.textTertiary,
          ),
        ),
      ),
    );
  }
}

class _Leading extends StatelessWidget {
  const _Leading({
    required this.song,
    required this.index,
    required this.numberLabel,
    required this.isCurrent,
    required this.hovering,
    required this.size,
  });

  final Song song;
  final int? index;
  final String? numberLabel;
  final bool isCurrent;
  final bool hovering;
  final double size;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final numbered = index != null || numberLabel != null;
    final Widget overlay;
    if (isCurrent) {
      overlay = ValueListenableBuilder(
        key: const ValueKey('playing'),
        valueListenable: app.player.playback,
        builder: (context, playback, _) => PlayingIndicator(
          size: 14,
          playing: playback.playing,
          color: numbered ? s.lime : Colors.white,
        ),
      );
    } else if (hovering && song.playable) {
      overlay = Icon(
        Icons.play_arrow_rounded,
        key: const ValueKey('hover'),
        size: 22,
        color: numbered ? context.colors.onSurface : Colors.white,
      );
    } else {
      overlay = const SizedBox.shrink(key: ValueKey('none'));
    }
    final animatedOverlay = AnimatedSwitcher(
      duration: AppMotion.quick,
      transitionBuilder: (child, animation) => FadeTransition(
        opacity: animation,
        child: ScaleTransition(scale: animation, child: child),
      ),
      child: overlay,
    );

    if (numbered) {
      final showNumber = !isCurrent && !(hovering && song.playable);
      return SizedBox(
        width: 40,
        height: size,
        child: Stack(
          alignment: Alignment.center,
          children: [
            AnimatedOpacity(
              duration: AppMotion.quick,
              opacity: showNumber ? 1 : 0,
              child: Text(
                numberLabel ?? '${index! + 1}',
                maxLines: 1,
                style: context.text.bodyMedium?.copyWith(
                  color: s.textTertiary,
                  fontFeatures: const [FontFeature.tabularFigures()],
                ),
              ),
            ),
            animatedOverlay,
          ],
        ),
      );
    }
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        fit: StackFit.expand,
        children: [
          CoverImage(
            url: song.album.picUrl,
            size: 140,
            radius: AppMetrics.radiusSm - 2,
          ),
          AnimatedOpacity(
            duration: AppMotion.quick,
            opacity: isCurrent || (hovering && song.playable) ? 1 : 0,
            child: DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.48),
                borderRadius: BorderRadius.circular(AppMetrics.radiusSm - 2),
              ),
            ),
          ),
          Center(child: animatedOverlay),
        ],
      ),
    );
  }
}

class _Titles extends StatelessWidget {
  const _Titles({required this.song, required this.isCurrent});

  final Song song;
  final bool isCurrent;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final alias = song.alias.isEmpty ? null : song.alias.first;
    return LayoutBuilder(
      builder: (context, constraints) {
        // Tags only render when the title keeps at least [_kMinTitleWidth]
        // next to them: a row whose column is too narrow silently drops the
        // tags instead of overflowing by their width.
        final badgeWidth = SongBadge.measureWidth(context, song);
        final showBadge =
            badgeWidth > 0 &&
            (!constraints.hasBoundedWidth ||
                constraints.maxWidth >= badgeWidth + 6 + _kMinTitleWidth);
        return _column(context, s, alias, showBadge: showBadge);
      },
    );
  }

  Widget _column(
    BuildContext context,
    AppSurfaces s,
    String? alias, {
    required bool showBadge,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Row(
          children: [
            Flexible(
              child: AnimatedDefaultTextStyle(
                duration: AppMotion.quick,
                style: context.text.bodyLarge!.copyWith(
                  fontSize: 15,
                  fontWeight: FontWeight.w500,
                  color: isCurrent
                      ? context.colors.primary
                      : context.colors.onSurface,
                ),
                child: Text.rich(
                  TextSpan(
                    text: song.name,
                    children: [
                      if (alias != null && alias.isNotEmpty)
                        TextSpan(
                          text: ' ($alias)',
                          style: TextStyle(color: s.textTertiary),
                        ),
                    ],
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ),
            if (showBadge) ...[const SizedBox(width: 6), SongBadge(song: song)],
          ],
        ),
        const SizedBox(height: 3),
        Text(
          song.artistText,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: context.text.bodySmall?.copyWith(
            fontSize: 12.5,
            color: s.textSecondary,
          ),
        ),
      ],
    );
  }
}

class _AlbumLink extends StatelessWidget {
  const _AlbumLink({required this.song});

  final Song song;

  @override
  Widget build(BuildContext context) {
    final album = song.album;
    final text = Text(
      album.name,
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
      style: context.text.bodySmall?.copyWith(
        color: context.surfaces.textTertiary,
      ),
    );
    if (album.id <= 0) return text;
    return Align(
      alignment: Alignment.centerLeft,
      child: MouseRegion(
        cursor: SystemMouseCursors.click,
        child: GestureDetector(
          onTap: () => openAlbum(context, album.id, preview: album),
          child: text,
        ),
      ),
    );
  }
}
