import 'json_utils.dart';
import 'song.dart';

/// An album, either a lightweight summary (grids: search, artist albums, new
/// albums) or a full detail with [tracks] from `/api/v1/album/{id}`.
class Album {
  const Album({
    required this.id,
    required this.name,
    this.picUrl,
    this.artists = const [],
    this.publishTime,
    this.company,
    this.description,
    this.size = 0,
    this.type,
    this.subType,
    this.alias = const [],
    this.tracks = const [],
  });

  final int id;
  final String name;
  final String? picUrl;
  final List<Artist> artists;
  final DateTime? publishTime;
  final String? company;
  final String? description;

  /// Number of tracks NetEase reports (`size`), available on summaries too.
  final int size;

  /// `专辑` / `Single` / `EP/Single` / `合集`...
  final String? type;

  /// `录音室版` / `现场版`...
  final String? subType;
  final List<String> alias;

  /// Only filled by [NcmApi.albumDetail]; summaries leave it empty.
  final List<Song> tracks;

  String get artistText =>
      artists.isEmpty ? '未知歌手' : artists.map((a) => a.name).join(' / ');

  /// The reference songs carry.
  AlbumRef get ref => AlbumRef(id: id, name: name, picUrl: picUrl);

  Album copyWith({List<Song>? tracks}) => Album(
    id: id,
    name: name,
    picUrl: picUrl,
    artists: artists,
    publishTime: publishTime,
    company: company,
    description: description,
    size: size,
    type: type,
    subType: subType,
    alias: alias,
    tracks: tracks ?? this.tracks,
  );

  /// Tolerates the search (`artist` + `artists`), artist album (`hotAlbums`),
  /// new album and detail shapes.
  factory Album.fromJson(Map<String, dynamic> json) {
    var artists = Artist.listFrom(json['artists']);
    if (artists.isEmpty) {
      final single = jsonMap(json['artist']);
      if (single != null) artists = [Artist.fromJson(single)];
    }
    final trans = jsonText(json['transName']);
    return Album(
      id: jsonInt(json['id']),
      name: jsonString(json['name']) ?? '',
      picUrl:
          jsonText(json['picUrl']) ??
          jsonText(json['blurPicUrl']) ??
          jsonText(json['coverUrl']),
      artists: artists,
      publishTime: jsonTime(json['publishTime']),
      company: jsonText(json['company']),
      description: jsonText(json['description']) ?? jsonText(json['briefDesc']),
      size: jsonInt(json['size'] ?? json['songCount'] ?? json['trackCount']),
      type: jsonText(json['type']),
      subType: jsonText(json['subType']),
      alias: {
        ...jsonStrings(json['alias']),
        ...jsonStrings(json['transNames']),
        ?trans,
      }.toList(growable: false),
    );
  }

  /// Parses the `/api/v1/album/{id}` body: `album` plus `songs`. Songs
  /// without artwork inherit the album cover.
  factory Album.detailFromJson(Map<String, dynamic> body) {
    final album = Album.fromJson(jsonMap(body['album']) ?? const {});
    final ref = album.ref;
    final tracks = [
      for (final song in Song.listFrom(body['songs']))
        song.album.picUrl == null || song.album.id == 0
            ? song.copyWith(album: ref)
            : song,
    ];
    return album.copyWith(tracks: tracks);
  }

  static List<Album> listFrom(Object? raw) => [
    for (final map in jsonMaps(raw))
      if (jsonInt(map['id']) > 0) Album.fromJson(map),
  ];
}
