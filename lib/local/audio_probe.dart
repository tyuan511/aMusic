import 'dart:convert';
import 'dart:typed_data';

import 'byte_source.dart';
import 'file_names.dart';
import 'tags/id3_writer.dart';
import 'tags/tag_data.dart';
import 'tags/tag_writer.dart';

/// Metadata read from an audio file. Empty strings mean "not tagged".
class AudioMetadata {
  const AudioMetadata({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.trackNumber,
    this.cover,
    this.container = AudioContainer.unknown,
  });

  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int? trackNumber;
  final TagPicture? cover;
  final AudioContainer container;

  AudioMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    int? trackNumber,
    TagPicture? cover,
    AudioContainer? container,
  }) => AudioMetadata(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    duration: duration ?? this.duration,
    trackNumber: trackNumber ?? this.trackNumber,
    cover: cover ?? this.cover,
    container: container ?? this.container,
  );
}

/// Pure Dart tag / duration reader for mp3 (ID3v2.2-2.4 + ID3v1), FLAC
/// (STREAMINFO, Vorbis comments, PICTURE), M4A (mvhd + ilst), WAV, Ogg
/// (Vorbis / Opus) and ADTS AAC.
///
/// Reads only the parts it needs through a [ByteSource]; every read is async
/// so probing a library never blocks a frame for long.
class AudioProbe {
  const AudioProbe();

  /// Largest tag / atom read into memory (covers above this are skipped).
  static const int maxTagBytes = 16 * 1024 * 1024;

  /// Probes the file at [path]. Never throws: unreadable files yield empty
  /// metadata (the file name fallback still applies).
  Future<AudioMetadata> probeFile(String path) async {
    ByteSource? source;
    try {
      source = await FileByteSource.open(path);
      return await probe(source, extensionHint: extensionOf(path));
    } on Object {
      return const AudioMetadata();
    } finally {
      await source?.close();
    }
  }

  Future<AudioMetadata> probe(
    ByteSource source, {
    String extensionHint = '',
  }) async {
    final container = await TagWriter.sniff(source);
    final AudioMetadata result;
    switch (container) {
      case AudioContainer.flac:
        result = await _flac(source);
      case AudioContainer.m4a:
        result = await _m4a(source);
      case AudioContainer.wav:
        result = await _wav(source);
      case AudioContainer.ogg:
        result = await _ogg(source);
      case AudioContainer.aac:
        result = await _aac(source);
      case AudioContainer.mp3:
        result = await _mp3(source);
      case AudioContainer.unknown:
        result = extensionHint == 'mp3'
            ? await _mp3(source)
            : const AudioMetadata();
    }
    return result.copyWith(container: container);
  }

  // ------------------------------------------------------------------ mp3

  Future<AudioMetadata> _mp3(ByteSource source) async {
    var meta = const AudioMetadata();
    var offset = 0;
    var tagLength = 0;
    final head = await source.read(0, 10);
    final size = Id3v2Writer.tagSize(head);
    if (size > 0) {
      tagLength = size;
      if (size <= maxTagBytes) {
        meta = _parseId3v2(await source.read(0, size));
      }
      offset = size;
      // Skip further stacked tags for the frame scan.
      for (var i = 0; i < 3; i++) {
        final next = Id3v2Writer.tagSize(await source.read(offset, 10));
        if (next == 0) break;
        offset += next;
      }
    }
    if (meta.title.isEmpty && source.length > 128) {
      final v1 = await source.read(source.length - 128, 128);
      if (v1.matches(0, 'TAG')) {
        String field(int at, int length) =>
            latin1.decode(_trimNul(v1.sublist(at, at + length))).trim();
        meta = meta.copyWith(
          title: field(3, 30),
          artist: meta.artist.isEmpty ? field(33, 30) : meta.artist,
          album: meta.album.isEmpty ? field(63, 30) : meta.album,
          trackNumber:
              meta.trackNumber ??
              (v1[125] == 0 && v1[126] != 0 ? v1[126] : null),
        );
      }
    }
    if (meta.duration == Duration.zero) {
      final duration = await _mpegDuration(source, offset, tagLength);
      if (duration != null) meta = meta.copyWith(duration: duration);
    }
    return meta;
  }

