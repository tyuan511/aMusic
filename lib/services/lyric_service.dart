import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';

import '../core/async_cache.dart';
import '../core/errors.dart';
import '../models/lyric.dart';
import 'api_host.dart';
import 'local_library_service.dart';

/// Parsed lyrics, cached per song so that scrubbing back to a previous track
/// does not hit the network again.
///
/// A user imported `.lrc` (stored as `<app support>/lyrics/<songId>.lrc`)
/// overrides the cloud lyric until it is removed. Local songs also pick up a
/// sidecar `.lrc` next to the audio file.
class LyricService {
  LyricService(
    this._host, {
    Future<Directory> Function()? storageDirectory,
    this.localPathFor,
  }) : _storageDirectory = storageDirectory ?? _defaultDirectory;

  final ApiHost _host;
  final Future<Directory> Function() _storageDirectory;

  /// Resolves the audio file of a local song (negative id), for sidecar
  /// `.lrc` lookup. Assigned by the player so the composition root does not
  /// need to know.
  String? Function(int songId)? localPathFor;

  final AsyncCache<int, Lyric> _cache = AsyncCache(
    ttl: const Duration(hours: 6),
    maxEntries: 80,
  );

  /// Bumped whenever a lyric is imported or removed; views keyed on it
  /// reload.
  final ValueNotifier<int> revision = ValueNotifier(0);

  static Future<Directory> _defaultDirectory() async {
    final support = await getApplicationSupportDirectory();
    return Directory('${support.path}${Platform.pathSeparator}lyrics');
  }

  Future<File> _importFile(int songId) async {
    final directory = await _storageDirectory();
    return File('${directory.path}${Platform.pathSeparator}$songId.lrc');
  }

  Future<Lyric> load(int songId) => _cache.get(songId, () async {
    final imported = await _readImported(songId);
    if (imported != null) return imported;
    if (LocalLibraryService.isLocalId(songId)) return _readSidecar(songId);
    try {
      return Lyric.fromPayload(await _host.api.lyricPayload(songId));
    } on AppException {
      return Lyric.empty;
    }
  });

  Lyric? peek(int songId) => _cache.peek(songId);

  /// Fire and forget, used to warm the cache for the upcoming track.
  void preload(int? songId) {
    if (songId == null) return;
    unawaited(load(songId).then((_) {}, onError: (Object _) {}));
  }

  void clear() => _cache.clear();

  // -------------------------------------------------------------- imports

  /// Whether [songId] currently uses an imported lyric.
  Future<bool> hasImported(int songId) async =>
      (await _importFile(songId)).exists();

  /// Stores [bytes] (an `.lrc` file, UTF-8 or UTF-16 with BOM) as the lyric
  /// of [songId]. Throws [FormatException] when it contains no timed line.
  Future<Lyric> importLrc(int songId, List<int> bytes) async {
    final text = decodeLyricBytes(bytes);
    final lyric = Lyric.parse(lrc: text).copyWith(imported: true);
    if (lyric.isEmpty) {
      throw const FormatException('文件里没有带时间轴的歌词');
    }
    final file = await _importFile(songId);
    await file.parent.create(recursive: true);
    await file.writeAsString(text, flush: true);
    _cache.invalidate(songId);
    revision.value++;
    return lyric;
  }

  /// Drops the imported lyric of [songId]; the cloud lyric comes back.
  Future<void> removeImported(int songId) async {
    final file = await _importFile(songId);
    if (await file.exists()) await file.delete();
    _cache.invalidate(songId);
    revision.value++;
  }

  Future<Lyric?> _readImported(int songId) async {
    try {
      final file = await _importFile(songId);
      if (!await file.exists()) return null;
      final lyric = Lyric.parse(lrc: await file.readAsString());
      return lyric.isEmpty ? null : lyric.copyWith(imported: true);
    } on Object {
      return null;
    }
  }

  Future<Lyric> _readSidecar(int songId) async {
    final path = localPathFor?.call(songId);
    if (path == null) return Lyric.empty;
    final dot = path.lastIndexOf('.');
    final base = dot > 0 ? path.substring(0, dot) : path;
    final file = File('$base.lrc');
    try {
      if (!await file.exists()) return Lyric.empty;
      return Lyric.parse(lrc: decodeLyricBytes(await file.readAsBytes()));
    } on Object {
      return Lyric.empty;
    }
  }
}

/// Decodes a lyric file: UTF-8 (with or without BOM) or UTF-16 LE / BE with
/// BOM. Invalid UTF-8 is decoded leniently instead of failing.
String decodeLyricBytes(List<int> bytes) {
  if (bytes.length >= 2) {
    if (bytes[0] == 0xFF && bytes[1] == 0xFE) {
      return _utf16(bytes.sublist(2), littleEndian: true);
    }
    if (bytes[0] == 0xFE && bytes[1] == 0xFF) {
      return _utf16(bytes.sublist(2), littleEndian: false);
    }
  }
  final body =
      bytes.length >= 3 &&
          bytes[0] == 0xEF &&
          bytes[1] == 0xBB &&
          bytes[2] == 0xBF
      ? bytes.sublist(3)
      : bytes;
  return utf8.decode(body, allowMalformed: true);
}

String _utf16(List<int> bytes, {required bool littleEndian}) {
  final units = <int>[];
  for (var i = 0; i + 1 < bytes.length; i += 2) {
    units.add(
      littleEndian
          ? bytes[i] | (bytes[i + 1] << 8)
          : (bytes[i] << 8) | bytes[i + 1],
    );
  }
  return String.fromCharCodes(units);
}
