import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/future_section.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/media_cards.dart';
import '../browse_widgets/playback.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import '../widgets/song_tile.dart';

/// Number of top songs listed on the artist page before "查看全部".
const int kArtistTopSongCount = 10;

/// 热门: top songs, latest releases and similar artists.
class ArtistHotTab extends StatelessWidget {
  const ArtistHotTab({
    super.key,
    required this.artistId,
    required this.artistName,
    required this.topSongs,
    required this.albums,
    required this.similar,
    required this.onRetry,
  });

  final int artistId;
  final String artistName;
  final Future<List<Song>> topSongs;
  final Future<List<Album>> albums;
  final Future<List<Artist>> similar;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SectionTitle(
          title: '热门歌曲',
          onAction: () => openArtistSongs(context, artistId),
        ),
        FutureSection<List<Song>>(
          future: topSongs,
          onRetry: onRetry,
          skeleton: const MediaRowSkeletonList(
            count: 5,
            padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
          ),
          hideWhen: (songs) => songs.isEmpty,
          empty: const EmptyView(message: '暂无热门歌曲'),
          builder: (context, songs) => Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.gutter - 10,
            ),
            child: ResponsiveColumns(
              minColumnWidth: 460,
              maxColumns: 2,
              children: [
                for (
                  var i = 0;
                  i < songs.length && i < kArtistTopSongCount;
                  i++
                )
                  EntranceItem(
                    index: i,
                    child: SongTile(
                      song: songs[i],
                      onTap: () => playCollection(
                        context,
                        songs,
                        index: i,
                        title: '$artistName 热门歌曲',
                        sourceId: artistId,
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        FutureSection<List<Album>>(
          future: albums,
          onRetry: onRetry,
          skeleton: const CardShelfSkeleton(),
          hideWhen: (list) => list.isEmpty,
          builder: (context, list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SectionTitle(
                title: '最新发行',
                onAction: () => openArtistAlbums(context, artistId),
              ),
              HorizontalShelf(
                height: 160 + CoverCard.textAreaHeight,
                itemWidth: 160,
                itemCount: list.length.clamp(0, 10),
                itemBuilder: (context, index) =>
                    AlbumCard(album: list[index], showArtist: false),
              ),
            ],
          ),
        ),
        FutureSection<List<Artist>>(
          future: similar,
          skeleton: const SizedBox.shrink(),
          hideWhen: (list) => list.isEmpty,
          builder: (context, list) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SectionTitle(title: '相似歌手'),
              HorizontalShelf(
                height: 120 + CoverCard.textAreaHeight,
                itemWidth: 120,
                itemCount: list.length.clamp(0, 16),
                itemBuilder: (context, index) =>
                    ArtistCard(artist: list[index]),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

/// 专辑 / 单曲EP: grid of the artist's releases of one kind.
class ArtistAlbumsTab extends StatelessWidget {
  const ArtistAlbumsTab({
    super.key,
    required this.artistId,
    required this.albums,
    required this.singles,
    required this.onRetry,
  });

  final int artistId;
  final Future<List<Album>> albums;

  /// Show singles / EPs instead of full albums.
  final bool singles;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureSection<List<Album>>(
      future: albums,
      onRetry: onRetry,
      skeleton: const Padding(
        padding: EdgeInsets.only(top: 24),
        child: CardShelfSkeleton(),
      ),
      builder: (context, all) {
        final list = all.where((a) => isSingleOrEp(a) == singles).toList();
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SectionTitle(
              title: singles ? '单曲 / EP' : '专辑',
              subtitle: '最近 ${all.length} 张发行中的 ${list.length} 张',
              actionLabel: '全部发行',
              onAction: () => openArtistAlbums(context, artistId),
            ),
            if (list.isEmpty)
              EmptyView(
                message: singles ? '暂无单曲或 EP' : '暂无专辑',
                icon: Icons.album_outlined,
              )
            else
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppMetrics.gutter,
                ),
                child: CoverGrid(
                  itemCount: list.length,
                  maxItemWidth: 200,
                  itemBuilder: (context, index) =>
                      AlbumCard(album: list[index], showArtist: false),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// 简介: brief description, identities and the long-form sections.
class ArtistAboutTab extends StatelessWidget {
  const ArtistAboutTab({
    super.key,
    required this.description,
    required this.identities,
    required this.onRetry,
  });

  final Future<ArtistDescription> description;
  final List<String> identities;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    return FutureSection<ArtistDescription>(
      future: description,
      onRetry: onRetry,
      hideWhen: (desc) => desc.isEmpty && identities.isEmpty,
      empty: const EmptyView(message: '暂无简介', icon: Icons.notes_rounded),
      builder: (context, desc) {
        final cards = <Widget>[
          if (identities.isNotEmpty)
            _AboutCard(title: '身份', text: identities.join(' · ')),
          if ((desc.briefDesc ?? '').isNotEmpty)
            _AboutCard(title: '简介', text: desc.briefDesc!),
          for (final section in desc.sections)
            _AboutCard(
              title: section.title.isEmpty ? '介绍' : section.title,
              text: section.text,
            ),
        ];
        return Padding(
          padding: const EdgeInsets.fromLTRB(
            AppMetrics.gutter,
            24,
            AppMetrics.gutter,
            0,
          ),
          child: Column(
            children: [
              for (var i = 0; i < cards.length; i++)
                EntranceItem(index: i, child: cards[i]),
            ],
          ),
        );
      },
    );
  }
}

class _AboutCard extends StatelessWidget {
  const _AboutCard({required this.title, required this.text});

  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 14),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: s.card,
        borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
        border: Border.all(color: s.hairline),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: context.text.titleMedium?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 10),
          SelectableText(
            text.trim(),
            style: context.text.bodyMedium?.copyWith(
              color: s.textSecondary,
              height: 1.7,
            ),
          ),
        ],
      ),
    );
  }
}
