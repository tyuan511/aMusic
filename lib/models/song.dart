import 'json_utils.dart';

/// Audio quality levels accepted by `/song/url/v1?level=`.
enum AudioLevel {
  standard('standard', '标准', 128000),
  higher('higher', '较高', 192000),
  exhigh('exhigh', '极高', 320000),
  lossless('lossless', '无损', 999000),
  hires('hires', 'Hi-Res', 1999000),
  jyeffect('jyeffect', '高清臻音', 2000000),
  sky('sky', '沉浸环绕声', 2100000),
  jymaster('jymaster', '超清母带', 2200000);

  const AudioLevel(this.value, this.label, this.bitrate);

  final String value;
  final String label;
  final int bitrate;

  static AudioLevel fromValue(String? value) => AudioLevel.values.firstWhere(
    (level) => level.value == value,
    orElse: () => AudioLevel.exhigh,
  );

  /// Tiers to try, in order, when this one has no url for the account:
  /// this level, then lossless -> exhigh -> higher -> standard (only the ones
  /// below this level).
  List<AudioLevel> get fallbackChain => [
    this,
    for (final lower in const [
      AudioLevel.lossless,
      AudioLevel.exhigh,
      AudioLevel.higher,
      AudioLevel.standard,
    ])
      if (lower.bitrate < bitrate) lower,
  ];
}

/// `fee` field of a track.
enum SongFee {
  free(0),
  vip(1),
  trial(4),
  album(8);

  const SongFee(this.value);

  final int value;

  static SongFee fromValue(int? value) => SongFee.values.firstWhere(
    (fee) => fee.value == value,
    orElse: () => SongFee.free,
  );

  String? get badge {
    switch (this) {
      case SongFee.vip:
        return 'VIP';
      case SongFee.album:
        return '数字专辑';
      case SongFee.trial:
        return '试听';
      case SongFee.free:
        return null;
    }
  }
}

class Artist {
  const Artist({
    required this.id,
    required this.name,
    this.picUrl,
    this.alias = const [],
    this.albumSize,
    this.musicSize,
  });

  final int id;
  final String name;

  /// Portrait, `null` when NetEase only has its grey placeholder.
  final String? picUrl;

  /// Alternative names (`alias` / `alia` / `trans`).
  final List<String> alias;

  /// Only present in search / similar artist payloads.
  final int? albumSize;
  final int? musicSize;

  factory Artist.fromJson(Map<String, dynamic> json) {
    final trans = jsonText(json['trans']);
    final alias = {
      ...jsonStrings(json['alias'] ?? json['alia']),
      ...jsonStrings(json['transNames']),
      ?trans,
    }.toList(growable: false);
    return Artist(
      id: jsonInt(json['id']),
      name: jsonString(json['name']) ?? '',
      picUrl: jsonImage([
        json['picUrl'],
        json['avatar'],
        json['cover'],
        json['img1v1Url'],
      ]),
      alias: alias,
      albumSize: jsonIntOrNull(json['albumSize']),
      musicSize: jsonIntOrNull(json['musicSize']),
    );
  }

  /// Old `/search` payloads use `artists`, new ones use `ar`.
  static List<Artist> listFrom(Object? raw) {
    if (raw is! List) return const [];
    return jsonMaps(raw).map(Artist.fromJson).toList(growable: false);
  }

  /// Only id/name (+ picture when known), which is what queues persist.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (picUrl != null) 'picUrl': picUrl,
  };
}

class AlbumRef {
  const AlbumRef({required this.id, required this.name, this.picUrl});

  final int id;
  final String name;
  final String? picUrl;

  factory AlbumRef.fromJson(Map<String, dynamic> json) => AlbumRef(
    id: (json['id'] as num?)?.toInt() ?? 0,
    name: json['name'] as String? ?? '',
    picUrl: jsonText(json['picUrl']) ?? jsonText(json['blurPicUrl']),
  );

  /// Old `/search` payloads use `album`, new ones use `al`.
  static AlbumRef? from(Object? raw) {
    final map = jsonMap(raw);
    return map == null ? null : AlbumRef.fromJson(map);
  }

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'picUrl': picUrl};
}

class Song {
  const Song({
    required this.id,
    required this.name,
    required this.artists,
    required this.album,
    required this.duration,
    this.fee = SongFee.free,
    this.playable = true,
    this.maxLevel,
    this.alias = const [],
    this.liked = false,
    this.no,
    this.cd,
  });

  /// Same as [listFrom] but matches privileges by song id instead of
  /// position (song/detail answers them in a separate, unordered array).
  static List<Song> listWithPrivileges(Object? raw, Object? privileges) {
    final byId = {
      for (final priv in jsonMaps(privileges)) jsonInt(priv['id']): priv,
    };
    return [
      for (final map in jsonMaps(raw))
        Song.fromJson(map, privilege: byId[jsonInt(map['id'])]),
    ];
  }

