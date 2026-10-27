import 'json_utils.dart';
import 'playlist.dart';
import 'song.dart';

/// Public profile from `/api/v1/user/detail/{uid}`.
class UserDetail {
  const UserDetail({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.backgroundUrl,
    this.signature,
    this.level = 0,
    this.listenSongs = 0,
    this.follows = 0,
    this.followeds = 0,
    this.vipType = 0,
    this.createDays,
    this.playlistCount = 0,
    this.followed = false,
  });

  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? backgroundUrl;
  final String? signature;
  final int level;

  /// Total number of songs listened to.
  final int listenSongs;

  /// Accounts this user follows.
  final int follows;

  /// Followers.
  final int followeds;
  final int vipType;

  /// Days since registration, when the server reports it.
  final int? createDays;
  final int playlistCount;

  /// Whether the signed in account follows this user.
  final bool followed;

  bool get isVip => vipType != 0;

  factory UserDetail.fromJson(Map<String, dynamic> body) {
    final profile = jsonMap(body['profile']) ?? const <String, dynamic>{};
    return UserDetail(
      id: jsonInt(profile['userId'] ?? profile['id']),
      nickname: jsonString(profile['nickname']) ?? '',
      avatarUrl: jsonText(profile['avatarUrl']),
      backgroundUrl: jsonText(profile['backgroundUrl']),
      signature: jsonText(profile['signature']),
      level: jsonInt(body['level']),
      listenSongs: jsonInt(body['listenSongs']),
      follows: jsonInt(profile['follows']),
      followeds: jsonInt(profile['followeds']),
      vipType: jsonInt(profile['vipType']),
      createDays: jsonIntOrNull(body['createDays']),
      playlistCount: jsonInt(profile['playlistCount']),
      followed: jsonBool(profile['followed']),
    );
  }
}

/// The account's playlists split the way the library screen shows them.
class UserCollections {
  const UserCollections({
    this.liked,
    this.created = const [],
    this.collected = const [],
  });

  static const UserCollections empty = UserCollections();

  /// "我喜欢的音乐" (`specialType == 5`).
  final Playlist? liked;

  /// Created by the account, excluding [liked].
  final List<Playlist> created;

  /// Collected (subscribed) from other users.
  final List<Playlist> collected;

  bool get isEmpty => liked == null && created.isEmpty && collected.isEmpty;

  /// Splits `/api/user/playlist` for the account [uid], keeping server order.
  factory UserCollections.split(List<Playlist> playlists, int uid) {
    Playlist? liked;
    final created = <Playlist>[];
    final collected = <Playlist>[];
    for (final playlist in playlists) {
      final mine =
          playlist.isMine(uid) ||
          (playlist.creatorId == 0 && !playlist.subscribed);
      if (mine && liked == null && playlist.isLikedSongs) {
        liked = playlist;
      } else if (mine) {
        created.add(playlist);
      } else {
        collected.add(playlist);
      }
    }
    return UserCollections(
      liked: liked,
      created: created,
      collected: collected,
    );
  }
}

/// One row of `/api/v1/play/record`.
typedef PlayRecordEntry = ({Song song, int playCount});

/// Parses `weekData` / `allData` rows.
List<PlayRecordEntry> parsePlayRecord(Object? rows) => [
  for (final row in jsonMaps(rows))
    if (jsonMap(row['song']) case final song?)
      (song: Song.fromJson(song), playCount: jsonInt(row['playCount'])),
];
