import 'dart:async';
import 'dart:io';

import 'audio_probe.dart';
import 'file_names.dart';
import 'local_track.dart';
import 'tags/tag_data.dart';

/// Progress of a running scan.
class ScanProgress {
  const ScanProgress({this.found = 0, this.probed = 0, this.current});

  /// Audio files seen so far.
  final int found;

  /// Files whose tags were (re)read (new or changed ones).
  final int probed;

  /// File being looked at.
  final String? current;
}

/// Outcome of a scan.
class ScanResult {
  const ScanResult({
    required this.tracks,
    this.unreadableRoots = const [],
    this.truncated = false,
    this.canceled = false,
  });

  final List<LocalTrack> tracks;

  /// Roots that could not be listed (missing / no permission).
  final List<String> unreadableRoots;

  /// Stopped at [LocalScanner.maxFiles].
  final bool truncated;
  final bool canceled;
}

/// Walks folders for audio files and probes their tags.
///
/// Unchanged files (same size and modification time as in [previous]) reuse
/// their old entry, so a rescan only reads new or edited files.
class LocalScanner {
  LocalScanner({AudioProbe? probe}) : probe = probe ?? const AudioProbe();

  final AudioProbe probe;

  static const Set<String> extensions = {
    'mp3',
    'flac',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wav',
  };

  /// Folder levels below a root that are scanned.
  static const int maxDepth = 8;
  static const int maxFiles = 5000;

  /// Directory names never descended into (besides hidden ones).
  static const Set<String> _skippedDirs = {
    r'$recycle.bin',
    'system volume information',
    '@eadir',
    'node_modules',
    'android', // Android/data, Android/obb
    'library', // macOS ~/Library inside a picked home folder
    'appdata',
    'windows',
    'program files',
    'program files (x86)',
    'lost+found',
  };

  static bool isAudioPath(String path) =>
      extensions.contains(extensionOf(path));

  static bool _skipDir(String name) =>
      name.startsWith('.') || _skippedDirs.contains(name.toLowerCase());

  /// Scans [roots]. [saveCover] stores an extracted picture and returns its
  /// path. Files listed in [excluded] (path keys) are ignored.
  Future<ScanResult> scan(
    List<String> roots, {
    Map<String, LocalTrack> previous = const {},
    Set<String> excluded = const {},
    Future<String?> Function(String path, TagPicture picture)? saveCover,
    void Function(ScanProgress progress)? onProgress,
    bool Function()? isCanceled,
  }) async {
    final found = <String, LocalTrack>{};
    final unreadable = <String>[];
    var visited = 0;
    var probed = 0;
    var truncated = false;
    var canceled = false;
    final now = DateTime.now();

    for (final root in roots) {
      final pending = <(Directory, int)>[(Directory(root), 0)];
      var rootReadable = true;
      while (pending.isNotEmpty) {
        if (isCanceled?.call() ?? false) {
          canceled = true;
          break;
        }
        final (directory, depth) = pending.removeLast();
        List<FileSystemEntity> entities;
        try {
          entities = await directory.list(followLinks: false).toList();
        } on FileSystemException {
          if (depth == 0) rootReadable = false;
          continue;
        }
        for (final entity in entities) {
          if (isCanceled?.call() ?? false) {
            canceled = true;
            break;
          }
          final name = baseName(entity.path);
          if (entity is Directory || entity is Link) {
            var dir = entity;
            if (entity is Link) {
              // Follow links to directories only at the root level (macOS
              // sandbox exposes ~/Music as a link).
              if (depth > 0) continue;
              try {
                final target = await entity.resolveSymbolicLinks();
                if (!await FileSystemEntity.isDirectory(target)) continue;
                dir = Directory(target);
              } on FileSystemException {
                continue;
              }
            }
            if (!_skipDir(name) && depth + 1 <= maxDepth) {
              pending.add((dir as Directory, depth + 1));
            }
            continue;
          }
          if (entity is! File || name.startsWith('.')) continue;
          if (!isAudioPath(entity.path)) continue;
          final key = pathKey(entity.path);
          if (found.containsKey(key) || excluded.contains(key)) continue;
          if (found.length >= maxFiles) {
            truncated = true;
            break;
          }
          visited++;
          try {
            final stat = await entity.stat();
            final old = previous[key];
            LocalTrack track;
            if (old != null &&
                old.size == stat.size &&
                old.modified.millisecondsSinceEpoch ==
                    stat.modified.millisecondsSinceEpoch) {
              track = old;
            } else {
              probed++;
              track = await probeTrack(
                entity.path,
                stat,
                added: old?.added ?? now,
                source: old?.source ?? LocalTrackSource.scan,
                saveCover: saveCover,
              );
            }
            found[key] = track;
          } on FileSystemException {
            // Vanished or unreadable file: skip.
          }
          if (visited % 20 == 0) {
            onProgress?.call(
              ScanProgress(
                found: found.length,
                probed: probed,
                current: entity.path,
              ),
            );
            // Yield so the scan never holds a frame for long.
            await Future<void>.delayed(Duration.zero);
          }
        }
        if (canceled || truncated) break;
      }
      if (!rootReadable) unreadable.add(root);
      if (canceled || truncated) break;
    }
    onProgress?.call(ScanProgress(found: found.length, probed: probed));
    return ScanResult(
      tracks: found.values.toList(),
      unreadableRoots: unreadable,
      truncated: truncated,
      canceled: canceled,
    );
  }

  /// Reads one file into a [LocalTrack].
  Future<LocalTrack> probeTrack(
    String path,
    FileStat stat, {
    required DateTime added,
    LocalTrackSource source = LocalTrackSource.scan,
    Future<String?> Function(String path, TagPicture picture)? saveCover,
  }) async {
    final meta = await probe.probeFile(path);
    final fallback = AudioProbe.fromFileName(path);
    final title = meta.title.isNotEmpty ? meta.title : fallback.title;
    final artist = meta.artist.isNotEmpty
        ? meta.artist
        : (fallback.artist.isNotEmpty
              ? fallback.artist
              : LocalTrack.unknownArtist);
    String? coverPath;
    final cover = meta.cover;
    if (cover != null && saveCover != null) {
      coverPath = await saveCover(path, cover);
    }
    return LocalTrack(
      path: path,
      title: title,
      artist: artist,
      album: meta.album.isNotEmpty ? meta.album : LocalTrack.unknownAlbum,
      duration: meta.duration,
      size: stat.size,
      modified: stat.modified,
      added: added,
      trackNumber: meta.trackNumber,
      coverPath: coverPath,
      source: source,
      format: extensionOf(path),
    );
  }
}
