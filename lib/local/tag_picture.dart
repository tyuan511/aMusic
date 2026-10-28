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