  final int id;
  final String name;
  final List<Artist> artists;
  final AlbumRef album;
  final Duration duration;
  final SongFee fee;

  /// `false` when the track is greyed out (copyright removed).
  final bool playable;

  /// Highest quality the account is allowed to stream, from `privilege`.
  final String? maxLevel;
  final List<String> alias;

  /// Not part of the API payload; merged in from the user's liked list.
  final bool liked;

  /// Track number inside its album (`no`), when the payload has one.
  final int? no;

  /// Disc number (`cd`, often a string such as `"1"` or `"01"`).
  final int? cd;

  String get artistText =>
      artists.isEmpty ? '未知歌手' : artists.map((a) => a.name).join(' / ');

  String get displayTitle =>
      alias.isEmpty || alias.first.isEmpty ? name : '$name (${alias.first})';

  Song copyWith({
    bool? liked,
    AlbumRef? album,
    bool? playable,
    String? maxLevel,
  }) => Song(
    id: id,
    name: name,
    artists: artists,
    album: album ?? this.album,
    duration: duration,
    fee: fee,
    playable: playable ?? this.playable,
    maxLevel: maxLevel ?? this.maxLevel,
    alias: alias,
    liked: liked ?? this.liked,
    no: no,
    cd: cd,
  );

  /// Parses the `ar` / `al` / `dt` shape used by `/cloudsearch`,
  /// `/playlist/detail`, `/playlist/track/all` and `/recommend/songs`, and
  /// falls back to the legacy `artists` / `album` / `duration` shape.
  factory Song.fromJson(
    Map<String, dynamic> json, {
    Map<String, dynamic>? privilege,
  }) {
    final priv = privilege ?? jsonMap(json['privilege']);
    final playable = _resolvePlayable(json, priv);
    return Song(
      id: jsonInt(json['id']),
      name: (json['name'] as String?) ?? '',
      artists: Artist.listFrom(json['ar'] ?? json['artists']),
      album:
          AlbumRef.from(json['al'] ?? json['album']) ??
          const AlbumRef(id: 0, name: ''),
      duration: Duration(milliseconds: _durationMs(json)),
      fee: SongFee.fromValue(jsonIntOrNull(json['fee'] ?? priv?['fee'])),
      playable: playable,
      maxLevel: jsonText(priv?['maxBrLevel']),
      alias: jsonStrings(json['alia'] ?? json['alias']),
      no: _positive(json['no']),
      cd: _positive(json['cd'] ?? json['disc']),
    );
  }

  static int? _positive(Object? raw) {
    final value = jsonIntOrNull(raw);
    return value == null || value <= 0 ? null : value;
  }

  static int _durationMs(Map<String, dynamic> json) {
    return jsonInt(json['dt'] ?? json['duration'] ?? json['playTime']);
  }

  static bool _resolvePlayable(
    Map<String, dynamic> json,
    Map<String, dynamic>? priv,
  ) {
    // `st` < 0 means the track was taken down.
    final st = jsonIntOrNull(json['st']);
    if (st != null && st < 0) return false;
    if (priv == null) return true;
    // In privilege payloads `code` 0 and 200 both mean "fine"; anything else
    // (404, -110...) means the account may not stream it. Whether the account
    // actually can is only known after requesting the play url, so this is the
    // most the metadata can tell us.
    final code = jsonIntOrNull(priv['code']);
    if (code != null && code != 0 && code != 200) return false;
    return true;
  }

  static List<Song> listFrom(
    Object? raw, {
    List<Map<String, dynamic>>? privileges,
  }) {
    if (raw is! List) return const [];
    final result = <Song>[];
    for (var i = 0; i < raw.length; i++) {
      final item = raw[i];
      final map = jsonMap(item);
      if (map == null) continue;
      Map<String, dynamic>? priv;
      if (privileges != null && i < privileges.length) priv = privileges[i];
      result.add(Song.fromJson(map, privilege: priv));
    }
    return result;
  }

  /// Persisted by `PlaybackSnapshot`. Deliberately has no `st` (playability)
  /// flag: whether a track streams is decided by the server on play.
  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'ar': artists.map((a) => a.toJson()).toList(),
    'al': album.toJson(),
    'dt': duration.inMilliseconds,
    'fee': fee.value,
    'alia': alias,
    if (no != null) 'no': no,
    if (cd != null) 'cd': cd,
    if (maxLevel != null) 'privilege': {'maxBrLevel': maxLevel},
  };

  @override
  bool operator ==(Object other) => other is Song && other.id == id;

  @override
  int get hashCode => id.hashCode;
}
