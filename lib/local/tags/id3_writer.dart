import 'dart:typed_data';

import '../byte_source.dart';
import 'tag_data.dart';

/// ID3v2.3 encoder.
///
/// v2.3 rather than v2.4 because it is what Windows Explorer, older car head
/// units and most players read reliably. Text that is not Latin-1 is written
/// as UTF-16 with a BOM (encoding 1), the only Unicode encoding v2.3 has.
class Id3v2Writer {
  Id3v2Writer._();

  /// Padding appended after the frames so later edits by other tools do not
  /// have to rewrite the whole file.
  static const int padding = 1024;

  /// Builds a complete tag (header + frames + padding).
  static Uint8List build(TagData tag) {
    final frames = ByteWriter();
    void text(String id, String? value) {
      if (value == null || value.trim().isEmpty) return;
      _frame(frames, id, _encodedText(value.trim()));
    }

    text('TIT2', tag.title);
    // v2.3 separates multiple artists with '/'.
    text('TPE1', tag.artists.where((a) => a.trim().isNotEmpty).join('/'));
    text('TALB', tag.album);
    if (tag.trackNumber != null && tag.trackNumber! > 0) {
      text('TRCK', '${tag.trackNumber}');
    }
    if (tag.discNumber != null && tag.discNumber! > 0) {
      text('TPOS', '${tag.discNumber}');
    }
    final lyrics = tag.lyrics;
    if (lyrics != null && lyrics.trim().isNotEmpty) {
      _frame(frames, 'USLT', _uslt(lyrics));
    }
    final cover = tag.cover;
    if (cover != null && cover.bytes.isNotEmpty) {
      _frame(frames, 'APIC', _apic(cover));
    }

    final body = frames.take();
    final out = ByteWriter()
      ..ascii('ID3')
      ..byte(3) // version 2.3
      ..byte(0) // revision
      ..byte(0) // flags: no unsynchronisation, no extended header
      ..syncsafe(body.length + padding)
      ..bytes(body)
      ..bytes(Uint8List(padding));
    return out.take();
  }

  static void _frame(ByteWriter out, String id, List<int> payload) {
    out
      ..ascii(id)
      // v2.3 frame sizes are plain 32 bit integers (not syncsafe).
      ..u32be(payload.length)
      ..u16be(0)
      ..bytes(payload);
  }

  static bool _isLatin1(String value) =>
      value.codeUnits.every((unit) => unit < 0x100);

  /// Encoding byte + text (no terminator, text frames do not need one).
  static List<int> _encodedText(String value) {
    if (_isLatin1(value)) return [0, ...value.codeUnits];
    return [1, ..._utf16(value)];
  }

  /// UTF-16 little endian with BOM.
  static List<int> _utf16(String value) {
    final out = <int>[0xFF, 0xFE];
    for (final unit in value.codeUnits) {
      out
        ..add(unit & 0xFF)
        ..add(unit >> 8);
    }
    return out;
  }

  static List<int> _uslt(String lyrics) {
    final out = ByteWriter();
    final latin = _isLatin1(lyrics);
    out
      ..byte(latin ? 0 : 1)
      ..ascii(latin ? 'eng' : 'chi');
    if (latin) {
      out
        ..byte(0) // empty description
        ..bytes(lyrics.codeUnits);
    } else {
      out
        ..bytes(_utf16(''))
        ..bytes(const [0, 0])
        ..bytes(_utf16(lyrics));
    }
    return out.take();
  }

  static List<int> _apic(TagPicture picture) {
    final out = ByteWriter()
      ..byte(0) // description encoding: Latin-1
      ..ascii(picture.mime)
      ..byte(0)
      ..byte(3) // picture type: front cover
      ..byte(0) // empty description
      ..bytes(picture.bytes);
    return out.take();
  }

  /// Size in bytes of the ID3v2 tag(s) at the start of [header] (the first
  /// 10 bytes of each tag are needed; several stacked tags are skipped one by
  /// one by the caller). Returns 0 when [header] does not start with `ID3`.
  static int tagSize(List<int> header) {
    if (header.length < 10 || !header.matches(0, 'ID3')) return 0;
    final footer = (header[5] & 0x10) != 0 ? 10 : 0;
    return 10 + header.syncsafe(6) + footer;
  }
}
