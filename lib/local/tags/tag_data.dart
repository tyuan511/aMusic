import 'dart:typed_data';

/// Embedded picture (front cover).
class TagPicture {
  const TagPicture({required this.bytes, required this.mime});

  final Uint8List bytes;

  /// `image/jpeg` or `image/png`.
  final String mime;

  /// Sniffs JPEG / PNG from the magic bytes, `null` for anything else.
  static TagPicture? sniff(Uint8List bytes) {
    final mime = mimeOf(bytes);
    return mime == null ? null : TagPicture(bytes: bytes, mime: mime);
  }

  static String? mimeOf(List<int> bytes) {
    if (bytes.length > 3 &&
        bytes[0] == 0xFF &&
        bytes[1] == 0xD8 &&
        bytes[2] == 0xFF) {
      return 'image/jpeg';
    }
    if (bytes.length > 8 &&
        bytes[0] == 0x89 &&
        bytes[1] == 0x50 &&
        bytes[2] == 0x4E &&
        bytes[3] == 0x47) {
      return 'image/png';
    }
    return null;
  }

  /// `jpg` / `png`.
  String get extension => mime == 'image/png' ? 'png' : 'jpg';
}

/// Metadata written into downloaded files.
class TagData {
  const TagData({
    required this.title,
    this.artists = const [],
    this.album,
    this.trackNumber,
    this.discNumber,
    this.cover,
    this.lyrics,
  });

  final String title;
  final List<String> artists;
  final String? album;
  final int? trackNumber;
  final int? discNumber;
  final TagPicture? cover;

  /// Plain (untimed) lyrics, see [plainLyrics].
  final String? lyrics;
}

final RegExp _lrcTimestamp = RegExp(r'\[\d{1,3}:\d{1,2}(?:[.:]\d{1,3})?\]');
final RegExp _lrcMetaLine = RegExp(r'^\[[a-zA-Z]+:.*\]$');

/// Turns an LRC document into plain lyrics for `USLT` / `LYRICS`: drops time
/// tags, `[ar:...]` style header lines and NetEase's JSON credit lines.
String? plainLyrics(String? lrc) {
  if (lrc == null || lrc.trim().isEmpty) return null;
  final lines = <String>[];
  for (final raw in lrc.split(RegExp(r'\r?\n'))) {
    final line = raw.trim();
    if (line.startsWith('{') && line.endsWith('}')) continue;
    if (_lrcMetaLine.hasMatch(line)) continue;
    lines.add(line.replaceAll(_lrcTimestamp, '').trim());
  }
  while (lines.isNotEmpty && lines.first.isEmpty) {
    lines.removeAt(0);
  }
  while (lines.isNotEmpty && lines.last.isEmpty) {
    lines.removeLast();
  }
  final text = lines.join('\n');
  return text.isEmpty ? null : text;
}
