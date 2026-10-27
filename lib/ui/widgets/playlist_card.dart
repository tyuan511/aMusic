import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/playlist.dart';
import '../../services/app.dart';
import '../browse_widgets/cards.dart';
import 'kit.dart';
import 'motion.dart';

/// Playlist cover card for grids and shelves.
///
/// Rounded 18, lifts on hover, lime play button that loads and plays the
/// playlist without opening it.
class PlaylistCard extends StatelessWidget {
  const PlaylistCard({super.key, required this.playlist, required this.onTap});

  static const double coverRatio = 1;
  static const double textAreaHeight = CoverCard.textAreaHeight;

  final Playlist playlist;
  final VoidCallback onTap;

  /// Height a card needs for a given column width.
  static double heightFor(double width) => CoverCard.heightFor(width);

  @override
  Widget build(BuildContext context) {
    return CoverCard(
      title: playlist.name,
      subtitle: playlistSubtitle(playlist),
      coverUrl: playlist.coverUrl,
      onTap: onTap,
      topRight: playlist.playCount > 0
          ? PlayCountPill(playlist.playCount.compact)
          : null,
      playButton: CollectionPlayButton(
        sourceId: playlist.id,
        sourceTitle: playlist.name,
        accent: true,
        size: 40,
        load: () async =>
            (await app.library.playlistDetail(playlist.id)).tracks,
      ),
    );
  }
}

/// "By 作者 • 24 首" style secondary line of a playlist.
String playlistSubtitle(Playlist playlist) {
  if (playlist.isDailyRecommend) return '每天 6:00 更新';
  final parts = [
    if (playlist.creator.nickname.isNotEmpty) playlist.creator.nickname,
    if (playlist.trackCount > 0) '${playlist.trackCount} 首',
  ];
  if (parts.isEmpty && playlist.playCount > 0) {
    return '${playlist.playCount.compact} 次播放';
  }
  return parts.join(' • ');
}

/// Section title with an optional trailing action. Kept for older call
/// sites; new code uses `SectionTitle` from the kit.
class SectionHeader extends StatelessWidget {
  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.action,
  });

  final String title;
  final String? subtitle;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 2),
      child: Row(
        children: [
          Expanded(
            child: SectionTitle(
              title: title,
              subtitle: subtitle,
              padding: EdgeInsets.zero,
            ),
          ),
          ?action,
        ],
      ),
    );
  }
}

/// Responsive playlist grid (box layout, for short lists inside a column).
class PlaylistGrid extends StatelessWidget {
  const PlaylistGrid({
    super.key,
    required this.playlists,
    required this.onTap,
    this.maxCrossAxisExtent = 190,
    this.spacing = 16,
  });

  final List<Playlist> playlists;
  final void Function(Playlist playlist) onTap;
  final double maxCrossAxisExtent;
  final double spacing;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;
        final columns = (width / maxCrossAxisExtent).ceil().clamp(2, 8);
        final itemWidth = (width - spacing * (columns - 1)) / columns;
        return GridView.builder(
          shrinkWrap: true,
          clipBehavior: Clip.none,
          physics: const NeverScrollableScrollPhysics(),
          padding: EdgeInsets.zero,
          gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
            crossAxisCount: columns,
            mainAxisExtent: PlaylistCard.heightFor(itemWidth),
            crossAxisSpacing: spacing,
            mainAxisSpacing: spacing,
          ),
          itemCount: playlists.length,
          itemBuilder: (context, index) => RepaintBoundary(
            child: EntranceFade(
              index: index,
              child: PlaylistCard(
                key: ValueKey('playlist-card-${playlists[index].id}'),
                playlist: playlists[index],
                onTap: () => onTap(playlists[index]),
              ),
            ),
          ),
        );
      },
    );
  }
}
