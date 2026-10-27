import 'json_utils.dart';
import 'song.dart';

/// Artist header from `/api/artist/head/info/get` (or the legacy
/// `/api/v1/artist/{id}` body).
class ArtistDetail {
  const ArtistDetail({
    required this.id,
    required this.name,
    this.alias = const [],
    this.avatarUrl,
    this.coverUrl,
    this.briefDesc,
    this.musicSize = 0,
    this.albumSize = 0,
    this.mvSize = 0,
    this.followed = false,
    this.identities = const [],
  });

  final int id;
  final String name;
  final List<String> alias;

  /// Square portrait.
  final String? avatarUrl;

  /// Wide header picture; falls back to [avatarUrl].
  final String? coverUrl;
  final String? briefDesc;
  final int musicSize;
  final int albumSize;
  final int mvSize;

  /// Whether the signed in account follows the artist (always `false` for
  /// guests).
  final bool followed;

  /// "歌手、作词、作曲..." labels when the head endpoint provides them.
  final List<String> identities;

  /// Plain reference for song lists / navigation.
  Artist get ref => Artist(
    id: id,
    name: name,
    picUrl: avatarUrl ?? coverUrl,
    alias: alias,
    albumSize: albumSize,
    musicSize: musicSize,
  );

  factory ArtistDetail.fromJson(Map<String, dynamic> body) {
    final data = jsonMap(body['data']) ?? body;
    final artist = jsonMap(data['artist']) ?? const <String, dynamic>{};
    final user = jsonMap(data['user']);
    final identify = jsonMap(data['identify']);
    final avatar = jsonImage([
      artist['avatar'],
      artist['img1v1Url'],
      artist['picUrl'],
      artist['cover'],
    ]);
    final cover =
        jsonImage([artist['cover'], artist['picUrl'], artist['avatar']]) ??
        avatar;
    final identityText = jsonText(identify?['imageDesc']);
    return ArtistDetail(
      id: jsonInt(artist['id']),
      name: jsonString(artist['name']) ?? '',
      alias: {
        ...jsonStrings(artist['alias']),
        ...jsonStrings(artist['transNames']),
        ?jsonText(artist['trans']),
      }.toList(growable: false),
      avatarUrl: avatar,
      coverUrl: cover,
      briefDesc: jsonText(artist['briefDesc']),
      musicSize: jsonInt(artist['musicSize']),
      albumSize: jsonInt(artist['albumSize']),
      mvSize: jsonInt(artist['mvSize'] ?? data['videoCount']),
      followed: jsonBool(user?['followed'] ?? artist['followed']),
      identities: identityText != null
          ? identityText
                .split(RegExp('[、,，/]'))
                .map((e) => e.trim())
                .where((e) => e.isNotEmpty)
                .toList(growable: false)
          : jsonStrings(artist['identities']),
    );
  }
}

/// One titled block of `/api/artist/introduction`.
class ArtistDescriptionSection {
  const ArtistDescriptionSection({required this.title, required this.text});

  final String title;
  final String text;
}

/// Full artist biography.
class ArtistDescription {
  const ArtistDescription({this.briefDesc, this.sections = const []});

  final String? briefDesc;
  final List<ArtistDescriptionSection> sections;

  bool get isEmpty => (briefDesc ?? '').isEmpty && sections.isEmpty;

  factory ArtistDescription.fromJson(Map<String, dynamic> body) =>
      ArtistDescription(
        briefDesc: jsonText(body['briefDesc']),
        sections: [
          for (final item in jsonMaps(body['introduction']))
            if (jsonText(item['txt']) case final text?)
              ArtistDescriptionSection(
                title: jsonString(item['ti']) ?? '',
                text: text,
              ),
        ],
      );
}
