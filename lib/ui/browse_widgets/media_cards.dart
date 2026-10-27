import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../models/song.dart';
import '../../router.dart';
import '../../services/app.dart';
import 'cards.dart';

/// [CoverCard] for an album: opens the album page, the play button loads
/// and plays the whole album.
class AlbumCard extends StatelessWidget {
  const AlbumCard({super.key, required this.album, this.showArtist = true});

  final Album album;
  final bool showArtist;

  @override
  Widget build(BuildContext context) {
    final year = album.publishTime?.year;
    final parts = [
      if (showArtist) album.artistText,
      if (!showArtist && year != null) '$year',
      if (!showArtist && album.size > 0) '${album.size} 首',
    ];
    return CoverCard(
      title: album.name,
      subtitle: parts.join(' • '),
      coverUrl: album.picUrl,
      onTap: () => openAlbum(context, album.id, preview: album),
      playButton: CollectionPlayButton(
        sourceId: album.id,
        sourceTitle: album.name,
        accent: true,
        size: 40,
        load: () async => (await app.library.albumDetail(album.id)).tracks,
      ),
    );
  }
}

/// Round artist portrait + name, opens the artist page.
class ArtistCard extends StatelessWidget {
  const ArtistCard({super.key, required this.artist});

  final Artist artist;

  @override
  Widget build(BuildContext context) {
    return CoverCard(
      circle: true,
      title: artist.name,
      subtitle: artist.albumSize != null && artist.albumSize! > 0
          ? '${artist.albumSize} 张专辑'
          : null,
      coverUrl: artist.picUrl,
      onTap: () => openArtist(context, artist.id, preview: artist),
    );
  }
}

/// `true` for singles and EPs (NetEase album `type` "Single", "EP/Single",
/// "EP"); everything else counts as a full album.
bool isSingleOrEp(Album album) {
  final type = (album.type ?? '').toLowerCase();
  final sub = (album.subType ?? '').toLowerCase();
  return type.contains('single') ||
      type.contains('ep') ||
      sub.contains('single') ||
      sub == 'ep';
}
