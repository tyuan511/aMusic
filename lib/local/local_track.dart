import 'dart:convert';

import 'package:crypto/crypto.dart';

import '../models/song.dart';
import 'file_names.dart';

/// Where a local track came from.
enum LocalTrackSource {
  /// Found while scanning a folder.
  scan,

  /// Picked with "导入文件".
  import;

  static LocalTrackSource fromName(String? name) =>
      name == 'import' ? LocalTrackSource.import : LocalTrackSource.scan;
}

/// Stable NEGATIVE song id for a local file, derived from its path (48 bits
/// of a SHA-1), so it never collides with NetEase ids and survives restarts.
int localIdForPath(String path) {
  final digest = sha1.convert(utf8.encode(pathKey(path))).bytes;
  var value = 0;
  for (var i = 0; i < 6; i++) {
    value = (value << 8) | digest[i];
  }
  return -(value + 1);
}

/// Stable negative id for a local artist / album name (grouping only).
int localGroupId(String name) {
  final digest = md5.convert(utf8.encode(name.toLowerCase())).bytes;
  var value = 0;
  for (var i = 0; i < 4; i++) {
    value = (value << 8) | digest[i];
  }
  return -(value + 1);
}

/// One audio file in the local library.
class LocalTrack {
  const LocalTrack({
    required this.path,
    required this.title,
    required this.artist,
    required this.album,
    required this.duration,
    required this.size,
    required this.modified,
    required this.added,
    this.trackNumber,
    this.coverPath,
    this.source = LocalTrackSource.scan,
    this.format = '',
  });

  static const String unknownArtist = '未知歌手';
  static const String unknownAlbum = '未知专辑';

  final String path;
  final String title;

  /// Display artist, `' / '` separated when several.
  final String artist;
  final String album;
  final Duration duration;
  final int size;
  final DateTime modified;
  final DateTime added;
  final int? trackNumber;

  /// Extracted cover in the app cache, `null` when the file has none.
  final String? coverPath;
  final LocalTrackSource source;

  /// Lower case extension (`mp3`, `flac`...).
  final String format;

  int get id => localIdForPath(path);

  List<String> get artistNames => artist
      .split(RegExp(r'\s*/\s*|\s*;\s*'))
      .where((name) => name.isNotEmpty)
      .toList(growable: false);

  /// Cover url for [Song.album.picUrl]: a `file://` uri of [coverPath]
  /// (percent encoded, valid on Windows too).
  String? get coverUrl =>
      coverPath == null ? null : Uri.file(coverPath!).toString();

  Song toSong() => Song(
    id: id,
    name: title,
    artists: [
      for (final name in artistNames.isEmpty ? [unknownArtist] : artistNames)
        Artist(id: localGroupId(name), name: name),
    ],
    album: AlbumRef(
      id: localGroupId('$album|$artist'),
      name: album,
      picUrl: coverUrl,
    ),
    duration: duration,
    no: trackNumber,
  );

  LocalTrack copyWith({String? coverPath, bool clearCover = false}) =>
      LocalTrack(
        path: path,
        title: title,
        artist: artist,
        album: album,
        duration: duration,
        size: size,
        modified: modified,
        added: added,
        trackNumber: trackNumber,
        coverPath: clearCover ? null : (coverPath ?? this.coverPath),
        source: source,
        format: format,
      );

  Map<String, dynamic> toJson() => {
    'path': path,
    'title': title,
    'artist': artist,
    'album': album,
    'ms': duration.inMilliseconds,
    'size': size,
    'mtime': modified.millisecondsSinceEpoch,
    'added': added.millisecondsSinceEpoch,
    if (trackNumber != null) 'no': trackNumber,
    if (coverPath != null) 'cover': coverPath,
    'source': source.name,
    'format': format,
  };

  static LocalTrack? fromJson(Object? raw) {
    if (raw is! Map) return null;
    final path = raw['path'];
    if (path is! String || path.isEmpty) return null;
    int number(String key) => (raw[key] as num?)?.toInt() ?? 0;
    return LocalTrack(
      path: path,
      title: raw['title'] as String? ?? stemOf(path),
      artist: raw['artist'] as String? ?? unknownArtist,
      album: raw['album'] as String? ?? unknownAlbum,
      duration: Duration(milliseconds: number('ms')),
      size: number('size'),
      modified: DateTime.fromMillisecondsSinceEpoch(number('mtime')),
      added: DateTime.fromMillisecondsSinceEpoch(number('added')),
      trackNumber: (raw['no'] as num?)?.toInt(),
      coverPath: raw['cover'] as String?,
      source: LocalTrackSource.fromName(raw['source'] as String?),
      format: raw['format'] as String? ?? extensionOf(path),
    );
  }
}
