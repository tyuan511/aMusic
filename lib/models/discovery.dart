import 'json_utils.dart';
import 'playlist.dart';

/// One preview row of a chart (`tracks[]` of `/api/toplist/detail`).
class ToplistPreview {
  const ToplistPreview({required this.name, required this.artist});

  /// Song name (`first`).
  final String name;

  /// Artist text (`second`).
  final String artist;
}

/// A chart from `/api/toplist/detail`. Charts are playlists, so the detail
/// screen loads them through `playlistDetail(id)`.
class Toplist {
  const Toplist({
    required this.id,
    required this.name,
    this.coverUrl,
    this.updateFrequency,
    this.description,
    this.preview = const [],
    this.isOfficial = false,
    this.toplistType,
    this.playCount = 0,
    this.trackCount = 0,
    this.updateTime,
  });

  final int id;
  final String name;
  final String? coverUrl;

  /// "每天更新", "每周四更新"...
  final String? updateFrequency;
  final String? description;

  /// Top 3 rows, only present on the official charts.
  final List<ToplistPreview> preview;

  /// 飙升 / 新歌 / 原创 / 热歌.
  final bool isOfficial;

  /// `S` / `N` / `O` / `H` for the official charts, `null` otherwise.
  final String? toplistType;
  final int playCount;
  final int trackCount;
  final DateTime? updateTime;

  /// [index] is the position in the response; the first four entries are the
  /// official charts when `ToplistType` is missing.
  factory Toplist.fromJson(Map<String, dynamic> json, {int index = 99}) {
    final type = jsonText(json['ToplistType'] ?? json['toplistType']);
    return Toplist(
      id: jsonInt(json['id']),
      name: jsonString(json['name']) ?? '',
      coverUrl: jsonText(json['coverImgUrl']) ?? jsonText(json['picUrl']),
      updateFrequency: jsonText(json['updateFrequency']),
      description: jsonText(json['description']),
      preview: [
        for (final row in jsonMaps(json['tracks']))
          ToplistPreview(
            name: jsonString(row['first']) ?? '',
            artist: jsonString(row['second']) ?? '',
          ),
      ],
      isOfficial: type != null || (json['ToplistType'] == null && index < 4),
      toplistType: type,
      playCount: jsonInt(json['playCount']),
      trackCount: jsonInt(json['trackCount']),
      updateTime: jsonTime(json['updateTime']),
    );
  }

  /// `list` of a `/api/toplist/detail` body.
  static List<Toplist> listFrom(Object? raw) {
    final maps = jsonMaps(raw);
    // When the server labels any chart, trust the labels only.
    final labelled = maps.any((m) => jsonText(m['ToplistType']) != null);
    return [
      for (var i = 0; i < maps.length; i++)
        if (jsonInt(maps[i]['id']) > 0)
          Toplist.fromJson(maps[i], index: labelled ? 99 : i),
    ];
  }

  /// Summary playlist used for navigation / cards.
  Playlist toPlaylist() => Playlist(
    id: id,
    name: name,
    coverUrl: coverUrl,
    description: description,
    playCount: playCount,
    trackCount: trackCount,
    updateTime: updateTime,
  );
}

/// A playlist tag such as "华语" or "夜晚".
class PlaylistCategory {
  const PlaylistCategory({
    required this.name,
    this.group = 0,
    this.hot = false,
  });

  final String name;

  /// Index into [PlaylistCatalogue.groups] (`category` field).
  final int group;
  final bool hot;
}

/// "语种", "风格"... with their tags.
class PlaylistCategoryGroup {
  const PlaylistCategoryGroup({
    required this.id,
    required this.name,
    this.categories = const [],
  });

  final int id;
  final String name;
  final List<PlaylistCategory> categories;
}

/// `/api/playlist/catalogue`.
class PlaylistCatalogue {
  const PlaylistCatalogue({this.allName = '全部', this.groups = const []});

  /// Name of the catch-all category (`all.name`, e.g. "全部歌单"). Requests
  /// use `'全部'` for it.
  final String allName;
  final List<PlaylistCategoryGroup> groups;

  List<PlaylistCategory> get hot => [
    for (final group in groups)
      for (final category in group.categories)
        if (category.hot) category,
  ];

  factory PlaylistCatalogue.fromJson(Map<String, dynamic> body) {
    final names = jsonMap(body['categories']) ?? const <String, dynamic>{};
    final subs = [
      for (final item in jsonMaps(body['sub']))
        if (jsonText(item['name']) case final name?)
          PlaylistCategory(
            name: name,
            group: jsonInt(item['category']),
            hot: jsonBool(item['hot']),
          ),
    ];
    final ids = names.keys.map(int.tryParse).whereType<int>().toList()..sort();
    // Groups present in `sub` but missing from `categories` still show up.
    for (final sub in subs) {
      if (!ids.contains(sub.group)) ids.add(sub.group);
    }
    return PlaylistCatalogue(
      allName: jsonText(jsonMap(body['all'])?['name']) ?? '全部',
      groups: [
        for (final id in ids)
          PlaylistCategoryGroup(
            id: id,
            name: jsonString(names['$id']) ?? '',
            categories: [
              for (final sub in subs)
                if (sub.group == id) sub,
            ],
          ),
      ],
    );
  }
}

/// Home banner from `/api/v2/banner/get`.
class HomeBanner {
  const HomeBanner({
    required this.imageUrl,
    this.title,
    this.targetId = 0,
    this.targetType = 0,
    this.url,
  });

  final String imageUrl;

  /// "新歌首发", "独家"...
  final String? title;
  final int targetId;

  /// 1 song, 10 album, 1000 playlist, 3000 url...
  final int targetType;
  final String? url;

  static List<HomeBanner> listFrom(Object? raw) => [
    for (final item in jsonMaps(raw))
      if (jsonText(item['imageUrl'] ?? item['pic']) case final image?)
        HomeBanner(
          imageUrl: image,
          title: jsonText(item['typeTitle']),
          targetId: jsonInt(item['targetId']),
          targetType: jsonInt(item['targetType']),
          url: jsonText(item['url']),
        ),
  ];
}
