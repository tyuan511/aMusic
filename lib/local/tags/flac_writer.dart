import 'dart:convert';
import 'dart:typed_data';

import '../byte_source.dart';
import 'tag_data.dart';

/// Builds FLAC metadata blocks (VORBIS_COMMENT, PICTURE, PADDING).
class FlacTagWriter {
  FlacTagWriter._();

  static const int typeStreamInfo = 0;
  static const int typePadding = 1;
  static const int typeVorbisComment = 4;
  static const int typePicture = 6;

  /// Largest block body the 24 bit length field can express.
  static const int maxBlockLength = 0xFFFFFF;

  static const String vendor = 'aMusic';

  /// VORBIS_COMMENT body (without the 4 byte block header).
  static Uint8List vorbisComment(TagData tag) {
    final comments = <String>[
      'TITLE=${tag.title}',
      for (final artist in tag.artists)
        if (artist.trim().isNotEmpty) 'ARTIST=${artist.trim()}',
      if (tag.album != null && tag.album!.trim().isNotEmpty)
        'ALBUM=${tag.album!.trim()}',
      if (tag.trackNumber != null && tag.trackNumber! > 0)
        'TRACKNUMBER=${tag.trackNumber}',
      if (tag.discNumber != null && tag.discNumber! > 0)
        'DISCNUMBER=${tag.discNumber}',
      if (tag.lyrics != null && tag.lyrics!.trim().isNotEmpty)
        'LYRICS=${tag.lyrics}',
    ];
    final out = ByteWriter();
    final vendorBytes = utf8.encode(vendor);
    out
      ..u32le(vendorBytes.length)
      ..bytes(vendorBytes)
      ..u32le(comments.length);
    for (final comment in comments) {
      final bytes = utf8.encode(comment);
      out
        ..u32le(bytes.length)
        ..bytes(bytes);
    }
    return out.take();
  }

  /// PICTURE body (front cover). Width / height / depth are left 0, which
  /// the spec allows ("unknown").
  static Uint8List picture(TagPicture cover) {
    final mime = ascii.encode(cover.mime);
    final out = ByteWriter()
      ..u32be(3) // front cover
      ..u32be(mime.length)
      ..bytes(mime)
      ..u32be(0) // description length
      ..u32be(0) // width
      ..u32be(0) // height
      ..u32be(0) // colour depth
      ..u32be(0) // indexed colours
      ..u32be(cover.bytes.length)
      ..bytes(cover.bytes);
    return out.take();
  }

  /// One metadata block with its header.
  static Uint8List block(int type, List<int> body, {required bool last}) {
    final out = ByteWriter()
      ..byte((last ? 0x80 : 0) | (type & 0x7F))
      ..u24be(body.length)
      ..bytes(body);
    return out.take();
  }

  /// Rebuilt metadata section: `fLaC` + [kept] blocks (STREAMINFO first, as
  /// read from the file) + new comment / picture + padding.
  static Uint8List metadata(List<(int, Uint8List)> kept, TagData tag) {
    final blocks = <(int, List<int>)>[
      for (final entry in kept) (entry.$1, entry.$2),
      (typeVorbisComment, vorbisComment(tag)),
    ];
    final cover = tag.cover;
    if (cover != null) {
      final body = picture(cover);
      if (body.length <= maxBlockLength) blocks.add((typePicture, body));
    }
    blocks.add((typePadding, Uint8List(1024)));
    final out = ByteWriter()..ascii('fLaC');
    for (var i = 0; i < blocks.length; i++) {
      out.bytes(
        block(blocks[i].$1, blocks[i].$2, last: i == blocks.length - 1),
      );
    }
    return out.take();
  }
}
