import 'dart:convert';
import 'dart:typed_data';

import 'package:amusic/local/byte_source.dart';

/// Synthetic audio files for probe / tagger tests.

/// Fake JPEG (valid magic, arbitrary body).
Uint8List fakeJpeg([int length = 600]) {
  final bytes = Uint8List(length);
  bytes.setAll(0, [0xFF, 0xD8, 0xFF, 0xE0]);
  for (var i = 4; i < length - 2; i++) {
    bytes[i] = (i * 31) & 0xFF;
  }
  bytes[length - 2] = 0xFF;
  bytes[length - 1] = 0xD9;
  return bytes;
}

/// [frames] MPEG-1 Layer III frames, 128 kbps, 44.1 kHz, stereo (417 bytes
/// each, 1152 samples), no padding.
Uint8List mp3Frames(int frames) {
  const frameLength = 417;
  final out = Uint8List(frames * frameLength);
  for (var f = 0; f < frames; f++) {
    final at = f * frameLength;
    out[at] = 0xFF;
    out[at + 1] = 0xFB; // MPEG-1, layer III, no CRC
    out[at + 2] = 0x90; // 128 kbps, 44.1 kHz, no padding
    out[at + 3] = 0x00; // stereo
    for (var i = 4; i < frameLength; i++) {
      out[at + i] = (i * 7 + f) & 0x7F; // never 0xFF: no false syncs
    }
  }
  return out;
}

/// Minimal FLAC: STREAMINFO (+ optional Vorbis comment) + fake frames.
Uint8List flacFile({
  int sampleRate = 44100,
  int totalSamples = 441000,
  Map<String, String> comments = const {},
  bool withId3Prefix = false,
}) {
  final streamInfo = Uint8List(34);
  // min/max block size 4096, frame sizes 0.
  streamInfo.setAll(0, [0x10, 0x00, 0x10, 0x00]);
  // 20 bits rate, 3 bits channels-1 (1 = stereo), 5 bits bps-1 (15), 36 bits
  // total samples.
  final channels = 1;
  final bps = 15;
  streamInfo[10] = (sampleRate >> 12) & 0xFF;
  streamInfo[11] = (sampleRate >> 4) & 0xFF;
  streamInfo[12] = ((sampleRate & 0x0F) << 4) | (channels << 1) | (bps >> 4);
  streamInfo[13] = ((bps & 0x0F) << 4) | ((totalSamples >> 32) & 0x0F);
  streamInfo[14] = (totalSamples >> 24) & 0xFF;
  streamInfo[15] = (totalSamples >> 16) & 0xFF;
  streamInfo[16] = (totalSamples >> 8) & 0xFF;
  streamInfo[17] = totalSamples & 0xFF;

  final blocks = <(int, List<int>)>[(0, streamInfo)];
  if (comments.isNotEmpty) {
    final w = ByteWriter();
    final vendor = utf8.encode('test');
    w
      ..u32le(vendor.length)
      ..bytes(vendor)
      ..u32le(comments.length);
    comments.forEach((key, value) {
      final entry = utf8.encode('$key=$value');
      w
        ..u32le(entry.length)
        ..bytes(entry);
    });
    blocks.add((4, w.take()));
  }
  final out = ByteWriter();
  if (withId3Prefix) {
    out
      ..ascii('ID3')
      ..bytes([3, 0, 0])
      ..syncsafe(16)
      ..bytes(Uint8List(16));
  }
  out.ascii('fLaC');
  for (var i = 0; i < blocks.length; i++) {
    final (type, body) = blocks[i];
    out
      ..byte((i == blocks.length - 1 ? 0x80 : 0) | type)
      ..u24be(body.length)
      ..bytes(body);
  }
  // Fake audio frames (sync code 0xFFF8).
  final frames = Uint8List(2048);
  frames[0] = 0xFF;
  frames[1] = 0xF8;
  for (var i = 2; i < frames.length; i++) {
    frames[i] = (i * 13) & 0xFF;
  }
  out.bytes(frames);
  return out.take();
}

