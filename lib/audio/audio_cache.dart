import 'dart:async';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

/// A fully downloaded stream on disk.
class CachedAudio {
  const CachedAudio({
    required this.file,
    required this.length,
    this.level,
    this.contentType,
  });

  final File file;
  final int length;

  /// Quality the server granted when the file was fetched.
  final String? level;
  final String? contentType;
}

/// Whole-file audio cache with LRU trimming.
///
/// Streams are only cached when one response covered the complete file
/// (Android / desktop players read sequentially, so this is the normal case).
/// AVPlayer's sparse range reads are not cached: stitching partial ranges
/// together is not worth the complexity for a cache. Files are named
/// `<key>.audio` with a `<key>.meta` sidecar (`level\ncontentType`); the
/// file's modification time is its last use.
class AudioCache {
  AudioCache({required this.maxBytes, Future<Directory> Function()? directory})
    : _directory = directory ?? _defaultDirectory;

  /// Upper bound, read on every trim so a settings change applies on the
  /// next write. `0` disables caching.
  int Function() maxBytes;

  final Future<Directory> Function() _directory;
  Directory? _resolved;

  static Future<Directory> _defaultDirectory() async {
    final base = await getApplicationCacheDirectory();
    return Directory('${base.path}${Platform.pathSeparator}audio');
  }

  Future<Directory> _dir() async {
    final dir = _resolved ??= await _directory();
    if (!await dir.exists()) await dir.create(recursive: true);
    return dir;
  }

  bool get enabled => maxBytes() > 0;

  String _path(Directory dir, String key, String extension) =>
      '${dir.path}${Platform.pathSeparator}${_safe(key)}.$extension';

  static String _safe(String key) => key.replaceAll(RegExp(r'[^\w\-]'), '_');

  /// The cached file for [key], refreshing its LRU timestamp.
  Future<CachedAudio?> lookup(String key) async {
    if (!enabled) return null;
    try {
      final dir = await _dir();
      final file = File(_path(dir, key, 'audio'));
      if (!await file.exists()) return null;
      final length = await file.length();
      if (length <= 0) return null;
      String? level;
      String? contentType;
      final meta = File(_path(dir, key, 'meta'));
      if (await meta.exists()) {
        final lines = (await meta.readAsString()).split('\n');
        level = lines.isNotEmpty && lines[0].isNotEmpty ? lines[0] : null;
        contentType = lines.length > 1 && lines[1].isNotEmpty ? lines[1] : null;
      }
      unawaited(file.setLastModified(DateTime.now()).catchError((Object _) {}));
      return CachedAudio(
        file: file,
        length: length,
        level: level,
        contentType: contentType,
      );
    } on FileSystemException {
      return null;
    }
  }

  /// Starts writing [key]. Commit with [AudioCacheWriter.commit] once every
  /// byte of [expectedLength] arrived; anything else discards the part file.
  Future<AudioCacheWriter?> openWriter(
    String key, {
    required int expectedLength,
    String? level,
    String? contentType,
  }) async {
    final limit = maxBytes();
    // A file larger than half the cache would evict everything else.
    if (limit <= 0 || expectedLength <= 0 || expectedLength > limit ~/ 2) {
      return null;
    }
    try {
      final dir = await _dir();
      final stamp = DateTime.now().microsecondsSinceEpoch;
      final part = File('${_path(dir, key, 'audio')}.$stamp.part');
      return AudioCacheWriter._(
        cache: this,
        part: part,
        sink: part.openWrite(),
        target: File(_path(dir, key, 'audio')),
        meta: File(_path(dir, key, 'meta')),
        expectedLength: expectedLength,
        metaText: '${level ?? ''}\n${contentType ?? ''}',
      );
    } on FileSystemException {
      return null;
    }
  }

  /// Bytes used on disk (finished files plus in-flight parts).
  Future<int> size() async {
    try {
      final dir = await _dir();
      var total = 0;
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is File) total += await entity.length();
      }
      return total;
    } on FileSystemException {
      return 0;
    }
  }

  Future<void> clear() async {
    try {
      final dir = await _dir();
      await for (final entity in dir.list(followLinks: false)) {
        try {
          await entity.delete();
        } on FileSystemException {
          // In use by a running download; it is discarded on its own.
        }
      }
    } on FileSystemException {
      // Nothing cached.
    }
  }

  /// Deletes the least recently used files until the cache fits.
  Future<void> trim() async {
    final limit = maxBytes();
    try {
      final dir = await _dir();
      final files = <(File, int, DateTime)>[];
      var total = 0;
      final staleBefore = DateTime.now().subtract(const Duration(hours: 1));
      await for (final entity in dir.list(followLinks: false)) {
        if (entity is! File) continue;
        if (entity.path.endsWith('.part')) {
          // Left behind by a stream that was killed mid-write; live writers
          // touch their file continuously, so an hour-old one is orphaned.
          final stat = await entity.stat();
          if (stat.modified.isBefore(staleBefore)) {
            try {
              await entity.delete();
            } on FileSystemException {
              // Still open somewhere; next trim.
            }
          }
          continue;
        }
        if (!entity.path.endsWith('.audio')) continue;
        final stat = await entity.stat();
        files.add((entity, stat.size, stat.modified));
        total += stat.size;
      }
      if (total <= limit) return;
      files.sort((a, b) => a.$3.compareTo(b.$3));
      for (final (file, size, _) in files) {
        if (total <= limit) break;
        try {
          await file.delete();
          final meta = File(
            '${file.path.substring(0, file.path.length - 6)}.meta',
          );
          if (await meta.exists()) await meta.delete();
          total -= size;
        } on FileSystemException {
          // Being read right now; try the next one.
        }
      }
    } on FileSystemException {
      // Directory vanished.
    }
  }
}

/// Write side of one cache entry.
class AudioCacheWriter {
  AudioCacheWriter._({
    required this._cache,
    required this._part,
    required this._sink,
    required this._target,
    required this._meta,
    required this.expectedLength,
    required this._metaText,
  });

  final AudioCache _cache;
  final File _part;
  final IOSink _sink;
  final File _target;
  final File _meta;
  final String _metaText;
  final int expectedLength;
  int _written = 0;
  bool _done = false;

  void add(List<int> chunk) {
    if (_done) return;
    _written += chunk.length;
    _sink.add(chunk);
  }

  /// Keeps the file when it is complete, otherwise discards it.
  Future<void> commit() async {
    if (_done) return;
    _done = true;
    try {
      await _sink.close();
      if (_written != expectedLength) {
        await _part.delete();
        return;
      }
      await _part.rename(_target.path);
      await _meta.writeAsString(_metaText);
      await _cache.trim();
    } on FileSystemException {
      await _deleteQuietly();
    }
  }

  Future<void> abort() async {
    if (_done) return;
    _done = true;
    try {
      await _sink.close();
    } on Object {
      // Already broken.
    }
    await _deleteQuietly();
  }

  Future<void> _deleteQuietly() async {
    try {
      if (await _part.exists()) await _part.delete();
    } on FileSystemException {
      // Ignore.
    }
  }
}