  static List<int> _trimNul(List<int> bytes) {
    final end = bytes.indexOf(0);
    return end < 0 ? bytes : bytes.sublist(0, end);
  }

  /// Parses a whole ID3v2 tag (header included).
  static AudioMetadata _parseId3v2(Uint8List tag) {
    if (tag.length < 10) return const AudioMetadata();
    final version = tag[3];
    final flags = tag[5];
    var body = Uint8List.sublistView(tag, 10);
    // v2.2 / v2.3 unsynchronise the whole tag.
    if ((flags & 0x80) != 0 && version < 4) body = _deunsync(body);
    var pos = 0;
    if ((flags & 0x40) != 0 && version >= 3 && body.length >= 4) {
      // Extended header: v2.3 size excludes itself, v2.4 is syncsafe total.
      pos = version == 3 ? body.u32be(0) + 4 : body.syncsafe(0);
    }
    final idLength = version == 2 ? 3 : 4;
    final headerLength = version == 2 ? 6 : 10;
    var title = '', artist = '', album = '';
    int? track;
    Duration? length;
    TagPicture? cover;
    var coverIsFront = false;
    while (pos + headerLength <= body.length) {
      if (body[pos] == 0) break; // padding
      final id = latin1.decode(body.sublist(pos, pos + idLength));
      int frameSize;
      var frameFlags = 0;
      if (version == 2) {
        frameSize = body.u24be(pos + 3);
      } else if (version == 4) {
        frameSize = body.syncsafe(pos + 4);
        frameFlags = body.u16be(pos + 8);
      } else {
        frameSize = body.u32be(pos + 4);
      }
      final start = pos + headerLength;
      final end = start + frameSize;
      if (frameSize <= 0 || end > body.length) break;
      var data = Uint8List.sublistView(body, start, end);
      if (version == 4) {
        // Data length indicator precedes the data.
        if ((frameFlags & 0x0001) != 0 && data.length >= 4) {
          data = Uint8List.sublistView(data, 4);
        }
        if ((frameFlags & 0x0002) != 0) data = _deunsync(data);
      }
      switch (id) {
        case 'TIT2' || 'TT2':
          title = _id3Text(data);
        case 'TPE1' || 'TP1':
          artist = _id3Text(data);
        case 'TALB' || 'TAL':
          album = _id3Text(data);
        case 'TRCK' || 'TRK':
          track = int.tryParse(_id3Text(data).split('/').first.trim());
        case 'TLEN' || 'TLE':
          final ms = int.tryParse(_id3Text(data).trim());
          if (ms != null && ms > 0) length = Duration(milliseconds: ms);
        case 'APIC' || 'PIC':
          if (!coverIsFront) {
            final picture = _id3Picture(data, v22: version == 2);
            if (picture != null) {
              cover = picture.$1;
              coverIsFront = picture.$2 == 3;
            }
          }
      }
      pos = end;
    }
    if (version >= 4) artist = artist.replaceAll('\u0000', ' / ');
    return AudioMetadata(
      title: title,
      artist: artist,
      album: album,
      trackNumber: track,
      duration: length ?? Duration.zero,
      cover: cover,
    );
  }

  static Uint8List _deunsync(Uint8List data) {
    final out = BytesBuilder(copy: false);
    for (var i = 0; i < data.length; i++) {
      out.addByte(data[i]);
      if (data[i] == 0xFF && i + 1 < data.length && data[i + 1] == 0) i++;
    }
    return out.takeBytes();
  }

  /// Decodes a text frame payload (encoding byte + text).
  static String _id3Text(List<int> data) {
    if (data.isEmpty) return '';
    final text = _decode(data[0], data.sublist(1));
    return text.replaceAll(RegExp(r'\u0000+$'), '').trim();
  }

  static String _decode(int encoding, List<int> bytes) {
    switch (encoding) {
      case 1:
        return _utf16(bytes, bigEndianDefault: false);
      case 2:
        return _utf16(bytes, bigEndianDefault: true);
      case 3:
        return utf8.decode(bytes, allowMalformed: true);
      default:
        return _latin1OrUtf8(bytes);
    }
  }

