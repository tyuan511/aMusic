import 'package:amusic/models/album.dart';
import 'package:amusic/models/playlist.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/services/app.dart';
import 'package:amusic/theme/app_theme.dart';
import 'package:amusic/ui/album/album_page.dart';
import 'package:amusic/ui/artist/artist_albums_page.dart';
import 'package:amusic/ui/artist/artist_page.dart';
import 'package:amusic/ui/artist/artist_songs_page.dart';
import 'package:amusic/ui/charts/charts_page.dart';
import 'package:amusic/ui/home/home_page.dart';
import 'package:amusic/ui/library/history_page.dart';
import 'package:amusic/ui/library/library_page.dart';
import 'package:amusic/ui/playlist/playlist_page.dart';
import 'package:amusic/ui/search/search_page.dart';
import 'package:amusic/ui/splash/splash_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pumps every browsing screen as a guest with no network (requests fail in
/// the test binding) at a phone and a desktop size, and checks that loading,
/// error and placeholder states lay out without exceptions.
void main() {
  setUpAll(() async {
    SharedPreferences.setMockInitialValues({});
    app = await AppServices.bootstrap();
  });

  final pages = <String, Widget Function()>{
    'home': () => const HomePage(),
    'charts': () => const ChartsPage(),
    'search': () => const SearchPage(),
    'search with keyword': () => const SearchPage(initialKeyword: '晴天'),
    'library': () => const LibraryPage(),
    'history': () => const HistoryPage(),
    'playlist preview': () => const PlaylistPage(
      playlistId: 1,
      preview: Playlist(
        id: 1,
        name: '预览歌单',
        trackCount: 12,
        description: '一段很长的描述',
        creator: PlaylistCreator(id: 2, nickname: '某人'),
      ),
    ),
    'daily as guest': () =>
        const PlaylistPage(playlistId: Playlist.dailyRecommendId),
    'album': () => const AlbumPage(
      albumId: 3,
      preview: Album(
        id: 3,
        name: '叶惠美',
        artists: [Artist(id: 1, name: '周杰伦')],
      ),
    ),
    'album from ref': () =>
        const AlbumPage(albumId: 3, preview: AlbumRef(id: 3, name: '叶惠美')),
    'artist': () => const ArtistPage(
      artistId: 1,
      preview: Artist(id: 1, name: '周杰伦', alias: ['Jay Chou']),
    ),
    'artist songs': () => const ArtistSongsPage(artistId: 1),
    'artist albums': () => const ArtistAlbumsPage(artistId: 1),
    'splash': () => const SplashPage(),
  };

  for (final size in const [Size(400, 860), Size(1440, 900)]) {
    for (final entry in pages.entries) {
      testWidgets('${entry.key} @ ${size.width.toInt()}', (tester) async {
        tester.view
          ..physicalSize = size
          ..devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await tester.pumpWidget(
          MaterialApp(
            theme: AppTheme.build(Brightness.dark),
            home: Scaffold(body: entry.value()),
          ),
        );
        for (var i = 0; i < 12; i++) {
          await tester.pump(const Duration(milliseconds: 150));
        }
        expect(tester.takeException(), isNull);
        // Unmount so pending animations / timers are disposed cleanly.
        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pump(const Duration(seconds: 1));
      });
    }
  }
}
