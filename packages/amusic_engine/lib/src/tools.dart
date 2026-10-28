import 'dart:convert';
import 'dart:ffi';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:ffi/ffi.dart';

import 'bindings.dart';

typedef _BufFreeC = Void Function(Pointer<Uint8>, Size);
typedef _BufFree = void Function(Pointer<Uint8>, int);
typedef _Str2C = Pointer<Uint8> Function(
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Size>,
);
typedef _Str2 = Pointer<Uint8> Function(
  Pointer<Utf8>,
  Pointer<Utf8>,
  Pointer<Size>,
);
typedef _WeapiC = Pointer<Uint8> Function(
  Pointer<Utf8>,
  Pointer<Uint8>,
  Pointer<Size>,
);
typedef _Weapi = Pointer<Uint8> Function(
  Pointer<Utf8>,
  Pointer<Uint8>,
  Pointer<Size>,
);
typedef _BytesC = Pointer<Uint8> Function(Pointer<Uint8>, Size, Pointer<Size>);
typedef _Bytes = Pointer<Uint8> Function(Pointer<Uint8>, int, Pointer<Size>);
typedef _FileC = Pointer<Uint8> Function(Pointer<Utf8>, Pointer<Size>);
typedef _File = Pointer<Uint8> Function(Pointer<Utf8>, Pointer<Size>);
typedef _ProbeBytesC = Pointer<Uint8> Function(
  Pointer<Uint8>,
  Size,
  Pointer<Utf8>,
  Pointer<Size>,
);
typedef _ProbeBytes = Pointer<Uint8> Function(
  Pointer<Uint8>,
  int,
  Pointer<Utf8>,
  Pointer<Size>,
);
typedef _SpectrumC = Pointer<Uint8> Function(
  Pointer<Utf8>,
  Uint32,
  Pointer<Size>,
);
typedef _Spectrum = Pointer<Uint8> Function(Pointer<Utf8>, int, Pointer<Size>);

/// Audio container as reported by the probe; mirrors the Rust `Container`.
enum ProbedContainer { mp3, flac, m4a, ogg, wav, aac, unknown }

/// Tags and duration of one audio file. Empty strings mean "not tagged".
class ProbedAudio {
  const ProbedAudio({
    this.container = ProbedContainer.unknown,
    this.duration = Duration.zero,
    this.trackNumber,
    this.title = '',
    this.artist = '',
    this.album = '',
    this.cover,
    this.replayGainDb,
  });

  final ProbedContainer container;
  final Duration duration;
  final int? trackNumber;
  final String title;
  final String artist;
  final String album;

  /// Encoded picture bytes (JPEG / PNG / ...), if the file embeds one.
  final Uint8List? cover;

  /// `REPLAYGAIN_TRACK_GAIN` in dB, `null` when the file is not tagged.
  final double? replayGainDb;
}

/// Colours of one cover as ARGB ints; `0` means the slot is empty.
class CoverSwatches {
  const CoverSwatches({
    required this.dominant,
    required this.vibrant,
    required this.lightVibrant,
    required this.darkVibrant,
    required this.muted,
    required this.lightMuted,
    required this.darkMuted,
    required this.all,
  });

  final int dominant;
  final int vibrant;
  final int lightVibrant;
  final int darkVibrant;
  final int muted;
  final int lightMuted;
  final int darkMuted;

  /// Every usable swatch, most populous first.
  final List<int> all;
}

/// The engine's stateless helpers: NetEase encryption, cover palettes and tag
/// probing. Plain calls are synchronous; the `*Async` ones run in a helper
/// isolate so a slow file never holds a frame.
class AmusicTools {
  AmusicTools._(DynamicLibrary lib)
    : _free = lib.lookupFunction<_BufFreeC, _BufFree>('amusic_buffer_free'),
      _eapi = lib.lookupFunction<_Str2C, _Str2>('amusic_netease_eapi'),
      _weapi = lib.lookupFunction<_WeapiC, _Weapi>('amusic_netease_weapi'),
      _palette = lib.lookupFunction<_BytesC, _Bytes>('amusic_cover_palette'),
      _probeFile = lib.lookupFunction<_FileC, _File>('amusic_probe_file'),
      _probeBytes = lib.lookupFunction<_ProbeBytesC, _ProbeBytes>(
        'amusic_probe_bytes',
      ),
      _spectrum = lib.lookupFunction<_SpectrumC, _Spectrum>(
        'amusic_spectrum_file',
      );

  final _BufFree _free;
  final _Str2 _eapi;
  final _Weapi _weapi;
  final _Bytes _palette;
  final _File _probeFile;
  final _ProbeBytes _probeBytes;
  final _Spectrum _spectrum;

  static AmusicTools? _shared;

  /// The instance of the current isolate.
  static AmusicTools get instance => _shared ??= AmusicTools._(
    AmusicNative.libraryPathOverride != null
        ? DynamicLibrary.open(AmusicNative.libraryPathOverride!)
        : AmusicNative.openDefault(),
  );

  /// Runs [task] with the helpers inside a short lived isolate.
  static Future<T> run<T>(T Function(AmusicTools tools) task) {
    final path = AmusicNative.libraryPathOverride;
    return Isolate.run(() {
      if (path != null) AmusicNative.overrideLibrary(path);
      return task(instance);
    });
  }

