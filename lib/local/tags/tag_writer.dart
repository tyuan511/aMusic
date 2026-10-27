import 'dart:io';
import 'dart:typed_data';

import '../byte_source.dart';
import 'flac_writer.dart';
import 'id3_writer.dart';
import 'tag_data.dart';

/// Container format detected from the file content (not the extension:
/// NetEase sometimes serves a FLAC with an ID3 prefix, or an mp3 named .flac).
enum AudioContainer { mp3, flac, m4a, ogg, wav, aac, unknown }

/// Writes [TagData] into downloaded files. Pure Dart, async IO, streamed:
/// only headers are held in memory, the audio payload is copied in chunks.
class TagWriter {
  TagWriter._();

  /// Sniffs the container of [source].
  static Future<AudioContainer> sniff(ByteSource source) async {
    var offset = 0;
    // Skip (possibly stacked) ID3v2 tags.
    for (var i = 0; i < 4; i++) {
      final head = await source.read(offset, 10);
      final size = Id3v2Writer.tagSize(head);
      if (size == 0) break;
      offset += size;
    }
    final head = await source.read(offset, 12);
    if (head.length < 4) return AudioContainer.unknown;
    if (head.matches(0, 'fLaC')) return AudioContainer.flac;
    if (head.matches(0, 'OggS')) return AudioContainer.ogg;
    if (head.matches(0, 'RIFF') && head.matches(8, 'WAVE')) {
      return AudioContainer.wav;
    }
    if (head.length >= 8 && head.matches(4, 'ftyp')) return AudioContainer.m4a;
    if (head[0] == 0xFF && (head[1] & 0xF6) == 0xF0) return AudioContainer.aac;
    if (head[0] == 0xFF && (head[1] & 0xE0) == 0xE0) return AudioContainer.mp3;
    // An ID3 tag followed by something else is still most likely an mp3.
    return offset > 0 ? AudioContainer.mp3 : AudioContainer.unknown;
  }

  /// Copies [sourcePath] to [targetPath] with [tag] embedded. Returns `false`
  /// (writing nothing) when the format cannot be tagged; the caller then
  /// keeps the untagged file.
  static Future<bool> writeTagged(
    String sourcePath,
    String targetPath,
    TagData tag,
  ) async {
    final source = await FileByteSource.open(sourcePath);
    try {
      final container = await sniff(source);
      switch (container) {
        case AudioContainer.mp3:
          await _writeMp3(source, targetPath, tag);
          return true;
        case AudioContainer.flac:
          return await _writeFlac(source, targetPath, tag);
        default:
          return false;
      }
    } finally {
      await source.close();
    }
  }

  static Future<int> _id3Prefix(ByteSource source) async {
    var offset = 0;
    for (var i = 0; i < 4; i++) {
      final size = Id3v2Writer.tagSize(await source.read(offset, 10));
      if (size == 0) break;
      offset += size;
    }
    return offset;
  }

  static Future<void> _writeMp3(
    ByteSource source,
    String targetPath,
    TagData tag,
  ) async {
    final audioStart = await _id3Prefix(source);
    var audioEnd = source.length;
    // Drop a trailing ID3v1 tag too: the v2 tag replaces it.
    if (audioEnd - audioStart > 128) {
      final tail = await source.read(audioEnd - 128, 3);
      if (tail.matches(0, 'TAG')) audioEnd -= 128;
    }
    await _copyWithHeader(
      source,
      targetPath,
      Id3v2Writer.build(tag),
      audioStart,
      audioEnd,
    );
  }

  static Future<bool> _writeFlac(
    ByteSource source,
    String targetPath,
    TagData tag,
  ) async {
    var offset = await _id3Prefix(source);
    if (!(await source.read(offset, 4)).matches(0, 'fLaC')) return false;
    offset += 4;
    final kept = <(int, Uint8List)>[];
    var last = false;
    while (!last) {
      final header = await source.read(offset, 4);
      if (header.length < 4) return false;
      last = (header[0] & 0x80) != 0;
      final type = header[0] & 0x7F;
      final length = header.u24be(1);
      if (offset + 4 + length > source.length) return false;
      if (type != FlacTagWriter.typePadding &&
          type != FlacTagWriter.typeVorbisComment &&
          type != FlacTagWriter.typePicture) {
        kept.add((type, await source.read(offset + 4, length)));
      }
      offset += 4 + length;
    }
    if (kept.isEmpty || kept.first.$1 != FlacTagWriter.typeStreamInfo) {
      return false;
    }
    await _copyWithHeader(
      source,
      targetPath,
      FlacTagWriter.metadata(kept, tag),
      offset,
      source.length,
    );
    return true;
  }

  static const int _chunk = 256 * 1024;

  static Future<void> _copyWithHeader(
    ByteSource source,
    String targetPath,
    Uint8List header,
    int start,
    int end,
  ) async {
    final out = await File(targetPath).open(mode: FileMode.write);
    try {
      await out.writeFrom(header);
      var position = start;
      while (position < end) {
        final chunk = await source.read(
          position,
          end - position < _chunk ? end - position : _chunk,
        );
        if (chunk.isEmpty) break;
        await out.writeFrom(chunk);
        position += chunk.length;
      }
      await out.flush();
    } finally {
      await out.close();
    }
  }
}
