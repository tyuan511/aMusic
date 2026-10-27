import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:crypto/crypto.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:path_provider/path_provider.dart';

import '../../core/config.dart';

/// Image provider for NetEase CDN pictures.
///
/// Decoded frames are cached by Flutter's own [ImageCache]; encoded bytes are
/// cached on disk. Rolling our own keeps the dependency count low and avoids
/// sandbox problems some cache managers hit on macOS.
@immutable
class NetImage extends ImageProvider<NetImage> {
  const NetImage(this.url, {this.referer = 'https://music.163.com'});

  final String url;
  final String referer;

  @override
  Future<NetImage> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<NetImage>(this);

  @override
  ImageStreamCompleter loadImage(NetImage key, ImageDecoderCallback decode) {
    return MultiFrameImageStreamCompleter(
      codec: _load(key, decode),
      scale: 1,
      debugLabel: key.url,
    );
  }

  Future<ui.Codec> _load(NetImage key, ImageDecoderCallback decode) async {
    try {
      final bytes = await ImageByteCache.instance.load(
        key.url,
        referer: referer,
      );
      if (bytes.isEmpty) {
        throw StateError('empty image: ${key.url}');
      }
      final buffer = await ui.ImmutableBuffer.fromUint8List(bytes);
      return await decode(buffer);
    } on Object catch (error, stack) {
      debugPrint('image load failed: ${key.url} -> $error');
      debugPrintStack(stackTrace: stack, maxFrames: 6);
      rethrow;
    }
  }

  @override
  bool operator ==(Object other) => other is NetImage && other.url == url;

  @override
  int get hashCode => url.hashCode;

  @override
  String toString() => 'NetImage($url)';
}

/// Byte level cache: memory (bounded) in front of the app cache directory.
class ImageByteCache {
  ImageByteCache._();

  static final ImageByteCache instance = ImageByteCache._();

  /// ~48 MB of encoded bytes across all sizes.
  static const int _maxMemoryBytes = 48 * 1024 * 1024;

  final Map<String, Uint8List> _memory = {};
  int _memoryBytes = 0;

  final Map<String, Future<Uint8List>> _inFlight = {};

  static const Duration _downloadTimeout = Duration(seconds: 20);

  final HttpClient _client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 12)
    ..autoUncompress = true
    ..maxConnectionsPerHost = 8;

  Directory? _directory;

  Future<Uint8List> load(String url, {required String referer}) {
    final cached = _memory[url];
    if (cached != null) {
      // Refresh LRU position.
      _memory.remove(url);
      _memory[url] = cached;
      return Future.value(cached);
    }
    final running = _inFlight[url];
    if (running != null) return running;
    // Block body on purpose: `remove` returns this very future, and
    // `whenComplete` awaits any future its callback returns, so an expression
    // body would make the future wait on itself and never complete.
    final future = _load(url, referer).whenComplete(() {
      _inFlight.remove(url);
    });
    _inFlight[url] = future;
    return future;
  }

  Future<Uint8List> _load(String url, String referer) async {
    final file = await _fileFor(url);
    if (file != null && await file.exists()) {
      try {
        final bytes = await file.readAsBytes();
        if (bytes.isNotEmpty) {
          _put(url, bytes);
          return bytes;
        }
      } on FileSystemException {
        // Fall through to the network.
      }
    }

    // Bounded as a whole: a CDN connection that stalls mid-body would
    // otherwise keep this cover (and its in-flight entry) pending forever.
    final bytes = await _download(url, referer).timeout(_downloadTimeout);
    _put(url, bytes);
    if (file != null) {
      unawaited(
        file.writeAsBytes(bytes, flush: false).catchError((Object _) => file),
      );
    }
    return bytes;
  }

  Future<Uint8List> _download(String url, String referer) async {
    final request = await _client.getUrl(Uri.parse(url));
    request.headers
      ..set(HttpHeaders.userAgentHeader, AppConfig.userAgent)
      ..set(HttpHeaders.refererHeader, referer);
    final response = await request.close();
    if (response.statusCode != HttpStatus.ok) {
      await response.drain<void>();
      throw StateError('image http ${response.statusCode}: $url');
    }
    final builder = BytesBuilder(copy: false);
    await for (final chunk in response) {
      builder.add(chunk);
    }
    return builder.takeBytes();
  }

  Future<File?> _fileFor(String url) async {
    if (_directory == null) {
      try {
        final base = await getApplicationCacheDirectory();
        final dir = Directory('${base.path}/images');
        if (!dir.existsSync()) dir.createSync(recursive: true);
        _directory = dir;
      } on Object {
        return null;
      }
    }
    final dir = _directory;
    if (dir == null) return null;
    final name = md5.convert(utf8.encode(url)).toString();
    return File('${dir.path}/$name');
  }

  void _put(String url, Uint8List bytes) {
    final previous = _memory.remove(url);
    if (previous != null) _memoryBytes -= previous.length;
    _memory[url] = bytes;
    _memoryBytes += bytes.length;
    while (_memoryBytes > _maxMemoryBytes && _memory.isNotEmpty) {
      final oldest = _memory.keys.first;
      final removed = _memory.remove(oldest);
      if (removed != null) _memoryBytes -= removed.length;
    }
  }

  /// Drops both caches (used by "clear cache" in settings).
  Future<void> clear() async {
    _memory.clear();
    _memoryBytes = 0;
    final dir = _directory;
    if (dir != null && dir.existsSync()) {
      await dir.delete(recursive: true);
      _directory = null;
    }
  }
}