  /// Many Chinese mp3s claim Latin-1 but carry UTF-8; prefer UTF-8 when the
  /// bytes are valid UTF-8 with multi byte sequences.
  static String _latin1OrUtf8(List<int> bytes) {
    if (bytes.any((b) => b >= 0x80)) {
      try {
        return utf8.decode(bytes);
      } on FormatException {
        // Real Latin-1.
      }
    }
    return latin1.decode(bytes);
  }

  static String _utf16(List<int> bytes, {required bool bigEndianDefault}) {
    var bigEndian = bigEndianDefault;
    var start = 0;
    if (bytes.length >= 2) {
      if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
        bigEndian = false;
        start = 2;
      } else if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
        bigEndian = true;
        start = 2;
      }
    }
    final units = <int>[];
    for (var i = start; i + 1 < bytes.length; i += 2) {
      units.add(
        bigEndian
            ? (bytes[i] << 8) | bytes[i + 1]
            : bytes[i] | (bytes[i + 1] << 8),
      );
    }
    // A UTF-16 string with several BOMs (multi value v2.4) keeps them as
    // separators; drop stray BOM characters.
    return String.fromCharCodes(units).replaceAll('\uFEFF', '');
  }

  /// Returns (picture, picture type).
  static (TagPicture, int)? _id3Picture(Uint8List data, {required bool v22}) {
    if (data.length < 6) return null;
    final encoding = data[0];
    var pos = 1;
    if (v22) {
      pos += 3; // image format, e.g. "JPG"
    } else {
      final end = data.indexOf(0, pos);
      if (end < 0) return null;
      pos = end + 1;
    }
    if (pos >= data.length) return null;
    final type = data[pos];
    pos++;
    // Description, terminated per encoding.
    if (encoding == 1 || encoding == 2) {
      while (pos + 1 < data.length && !(data[pos] == 0 && data[pos + 1] == 0)) {
        pos += 2;
      }
      pos += 2;
    } else {
      final end = data.indexOf(0, pos);
      if (end < 0) return null;
      pos = end + 1;
    }
    if (pos >= data.length) return null;
    final bytes = Uint8List.fromList(data.sublist(pos));
    final picture = TagPicture.sniff(bytes);
    return picture == null ? null : (picture, type);
  }

  static const List<int> _bitratesV1L3 = [
    0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320, 0, //
  ];
  static const List<int> _bitratesV2L3 = [
    0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160, 0, //
  ];

  /// Duration from the first MPEG frame: Xing / Info / VBRI frame count when
  /// present, otherwise the CBR estimate from the bitrate.
  static Future<Duration?> _mpegDuration(
    ByteSource source,
    int start,
    int tagLength,
  ) async {
    final window = await source.read(start, 64 * 1024);
    for (var i = 0; i + 4 <= window.length; i++) {
      if (window[i] != 0xFF || (window[i + 1] & 0xE0) != 0xE0) continue;
      final versionBits =
          (window[i + 1] >> 3) & 0x03; // 3 = v1, 2 = v2, 0 = v2.5
      final layerBits = (window[i + 1] >> 1) & 0x03; // 1 = layer III
      final bitrateIndex = window[i + 2] >> 4;
      final rateIndex = (window[i + 2] >> 2) & 0x03;
      if (versionBits == 1 || layerBits != 1) continue;
      if (bitrateIndex == 0 || bitrateIndex == 15 || rateIndex == 3) continue;
      final v1 = versionBits == 3;
      final baseRate = const [44100, 48000, 32000][rateIndex];
      final sampleRate = v1
          ? baseRate
          : (versionBits == 2 ? baseRate ~/ 2 : baseRate ~/ 4);
      final bitrate = (v1 ? _bitratesV1L3 : _bitratesV2L3)[bitrateIndex] * 1000;
      final samplesPerFrame = v1 ? 1152 : 576;
      final mono = (window[i + 3] >> 6) == 3;
      final sideInfo = v1 ? (mono ? 17 : 32) : (mono ? 9 : 17);
      final xingAt = i + 4 + sideInfo;
      if (window.matches(xingAt, 'Xing') || window.matches(xingAt, 'Info')) {
        final xingFlags = window.u32be(xingAt + 4);
        if ((xingFlags & 0x1) != 0 && xingAt + 12 <= window.length) {
          final frames = window.u32be(xingAt + 8);
          if (frames > 0) {
            return Duration(
              microseconds: frames * samplesPerFrame * 1000000 ~/ sampleRate,
            );
          }
        }
      }
      final vbriAt = i + 4 + 32;
      if (window.matches(vbriAt, 'VBRI') && vbriAt + 18 <= window.length) {
        final frames = window.u32be(vbriAt + 14);
        if (frames > 0) {
          return Duration(
            microseconds: frames * samplesPerFrame * 1000000 ~/ sampleRate,
          );
        }
      }
      final audioBytes = source.length - start;
      if (bitrate <= 0 || audioBytes <= 0) return null;
      return Duration(milliseconds: audioBytes * 8 * 1000 ~/ bitrate);
    }
    return null;
  }

  // ----------------------------------------------------------------- flac

  Future<AudioMetadata> _flac(ByteSource source) async {
    var offset = 0;
    for (var i = 0; i < 4; i++) {
      final size = Id3v2Writer.tagSize(await source.read(offset, 10));
      if (size == 0) break;
      offset += size;
    }
    offset += 4; // fLaC
    var meta = const AudioMetadata();
    TagPicture? cover;
    var coverIsFront = false;
    var last = false;
    while (!last) {
      final header = await source.read(offset, 4);
      if (header.length < 4) break;
      last = (header[0] & 0x80) != 0;
      final type = header[0] & 0x7F;
      final length = header.u24be(1);
      final body = offset + 4;
      if (type == 0 && length >= 18) {
        final info = await source.read(body, 18);
        // 20 bits sample rate, 3 channels, 5 bps, 36 bits total samples.
        final sampleRate = (info[10] << 12) | (info[11] << 4) | (info[12] >> 4);
        final totalSamples = ((info[13] & 0x0F) * 0x100000000) + info.u32be(14);
        if (sampleRate > 0 && totalSamples > 0) {
          meta = meta.copyWith(
            duration: Duration(
              microseconds: totalSamples * 1000000 ~/ sampleRate,
            ),
          );
        }
      } else if (type == 4 && length <= maxTagBytes) {
        meta = _applyVorbis(meta, await source.read(body, length));
      } else if (type == 6 && length <= maxTagBytes && !coverIsFront) {
        final picture = _flacPicture(await source.read(body, length));
        if (picture != null) {
          cover = picture.$1;
          coverIsFront = picture.$2 == 3;
        }
      }
      offset = body + length;
      if (offset > source.length) break;
    }
    return cover == null ? meta : meta.copyWith(cover: cover);
  }

  /// Applies a Vorbis comment block (also used by Ogg) to [meta].
  static AudioMetadata _applyVorbis(AudioMetadata meta, Uint8List data) {
    if (data.length < 8) return meta;
    var pos = 4 + data.u32le(0);
    if (pos + 4 > data.length) return meta;
    final count = data.u32le(pos);
    pos += 4;
    final artists = <String>[];
    var title = meta.title, album = meta.album;
    var track = meta.trackNumber;
    TagPicture? cover = meta.cover;
    for (var i = 0; i < count && pos + 4 <= data.length; i++) {
      final length = data.u32le(pos);
      pos += 4;
      if (pos + length > data.length) break;
      final entry = utf8.decode(
        data.sublist(pos, pos + length),
        allowMalformed: true,
      );
      pos += length;
      final eq = entry.indexOf('=');
      if (eq <= 0) continue;
      final key = entry.substring(0, eq).toUpperCase();
      final value = entry.substring(eq + 1).trim();
      switch (key) {
        case 'TITLE':
          title = value;
        case 'ARTIST':
          if (value.isNotEmpty) artists.add(value);
        case 'ALBUM':
          album = value;
        case 'TRACKNUMBER':
          track = int.tryParse(value.split('/').first.trim()) ?? track;
        case 'METADATA_BLOCK_PICTURE':
          if (cover == null) {
            try {
              cover = _flacPicture(base64.decode(value))?.$1;
            } on FormatException {
              // Ignore a broken picture.
            }
          }
      }
    }
    return meta.copyWith(
      title: title,
      album: album,
      artist: artists.isEmpty ? meta.artist : artists.join(' / '),
      trackNumber: track,
      cover: cover,
    );
  }

  static (TagPicture, int)? _flacPicture(Uint8List data) {
    if (data.length < 32) return null;
    final type = data.u32be(0);
    var pos = 4;
    final mimeLength = data.u32be(pos);
    pos += 4 + mimeLength;
    if (pos + 4 > data.length) return null;
    final descLength = data.u32be(pos);
    pos += 4 + descLength + 16;
    if (pos + 4 > data.length) return null;
    final length = data.u32be(pos);
    pos += 4;
    if (pos + length > data.length) return null;
    final bytes = Uint8List.fromList(data.sublist(pos, pos + length));
    final picture = TagPicture.sniff(bytes);
    return picture == null ? null : (picture, type);
  }

  // ------------------------------------------------------------------ m4a

  Future<AudioMetadata> _m4a(ByteSource source) async {
    final moov = await _findAtom(source, 0, source.length, 'moov');
    if (moov == null) return const AudioMetadata();
    var meta = const AudioMetadata();
    final mvhd = await _findAtom(source, moov.$1, moov.$2, 'mvhd');
    if (mvhd != null) {
      final data = await source.read(mvhd.$1, 32);
      if (data.isNotEmpty) {
        final version = data[0];
        int timescale, duration;
        if (version == 1 && data.length >= 32) {
          timescale = data.u32be(20);
          duration = data.u64be(24);
        } else if (data.length >= 20) {
          timescale = data.u32be(12);
          duration = data.u32be(16);
        } else {
          timescale = 0;
          duration = 0;
        }
        if (timescale > 0 && duration > 0) {
          meta = meta.copyWith(
            duration: Duration(microseconds: duration * 1000000 ~/ timescale),
          );
        }
      }
    }
    final udta = await _findAtom(source, moov.$1, moov.$2, 'udta');
    if (udta == null) return meta;
    final metaAtom = await _findAtom(source, udta.$1, udta.$2, 'meta');
    if (metaAtom == null) return meta;
    // `meta` is a full box (4 byte version / flags) in ISO files, a plain
    // box in some QuickTime files: detect by checking for a child header.
    var metaStart = metaAtom.$1;
    final peek = await source.read(metaStart, 8);
    if (peek.length == 8 && peek.u32be(0) == 0) metaStart += 4;
    final ilst = await _findAtom(source, metaStart, metaAtom.$2, 'ilst');
    if (ilst == null || ilst.$2 - ilst.$1 > maxTagBytes) return meta;
    final items = await source.read(ilst.$1, ilst.$2 - ilst.$1);
    var pos = 0;
    while (pos + 8 <= items.length) {
      final size = items.u32be(pos);
      if (size < 8 || pos + size > items.length) break;
      final name = latin1.decode(items.sublist(pos + 4, pos + 8));
      final value = _ilstData(
        Uint8List.sublistView(items, pos + 8, pos + size),
      );
      if (value != null) {
        final (type, payload) = value;
        String text() => utf8.decode(payload, allowMalformed: true).trim();
        switch (name) {
          case '\u00A9nam':
            meta = meta.copyWith(title: text());
          case '\u00A9ART':
            meta = meta.copyWith(artist: text());
          case 'aART':
            if (meta.artist.isEmpty) meta = meta.copyWith(artist: text());
          case '\u00A9alb':
            meta = meta.copyWith(album: text());
          case 'trkn':
            if (payload.length >= 4) {
              final n = payload.u16be(2);
              if (n > 0) meta = meta.copyWith(trackNumber: n);
            }
          case 'covr':
            if (meta.cover == null && (type == 13 || type == 14 || type == 0)) {
              final picture = TagPicture.sniff(Uint8List.fromList(payload));
              if (picture != null) meta = meta.copyWith(cover: picture);
            }
        }
      }
      pos += size;
    }
    return meta;
  }

  /// First `data` child of an ilst item: (type, payload).
  static (int, Uint8List)? _ilstData(Uint8List item) {
    var pos = 0;
    while (pos + 16 <= item.length) {
      final size = item.u32be(pos);
      if (size < 8 || pos + size > item.length) return null;
      if (item.matches(pos + 4, 'data')) {
        final type = item.u24be(pos + 9);
        return (type, Uint8List.sublistView(item, pos + 16, pos + size));
      }
      pos += size;
    }
    return null;
  }

  /// Finds a direct child atom named [name] within [start, end): returns the
  /// payload range (after the header).
  static Future<(int, int)?> _findAtom(
    ByteSource source,
    int start,
    int end,
    String name,
  ) async {
    var pos = start;
    while (pos + 8 <= end) {
      final header = await source.read(pos, 16);
      if (header.length < 8) return null;
      var size = header.u32be(0);
      var headerLength = 8;
      if (size == 1 && header.length >= 16) {
        size = header.u64be(8);
        headerLength = 16;
      } else if (size == 0) {
        size = end - pos;
      }
      if (size < headerLength || pos + size > end) return null;
      if (header.matches(4, name)) return (pos + headerLength, pos + size);
      pos += size;
    }
    return null;
  }

  // ------------------------------------------------------------------ wav

  Future<AudioMetadata> _wav(ByteSource source) async {
    var pos = 12;
    var byteRate = 0;
    var dataSize = 0;
    var meta = const AudioMetadata();
    while (pos + 8 <= source.length) {
      final header = await source.read(pos, 8);
      if (header.length < 8) break;
      final size = header.u32le(4);
      if (header.matches(0, 'fmt ')) {
        final fmt = await source.read(pos + 8, 16);
        if (fmt.length >= 12) byteRate = fmt.u32le(8);
      } else if (header.matches(0, 'data')) {
        dataSize = size;
        // The data chunk is usually last; LIST chunks after it are rare.
      } else if (header.matches(0, 'LIST') && size <= 1024 * 1024) {
        meta = _wavInfo(meta, await source.read(pos + 8, size));
      }
      pos += 8 + size + (size & 1);
    }
    if (byteRate > 0 && dataSize > 0) {
      meta = meta.copyWith(
        duration: Duration(microseconds: dataSize * 1000000 ~/ byteRate),
      );
    }
    return meta;
  }

  static AudioMetadata _wavInfo(AudioMetadata meta, Uint8List list) {
    if (list.length < 4 || !list.matches(0, 'INFO')) return meta;
    var pos = 4;
    while (pos + 8 <= list.length) {
      final id = latin1.decode(list.sublist(pos, pos + 4));
      final size = list.u32le(pos + 4);
      if (pos + 8 + size > list.length) break;
      final value = _latin1OrUtf8(
        _trimNul(list.sublist(pos + 8, pos + 8 + size)),
      ).trim();
      switch (id) {
        case 'INAM':
          meta = meta.copyWith(title: value);
        case 'IART':
          meta = meta.copyWith(artist: value);
        case 'IPRD':
          meta = meta.copyWith(album: value);
      }
      pos += 8 + size + (size & 1);
    }
    return meta;
  }

  // ------------------------------------------------------------------ ogg

  Future<AudioMetadata> _ogg(ByteSource source) async {
    final head = await source.read(0, 256 * 1024);
    var meta = const AudioMetadata();
    var opus = false;
    var sampleRate = 0;
    var preSkip = 0;
    // Reassemble the first few packets from the pages in [head].
    final packets = _oggPackets(head, maxPackets: 2);
    if (packets.isNotEmpty) {
      final id = packets.first;
      if (id.matches(0, 'OpusHead') && id.length >= 12) {
        opus = true;
        sampleRate = 48000;
        preSkip = id.u16le(10);
      } else if (id.length >= 16 && id[0] == 1 && id.matches(1, 'vorbis')) {
        sampleRate = id.u32le(12);
      }
    }
    if (packets.length > 1) {
      final comment = packets[1];
      if (opus && comment.matches(0, 'OpusTags')) {
        meta = _applyVorbis(meta, Uint8List.sublistView(comment, 8));
      } else if (comment.length > 7 &&
          comment[0] == 3 &&
          comment.matches(1, 'vorbis')) {
        meta = _applyVorbis(meta, Uint8List.sublistView(comment, 7));
      }
    }
    if (sampleRate > 0) {
      final tailStart = source.length > 64 * 1024
          ? source.length - 64 * 1024
          : 0;
      final tail = await source.read(tailStart, 64 * 1024);
      for (var i = tail.length - 27; i >= 0; i--) {
        if (!tail.matches(i, 'OggS')) continue;
        final granule = (tail.u32le(i + 10) * 0x100000000) + tail.u32le(i + 6);
        final samples = granule - preSkip;
        if (samples > 0) {
          meta = meta.copyWith(
            duration: Duration(microseconds: samples * 1000000 ~/ sampleRate),
          );
        }
        break;
      }
    }
    return meta;
  }

  static List<Uint8List> _oggPackets(
    Uint8List data, {
    required int maxPackets,
  }) {
    final packets = <Uint8List>[];
    final current = BytesBuilder(copy: false);
    var pos = 0;
    while (pos + 27 <= data.length && packets.length < maxPackets) {
      if (!data.matches(pos, 'OggS')) break;
      final segments = data[pos + 26];
      final tableStart = pos + 27;
      if (tableStart + segments > data.length) break;
      var bodyPos = tableStart + segments;
      for (var s = 0; s < segments; s++) {
        final lacing = data[tableStart + s];
        if (bodyPos + lacing > data.length) return packets;
        current.add(Uint8List.sublistView(data, bodyPos, bodyPos + lacing));
        bodyPos += lacing;
        if (lacing < 255) {
          packets.add(current.takeBytes());
          if (packets.length >= maxPackets) return packets;
        }
      }
      pos = bodyPos;
    }
    return packets;
  }

  // ------------------------------------------------------------------ aac

  Future<AudioMetadata> _aac(ByteSource source) async {
    var start = 0;
    final size = Id3v2Writer.tagSize(await source.read(0, 10));
    var meta = const AudioMetadata();
    if (size > 0) {
      if (size <= maxTagBytes) meta = _parseId3v2(await source.read(0, size));
      start = size;
    }
    if (meta.duration > Duration.zero) return meta;
    // Average frame size over the first 512 KB, extrapolated.
    final window = await source.read(start, 512 * 1024);
    var pos = 0, frames = 0, sampleRate = 0;
    const rates = [
      96000, 88200, 64000, 48000, 44100, 32000, 24000, 22050, 16000, 12000, //
      11025, 8000, 7350,
    ];
    while (pos + 7 <= window.length) {
      if (window[pos] != 0xFF || (window[pos + 1] & 0xF6) != 0xF0) break;
      final rateIndex = (window[pos + 2] >> 2) & 0x0F;
      if (rateIndex >= rates.length) break;
      sampleRate = rates[rateIndex];
      final frameLength =
          ((window[pos + 3] & 0x03) << 11) |
          (window[pos + 4] << 3) |
          (window[pos + 5] >> 5);
      if (frameLength < 7) break;
      pos += frameLength;
      frames++;
    }
    if (frames == 0 || sampleRate == 0 || pos == 0) return meta;
    final totalFrames = (source.length - start) * frames / pos;
    return meta.copyWith(
      duration: Duration(
        microseconds: (totalFrames * 1024 * 1000000 / sampleRate).round(),
      ),
    );
  }

  // ------------------------------------------------------------- fallback

  /// `Artist - Title.mp3` -> (artist, title); a name without ` - ` is the
  /// title alone.
  static ({String artist, String title}) fromFileName(String path) {
    final stem = stemOf(path).trim();
    final split = stem.indexOf(' - ');
    if (split > 0) {
      return (
        artist: stem.substring(0, split).trim(),
        title: stem.substring(split + 3).trim(),
      );
    }
    return (artist: '', title: stem);
  }
}
