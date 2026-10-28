import 'dart:convert';
import 'dart:typed_data';

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

/// PCM WAV: 44.1 kHz stereo 16 bit, [seconds] long, optional LIST/INFO.
Uint8List wavFile({int seconds = 2, String? title}) {
  const byteRate = 44100 * 4;
  final body = BytesBuilder(copy: false)
    ..add('WAVE'.codeUnits);
  _chunk(body, 'fmt ', [
    ..._u16le(1), // PCM
    ..._u16le(2), // stereo
    ..._u32le(44100),
    ..._u32le(byteRate),
    ..._u16le(4), // block align
    ..._u16le(16), // bits per sample
  ]);
  if (title != null) {
    final name = [...utf8.encode(title), 0];
    if (name.length.isOdd) name.add(0);
    final info = BytesBuilder(copy: false)
      ..add('INFO'.codeUnits);
    _chunk(info, 'INAM', name);
    _chunk(body, 'LIST', info.takeBytes());
  }
  _chunk(body, 'data', Uint8List(byteRate * seconds));
  final payload = body.takeBytes();
  final out = BytesBuilder(copy: false)
    ..add('RIFF'.codeUnits)
    ..add(_u32le(payload.length))
    ..add(payload);
  return out.takeBytes();
}

List<int> _u16le(int v) => [v & 0xFF, (v >> 8) & 0xFF];

List<int> _u32le(int v) =>
    [v & 0xFF, (v >> 8) & 0xFF, (v >> 16) & 0xFF, (v >> 24) & 0xFF];

void _chunk(BytesBuilder out, String id, List<int> payload) {
  out
    ..add(id.codeUnits)
    ..add(_u32le(payload.length))
    ..add(payload);
}
