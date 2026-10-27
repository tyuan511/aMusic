import '../../models/album.dart';
import '../../models/discovery.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../models/user.dart';
import '../../services/app.dart';
import '../browse_widgets/future_section.dart';

/// Chips of the home page.
enum HomeChip {
  all('全部'),
  newSongs('新歌'),
  charts('排行'),
  playlists('歌单');

  const HomeChip(this.label);

  final String label;
}

/// Regions of 新歌速递 and their `areaId`.
enum NewSongArea {
  all(0, '全部'),
  chinese(7, '华语'),
  western(96, '欧美'),
  japanese(8, '日本'),
  korean(16, '韩国');

  const NewSongArea(this.id, this.label);

  final int id;
  final String label;
}

/// Time-of-day greeting shown above the home chips.
String greetingFor(int hour) {
  if (hour < 5) return '夜深了';
  if (hour < 11) return '早上好';
  if (hour < 13) return '中午好';
  if (hour < 18) return '下午好';
  return '晚上好';
}

/// "晚上好，昵称" (or just the greeting for guests).
String greetingLine(int hour, String? nickname) {
  final greeting = greetingFor(hour);
  if (nickname == null || nickname.trim().isEmpty) return greeting;
  return '$greeting，${nickname.trim()}';
}

/// Independent home sections; each loads (and fails) on its own.
class HomeFeed {
  HomeFeed({required this.loggedIn})
    : discover = guardFuture(app.library.discoverPlaylists()),
      newAlbums = guardFuture(
        app.library.newAlbums(limit: 12).then((page) => page.items),
      ),
      toplists = guardFuture(app.library.toplists()),
      collections = guardFuture(
        loggedIn
            ? app.library.userCollections()
            : Future.value(UserCollections.empty),
      );

  final bool loggedIn;
  final Future<List<Playlist>> discover;
  final Future<List<Album>> newAlbums;
  final Future<List<Toplist>> toplists;
  final Future<UserCollections> collections;

  final Map<NewSongArea, Future<List<Song>>> _newSongs = {};

  /// 新歌速递 of [area], requested on first use.
  Future<List<Song>> newSongs([NewSongArea area = NewSongArea.all]) =>
      _newSongs.putIfAbsent(
        area,
        () => guardFuture(app.library.newSongs(areaId: area.id)),
      );

  /// Official charts first (they carry the top-3 preview).
  Future<List<Toplist>> get officialCharts => toplists.then(
    (lists) => [
      ...lists.where((list) => list.isOfficial),
      ...lists.where((list) => !list.isOfficial),
    ],
  );
}