Uint8List _atom(String type, List<int> body) {
  final w = ByteWriter()
    ..u32be(body.length + 8)
    ..ascii(type)
    ..bytes(body);
  return w.take();
}

Uint8List _ilstItem(String name, int dataType, List<int> payload) {
  final data = ByteWriter()
    ..byte(0) // version
    ..u24be(dataType)
    ..u32be(0) // locale
    ..bytes(payload);
  return _atom(name, _atom('data', data.take()));
}

/// Minimal M4A: ftyp + moov(mvhd + udta/meta/ilst) + mdat. [moovLast] puts
/// moov after mdat like many encoders do.
Uint8List m4aFile({
  required String title,
  required String artist,
  required String album,
  int timescale = 44100,
  int duration = 44100 * 125,
  Uint8List? cover,
  bool moovLast = true,
}) {
  final mvhd = ByteWriter()
    ..byte(0)
    ..u24be(0)
    ..u32be(0) // creation
    ..u32be(0) // modification
    ..u32be(timescale)
    ..u32be(duration)
    ..bytes(Uint8List(80));
  final ilst = ByteWriter()
    // Atom names are Latin-1: '\u00A9' is the single byte 0xA9.
    ..bytes(_ilstItem('\u00A9nam', 1, utf8.encode(title)))
    ..bytes(_ilstItem('\u00A9ART', 1, utf8.encode(artist)))
    ..bytes(_ilstItem('\u00A9alb', 1, utf8.encode(album)))
    ..bytes(_ilstItem('trkn', 0, [0, 0, 0, 7, 0, 12, 0, 0]));
  if (cover != null) ilst.bytes(_ilstItem('covr', 13, cover));
  final hdlr = _atom('hdlr', Uint8List(25));
  final meta = _atom('meta', [
    0,
    0,
    0,
    0,
    ...hdlr,
    ..._atom('ilst', ilst.take()),
  ]);
  final moov = _atom('moov', [
    ..._atom('mvhd', mvhd.take()),
    ..._atom('udta', meta),
  ]);
  final ftyp = _atom('ftyp', [
    ...ascii.encode('M4A '),
    0,
    0,
    0,
    0,
    ...ascii.encode('isomM4A '),
  ]);
  final mdat = _atom('mdat', Uint8List(4096));
  return Uint8List.fromList(
    moovLast ? [...ftyp, ...mdat, ...moov] : [...ftyp, ...moov, ...mdat],
  );
}

/// PCM WAV: 44.1 kHz stereo 16 bit, [seconds] long, optional LIST/INFO.
Uint8List wavFile({int seconds = 2, String? title}) {
  const byteRate = 44100 * 4;
  final data = Uint8List(byteRate * seconds);
  final fmt = ByteWriter()
    ..bytes([1, 0, 2, 0]) // PCM, 2 channels
    ..u32le(44100)
    ..u32le(byteRate)
    ..bytes([4, 0, 16, 0]);
  final chunks = ByteWriter()
    ..ascii('WAVE')
    ..ascii('fmt ')
    ..u32le(16)
    ..bytes(fmt.take());
  if (title != null) {
    final name = [...utf8.encode(title), 0];
    if (name.length.isOdd) name.add(0);
    final info = ByteWriter()
      ..ascii('INFO')
      ..ascii('INAM')
      ..u32le(name.length)
      ..bytes(name);
    final body = info.take();
    chunks
      ..ascii('LIST')
      ..u32le(body.length)
      ..bytes(body);
  }
  chunks
    ..ascii('data')
    ..u32le(data.length)
    ..bytes(data);
  final body = chunks.take();
  final out = ByteWriter()
    ..ascii('RIFF')
    ..u32le(body.length)
    ..bytes(body);
  return out.take();
}
