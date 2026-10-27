import 'json_utils.dart';
import 'song.dart';

class PlaylistCreator {
  const PlaylistCreator({
    required this.id,
    required this.nickname,
    this.avatarUrl,
  });

  final int id;
  final String nickname;
  final String? avatarUrl;

  factory PlaylistCreator.fromJson(Map<String, dynamic> json) =>
      PlaylistCreator(
        id: jsonInt(json['userId'] ?? json['id']),
        nickname: jsonString(json['nickname']) ?? '',
        avatarUrl: jsonText(json['avatarUrl']),
      );

  Map<String, dynamic> toJson() => {
    'userId': id,
    'nickname': nickname,
    'avatarUrl': avatarUrl,
  };
}

class Playlist {
  const Playlist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.description,
    this.creator = const PlaylistCreator(id: 0, nickname: ''),
    this.trackCount = 0,
    this.playCount = 0,
    this.createTime,
    this.tags = const [],
    this.tracks = const [],
    this.isDailyRecommend = false,
    this.subscribed = false,
    this.specialType = 0,
    this.privacy = 0,
    this.trackIds = const [],
    this.subscribedCount = 0,
    this.updateTime,
    this.userId = 0,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final String? description;
  final PlaylistCreator creator;
  final int trackCount;
  final int playCount;
  final DateTime? createTime;
  final List<String> tags;
  final List<Song> tracks;

  /// The synthetic "daily recommendation" entry has no real playlist id.
  final bool isDailyRecommend;

  /// The signed in account collected (subscribed to) this playlist.
  final bool subscribed;

  /// `5` is the account's "我喜欢的音乐", `10`/`20`... are editorial lists.
  final int specialType;

  /// `10` means private, `0` public.
  final int privacy;

  /// Every track id in playlist order (only in detail payloads). Can be
  /// longer than [tracks] in the raw response; [NcmApi.playlistDetail] fills
  /// the gap so the final [tracks] list is complete.
  final List<int> trackIds;
  final int subscribedCount;
  final DateTime? updateTime;

  /// Owner id from the top level `userId` field (used when [creator] is
  /// missing, e.g. search results).
  final int userId;

  /// Sentinel id used to route to the daily recommendation list.
  static const int dailyRecommendId = -1;

  /// `specialType` of the account's liked songs playlist.
  static const int likedSpecialType = 5;

  /// Id of the account that owns this playlist (0 when unknown).
  int get creatorId => creator.id != 0 ? creator.id : userId;

  /// Whether the account [uid] owns (created) this playlist.
  bool isMine(int? uid) => uid != null && uid > 0 && creatorId == uid;

  /// "我喜欢的音乐".
  bool get isLikedSongs => specialType == likedSpecialType;

  bool get isPrivate => privacy == 10;

  Playlist copyWith({
    List<Song>? tracks,
    bool? subscribed,
    String? name,
    int? privacy,
  }) => Playlist(
    id: id,
    name: name ?? this.name,
    coverUrl: coverUrl,
    description: description,
    creator: creator,
    trackCount: tracks?.length ?? trackCount,
    playCount: playCount,
    createTime: createTime,
    tags: tags,
    tracks: tracks ?? this.tracks,
    isDailyRecommend: isDailyRecommend,
    subscribed: subscribed ?? this.subscribed,
    specialType: specialType,
    privacy: privacy ?? this.privacy,
    trackIds: trackIds,
    subscribedCount: subscribedCount,
    updateTime: updateTime,
    userId: userId,
  );

  /// Handles `/user/playlist`, `/playlist/detail`, `/recommend/resource`,
  /// `/personalized`, `/playlist/list`, `/toplist/detail` and cloudsearch
  /// payload differences.
  factory Playlist.fromJson(Map<String, dynamic> json) {
    final cover =
        jsonText(json['coverImgUrl']) ??
        jsonText(json['picUrl']) ??
        jsonText(json['coverUrl']) ??
        jsonText(json['pic']);
    final creatorRaw = jsonMap(json['creator']);
    final privileges = jsonMaps(json['privileges']);
    return Playlist(
      id: jsonInt(json['id']),
      name: jsonString(json['name']) ?? jsonString(json['title']) ?? '',
      coverUrl: cover,
      description:
          jsonString(json['description']) ?? jsonString(json['copywriter']),
      creator: creatorRaw != null
          ? PlaylistCreator.fromJson(creatorRaw)
          : const PlaylistCreator(id: 0, nickname: ''),
      trackCount: jsonInt(json['trackCount']),
      playCount: jsonInt(json['playCount'] ?? json['playcount']),
      createTime: jsonTime(json['createTime']),
      tags: jsonStrings(json['tags']),
      tracks: Song.listFrom(
        json['tracks'],
        privileges: privileges.isEmpty ? null : privileges,
      ),
      subscribed: jsonBool(json['subscribed']),
      specialType: jsonInt(json['specialType']),
      privacy: jsonInt(json['privacy']),
      trackIds: [
        for (final item in jsonMaps(json['trackIds']))
          if (jsonInt(item['id']) > 0) jsonInt(item['id']),
      ],
      subscribedCount: jsonInt(
        json['subscribedCount'] ?? json['bookCount'] ?? json['subCount'],
      ),
      updateTime: jsonTime(json['updateTime'] ?? json['trackUpdateTime']),
      userId: jsonInt(json['userId']),
    );
  }

  static List<Playlist> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return jsonMaps(raw).map(Playlist.fromJson).toList(growable: false);
  }
}

class UserProfile {
  const UserProfile({
    required this.id,
    required this.nickname,
    this.avatarUrl,
    this.signature,
    this.vipType = 0,
  });

  final int id;
  final String nickname;
  final String? avatarUrl;
  final String? signature;
  final int vipType;

  bool get isVip => vipType == 11;

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
    id: jsonInt(json['userId'] ?? json['id']),
    nickname: jsonString(json['nickname']) ?? '',
    avatarUrl: jsonText(json['avatarUrl']),
    signature: jsonString(json['signature']),
    vipType: jsonInt(json['vipType']),
  );
}