  Uint8List? _take(Pointer<Uint8> ptr, Pointer<Size> len) {
    if (ptr == nullptr) return null;
    final bytes = Uint8List.fromList(ptr.asTypedList(len.value));
    _free(ptr, len.value);
    return bytes;
  }

  // ------------------------------------------------------------- netease

  /// `eapi` payload (upper case hex) for [json] sent to [uri].
  String eapi(String uri, String json) => using((arena) {
    final len = arena<Size>();
    final out = _take(
      _eapi(
        uri.toNativeUtf8(allocator: arena),
        json.toNativeUtf8(allocator: arena),
        len,
      ),
      len,
    );
    if (out == null) throw StateError('eapi failed');
    return utf8.decode(out);
  });

  /// `weapi` payload for [json] under the 16 byte [secret].
  ({String params, String encSecKey}) weapi(String json, Uint8List secret) {
    assert(secret.length == 16);
    return using((arena) {
      final key = arena<Uint8>(16)..asTypedList(16).setAll(0, secret);
      final len = arena<Size>();
      final out = _take(
        _weapi(json.toNativeUtf8(allocator: arena), key, len),
        len,
      );
      if (out == null) throw StateError('weapi failed');
      final parts = utf8.decode(out).split('\n');
      return (params: parts[0], encSecKey: parts[1]);
    });
  }

  // --------------------------------------------------------------- cover

  /// Palette of an encoded picture, `null` if it cannot be decoded.
  CoverSwatches? coverPalette(Uint8List image) => using((arena) {
    final data = arena<Uint8>(image.length)
      ..asTypedList(image.length).setAll(0, image);
    final len = arena<Size>();
    final out = _take(_palette(data, image.length, len), len);
    if (out == null) return null;
    final view = ByteData.sublistView(out);
    int at(int i) => view.getUint32(i * 4, Endian.little);
    final count = at(7);
    return CoverSwatches(
      dominant: at(0),
      vibrant: at(1),
      lightVibrant: at(2),
      darkVibrant: at(3),
      muted: at(4),
      lightMuted: at(5),
      darkMuted: at(6),
      all: [for (var i = 0; i < count; i++) at(8 + i)],
    );
  });

  static Future<CoverSwatches?> coverPaletteAsync(Uint8List image) =>
      run((t) => t.coverPalette(image));

  // --------------------------------------------------------------- probe

  /// Tags of the file at [path]; unreadable files give empty metadata.
  ProbedAudio probeFile(String path) => using((arena) {
    final len = arena<Size>();
    return _decodeProbe(
      _take(_probeFile(path.toNativeUtf8(allocator: arena), len), len),
    );
  });

  /// Tags of an in-memory file; [extension] (no dot) hints the format.
  ProbedAudio probeBytes(Uint8List data, {String extension = ''}) =>
      using((arena) {
        final buf = arena<Uint8>(data.length == 0 ? 1 : data.length)
          ..asTypedList(data.length).setAll(0, data);
        final len = arena<Size>();
        return _decodeProbe(
          _take(
            _probeBytes(
              buf,
              data.length,
              extension.toNativeUtf8(allocator: arena),
              len,
            ),
            len,
          ),
        );
      });

  static Future<ProbedAudio> probeFileAsync(String path) =>
      run((t) => t.probeFile(path));

  static ProbedAudio _decodeProbe(Uint8List? raw) {
    if (raw == null) return const ProbedAudio();
    final view = ByteData.sublistView(raw);
    var at = 0;
    final container = ProbedContainer
        .values[raw[at].clamp(0, ProbedContainer.values.length - 1)];
    at += 1;
    final micros = view.getInt64(at, Endian.little);
    at += 8;
    final track = view.getInt32(at, Endian.little);
    at += 4;
    final gain = view.getFloat32(at, Endian.little);
    at += 4;
    String readString() {
      final n = view.getUint32(at, Endian.little);
      at += 4;
      final s = utf8.decode(raw.sublist(at, at + n), allowMalformed: true);
      at += n;
      return s;
    }

    final title = readString();
    final artist = readString();
    final album = readString();
    final coverLength = view.getUint32(at, Endian.little);
    at += 4;
    return ProbedAudio(
      container: container,
      duration: Duration(microseconds: micros),
      trackNumber: track > 0 ? track : null,
      title: title,
      artist: artist,
      album: album,
      cover: coverLength == 0
          ? null
          : Uint8List.fromList(raw.sublist(at, at + coverLength)),
      // Rust sends NaN for "not tagged".
      replayGainDb: gain.isNaN ? null : gain.toDouble(),
    );
  }

  // ------------------------------------------------------------ spectrum

  /// Timeline spectrum envelope for a local path or supported URL.
  /// Values are normalised bytes so the UI can paint them without decoding
  /// audio data or doing DSP on the Flutter isolate.
  Uint8List? spectrumFile(String path, {int bands = 96}) => using((arena) {
    final len = arena<Size>();
    final out = _take(
      _spectrum(
        path.toNativeUtf8(allocator: arena),
        bands.clamp(1, 255).toInt(),
        len,
      ),
      len,
    );
    return out;
  });

  /// Runs [spectrumFile] in a helper isolate backed by the Rust decoder.
  static Future<Uint8List?> spectrumFileAsync(String path, {int bands = 96}) =>
      run((t) => t.spectrumFile(path, bands: bands));
}
