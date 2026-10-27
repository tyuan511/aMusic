import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../data/ncm_api.dart';
import '../local/file_names.dart';
import '../local/reveal.dart';
import '../local/tags/tag_data.dart';
import '../local/tags/tag_writer.dart';
import '../models/song.dart';
import 'api_host.dart';
import 'settings_service.dart';

/// Lifecycle of a [DownloadTask].
enum DownloadStatus {
  queued('等待中'),
  downloading('下载中'),
  failed('失败'),
  canceled('已取消'),
  done('已完成');

  const DownloadStatus(this.label);

  final String label;

  static DownloadStatus fromName(String? name) => DownloadStatus.values
      .firstWhere((s) => s.name == name, orElse: () => DownloadStatus.queued);
}

/// One queued / running / failed download. Mutable on purpose: progress
/// changes many times a second and the UI reads it through the service.
class DownloadTask {
  DownloadTask({
    required this.song,
    this.folder,
    this.status = DownloadStatus.queued,
    this.received = 0,
    this.total = 0,
    this.partPath,
    this.level,
    this.downgraded = false,
    this.error,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  final Song song;

  /// Optional sub folder (album / playlist name), already sanitized.
  final String? folder;
  DownloadStatus status;
  int received;

  /// Expected size in bytes, 0 while unknown.
  int total;

  /// `<target>.part` of the current attempt (kept for resuming).
  String? partPath;

  /// Granted quality of the current attempt.
  AudioLevel? level;

  /// Granted quality is lower than the requested one.
  bool downgraded;
  String? error;
  final DateTime createdAt;

  int get songId => song.id;

  /// 0 - 1, `null` while the size is unknown.
  double? get fraction => total > 0 ? (received / total).clamp(0.0, 1.0) : null;

  bool get isActive =>
      status == DownloadStatus.queued || status == DownloadStatus.downloading;

  Map<String, dynamic> toJson() => {
    'song': song.toJson(),
    if (folder != null) 'folder': folder,
    // A running download resumes as queued after a restart.
    'status': status == DownloadStatus.downloading
        ? DownloadStatus.queued.name
        : status.name,
    'received': received,
    'total': total,
    if (partPath != null) 'part': partPath,
    if (level != null) 'level': level!.value,
    'downgraded': downgraded,
    if (error != null) 'error': error,
    'created': createdAt.millisecondsSinceEpoch,
  };

  static DownloadTask? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final song = raw['song'];
    if (song is! Map<String, dynamic>) return null;
    final level = raw['level'] as String?;
    var status = DownloadStatus.fromName(raw['status'] as String?);
    // Nothing runs before init: an interrupted download resumes as queued.
    if (status == DownloadStatus.downloading) status = DownloadStatus.queued;
    return DownloadTask(
      song: Song.fromJson(song),
      folder: raw['folder'] as String?,
      status: status,
      received: (raw['received'] as num?)?.toInt() ?? 0,
      total: (raw['total'] as num?)?.toInt() ?? 0,
      partPath: raw['part'] as String?,
      level: level == null ? null : AudioLevel.fromValue(level),
      downgraded: raw['downgraded'] as bool? ?? false,
      error: raw['error'] as String?,
      createdAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['created'] as num?)?.toInt() ?? 0,
      ),
    );
  }
}

/// A finished download (persisted in `dl.done`).
class DownloadRecord {
  const DownloadRecord({
    required this.song,
    required this.path,
    required this.size,
    required this.finishedAt,
    this.level,
    this.downgraded = false,
    this.tagged = false,
  });

  final Song song;
  final String path;
  final int size;
  final DateTime finishedAt;
  final AudioLevel? level;
  final bool downgraded;

  /// Tags (title / artist / cover...) were embedded.
  final bool tagged;

  Map<String, dynamic> toJson() => {
    'path': path,
    'song': song.toJson(),
    'size': size,
    'finished': finishedAt.millisecondsSinceEpoch,
    if (level != null) 'level': level!.value,
    'downgraded': downgraded,
    'tagged': tagged,
  };

  static DownloadRecord? fromJson(Object? raw) {
    if (raw is! Map<String, dynamic>) return null;
    final path = raw['path'];
    final song = raw['song'];
    if (path is! String || song is! Map<String, dynamic>) return null;
    final level = raw['level'] as String?;
    return DownloadRecord(
      song: Song.fromJson(song),
      path: path,
      size: (raw['size'] as num?)?.toInt() ?? 0,
      finishedAt: DateTime.fromMillisecondsSinceEpoch(
        (raw['finished'] as num?)?.toInt() ?? 0,
      ),
      level: level == null ? null : AudioLevel.fromValue(level),
      downgraded: raw['downgraded'] as bool? ?? false,
      tagged: raw['tagged'] as bool? ?? false,
    );
  }
}

/// The download folder cannot be created or written.
class DownloadDirectoryException implements Exception {
  const DownloadDirectoryException(this.path, this.reason);

  final String path;
  final String reason;

  @override
  String toString() => '下载目录不可写：$path（$reason）';
}

/// Resolved stream for a download.
typedef DownloadSource = ({
  String url,
  AudioLevel level,
  String? type,
  int? size,
  bool trial,
});

/// Downloads tracks to disk.
///
/// * Queue (`dl.tasks`) and finished index (`dl.done`: song id -> path +
///   song) are persisted and survive restarts; finished files are verified
///   on [init].
/// * Two downloads run at a time. Each writes `<target>.part`, resumes it
///   with a `Range` request when it already exists, checks the length and
///   renames atomically.
/// * mp3 files get ID3v2.3 tags (title / artist / album / track / cover /
///   lyrics), FLAC files Vorbis comments + PICTURE.
/// * Listeners are notified at most ~10 times a second while bytes flow.
class DownloadService extends ChangeNotifier {
  DownloadService({
    required this._host,
    required this._settings,
    required this._prefs,
    @visibleForTesting
    Future<DownloadSource> Function(Song song, AudioLevel level)? resolveSource,
    @visibleForTesting Future<String?> Function(int songId)? fetchLyrics,
    @visibleForTesting Future<Directory> Function()? defaultDirectory,
    @visibleForTesting this.autoStart = true,
  }) : _resolveOverride = resolveSource,
       _lyricsOverride = fetchLyrics,
       _defaultDirectoryOverride = defaultDirectory;

  final ApiHost _host;
  final SettingsService _settings;
  final SharedPreferences _prefs;
  final Future<DownloadSource> Function(Song, AudioLevel)? _resolveOverride;
  final Future<String?> Function(int)? _lyricsOverride;
  final Future<Directory> Function()? _defaultDirectoryOverride;

  /// Start the queue automatically (off in tests).
  final bool autoStart;

  static const String tasksKey = 'dl.tasks';
  static const String doneKey = 'dl.done';
  static const int concurrency = 2;
  static const int _maxAttempts = 3;
  static const Duration _notifyInterval = Duration(milliseconds: 100);

  final List<DownloadTask> _tasks = [];
  final Map<int, DownloadRecord> _done = {};
  final Map<int, _Job> _jobs = {};
  bool _initialized = false;
  bool _disposed = false;
  Timer? _notifyTimer;
  bool _notifyPending = false;
  DateTime _lastNotify = DateTime.fromMillisecondsSinceEpoch(0);

  final HttpClient _http = HttpClient()
    ..connectionTimeout = const Duration(seconds: 15)
    ..idleTimeout = const Duration(seconds: 15)
    ..autoUncompress = false
    ..userAgent = AppConfig.userAgent;

  // ------------------------------------------------------------- queries

  /// Queued, running, failed and canceled downloads, oldest first.
  List<DownloadTask> get tasks => List.unmodifiable(_tasks);

  /// Finished downloads, newest first.
  List<DownloadRecord> get finished =>
      _done.values.toList()
        ..sort((a, b) => b.finishedAt.compareTo(a.finishedAt));

  /// Songs of [finished], ready for `player.playSongs`.
  List<Song> get finishedSongs => [for (final r in finished) r.song];

  int get activeCount => _tasks.where((t) => t.isActive).length;

  DownloadRecord? recordFor(int songId) => _done[songId];

  DownloadTask? taskFor(int songId) {
    for (final task in _tasks) {
      if (task.songId == songId) return task;
    }
    return null;
  }

  /// Absolute path of a finished download of [songId], if the file exists.
  /// Backed by the index verified on [init] (a file deleted behind the app's
  /// back is caught the next time the player opens it).
  String? localPathFor(int songId) => _done[songId]?.path;

  /// Like [localPathFor] but checks the file is still on disk. A download
  /// deleted outside the app is dropped from the index so the caller can fall
  /// back to streaming instead of failing on a missing file.
  String? verifiedPathFor(int songId) {
    final path = localPathFor(songId);
    if (path == null) return null;
    if (File(path).existsSync()) return path;
    _done.remove(songId);
    _persist();
    _notifyNow();
    return null;
  }

  bool isDownloaded(int songId) => localPathFor(songId) != null;

  /// `null` when not queued, otherwise 0 - 1 (1 = done).
  double? progressOf(int songId) {
    if (_done.containsKey(songId)) return 1;
    final task = taskFor(songId);
    if (task == null || !task.isActive) return null;
    return task.fraction ?? 0;
  }

  // ----------------------------------------------------------- lifecycle

  /// Restores the persisted queue / finished index and resumes the queue.
  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final rawDone = _prefs.getString(doneKey);
    if (rawDone != null) {
      try {
        final map = jsonDecode(rawDone) as Map<String, dynamic>;
        var checked = 0;
        for (final entry in map.entries) {
          final record = DownloadRecord.fromJson(entry.value);
          if (record == null) continue;
          if (await File(record.path).exists()) {
            _done[record.song.id] = record;
          }
          if (++checked % 50 == 0) await Future<void>.delayed(Duration.zero);
        }
      } on Object catch (error) {
        debugPrint('download index unreadable: $error');
      }
    }
    final rawTasks = _prefs.getString(tasksKey);
    if (rawTasks != null) {
      try {
        for (final item in jsonDecode(rawTasks) as List) {
          final task = DownloadTask.fromJson(item);
          if (task == null || _done.containsKey(task.songId)) continue;
          if (_tasks.any((t) => t.songId == task.songId)) continue;
          if (task.status == DownloadStatus.done) continue;
          _tasks.add(task);
        }
      } on Object catch (error) {
        debugPrint('download queue unreadable: $error');
      }
    }
    _persist();
    _notifyNow();
    if (autoStart && _tasks.any((t) => t.status == DownloadStatus.queued)) {
      // Let the session restore first: resolving urls needs the cookie.
      Timer(const Duration(seconds: 3), _pump);
    }
  }

  /// Queues [songs] (skips ones already downloaded or queued). [folder] is an
  /// optional sub folder name (album / playlist).
  Future<void> enqueue(List<Song> songs, {String? folder}) async {
    final safeFolder = folder == null || folder.trim().isEmpty
        ? null
        : sanitizeFileName(folder);
    var changed = false;
    for (final song in songs) {
      if (song.id <= 0 || _done.containsKey(song.id)) continue;
      final existing = taskFor(song.id);
      if (existing != null) {
        if (!existing.isActive) {
          existing
            ..status = DownloadStatus.queued
            ..error = null;
          changed = true;
        }
        continue;
      }
      _tasks.add(DownloadTask(song: song, folder: safeFolder));
      changed = true;
    }
    if (!changed) return;
    _persist();
    _notifyNow();
    if (autoStart) _pump();
  }

  /// Starts queued tasks up to [concurrency]. Exposed for tests.
  @visibleForTesting
  Future<void> runQueue() async {
    _pump();
    while (_jobs.isNotEmpty) {
      await Future.wait([for (final job in _jobs.values) job.done.future]);
      _pump();
    }
  }

  void _pump() {
    if (_disposed) return;
    for (final task in _tasks) {
      if (_jobs.length >= concurrency) break;
      if (task.status != DownloadStatus.queued) continue;
      if (_jobs.containsKey(task.songId)) continue;
      final job = _Job();
      _jobs[task.songId] = job;
      unawaited(_run(task, job));
    }
  }

  // ------------------------------------------------------------- actions

  /// Stops a queued / running download. Its partial file is deleted.
  Future<void> cancel(int songId) async {
    final task = taskFor(songId);
    if (task == null || !task.isActive) return;
    task
      ..status = DownloadStatus.canceled
      ..error = null;
    _notifyNow();
    final job = _jobs[songId];
    if (job != null) {
      job.cancel();
      await job.done.future;
    }
    await _deletePart(task);
    task.received = 0;
    _persist();
    _notifyNow();
  }

  /// Re-queues a failed / canceled download (resuming its partial file).
  void retry(int songId) {
    final task = taskFor(songId);
    if (task == null || task.isActive) return;
    task
      ..status = DownloadStatus.queued
      ..error = null;
    _persist();
    _notifyNow();
    _pump();
  }

  void retryAllFailed() {
    for (final task in _tasks) {
      if (task.status == DownloadStatus.failed ||
          task.status == DownloadStatus.canceled) {
        task
          ..status = DownloadStatus.queued
          ..error = null;
      }
    }
    _persist();
    _notifyNow();
    _pump();
  }

  /// Removes a task or a finished entry. With [deleteFile] the downloaded
  /// file is deleted too (partial files always are).
  Future<void> remove(int songId, {bool deleteFile = false}) async {
    final task = taskFor(songId);
    if (task != null) {
      if (task.isActive) await cancel(songId);
      await _deletePart(task);
      _tasks.remove(task);
    }
    final record = _done.remove(songId);
    if (record != null && deleteFile) {
      try {
        final file = File(record.path);
        if (await file.exists()) await file.delete();
      } on FileSystemException catch (error) {
        debugPrint('delete download failed: $error');
      }
    }
    _persist();
    _notifyNow();
  }

  /// Clears the finished list. Files stay on disk unless [deleteFiles].
  Future<void> clearFinished({bool deleteFiles = false}) async {
    if (deleteFiles) {
      for (final record in _done.values) {
        try {
          final file = File(record.path);
          if (await file.exists()) await file.delete();
        } on FileSystemException {
          // Keep going.
        }
      }
    }
    _done.clear();
    _persist();
    _notifyNow();
  }

  /// Drops failed / canceled tasks.
  Future<void> clearInactive() async {
    for (final task in _tasks.where((t) => !t.isActive).toList()) {
      await _deletePart(task);
      _tasks.remove(task);
    }
    _persist();
    _notifyNow();
  }

  /// Opens the download folder in the system file manager (desktop). Returns
  /// `false` where that is not possible (Android, iOS).
  Future<bool> openFolder() async {
    if (!Platforms.isDesktop) return false;
    try {
      final dir = await downloadDirectory();
      await dir.create(recursive: true);
      return await openDirectory(dir.path);
    } on Object {
      return false;
    }
  }

  /// Shows a finished download selected in Finder / Explorer (desktop).
  Future<bool> reveal(int songId) async {
    final record = _done[songId];
    if (record == null || !Platforms.isDesktop) return false;
    return revealInFileManager(record.path);
  }

  // ----------------------------------------------------------- directory

  /// Platform default download folder:
  /// desktop `Downloads/aMusic`, Android `<external app files>/Music/aMusic`
  /// (app specific, no permission needed), iOS `Documents/aMusic`.
  Future<Directory> defaultDirectory() async {
    final override = _defaultDirectoryOverride;
    if (override != null) return override();
    Directory? base;
    try {
      if (Platform.isAndroid) {
        final external = await getExternalStorageDirectory();
        if (external != null) {
          base = Directory(joinPath(external.path, 'Music'));
        }
      } else if (Platform.isIOS) {
        base = await getApplicationDocumentsDirectory();
      } else {
        base = await getDownloadsDirectory();
      }
    } on Object {
      base = null;
    }
    base ??= await getApplicationDocumentsDirectory();
    return Directory(joinPath(base.path, AppConfig.appName));
  }

  /// Folder downloads go to: the one chosen in settings, or the default.
  Future<Directory> downloadDirectory() async {
    final custom = _settings.value.downloadDirectory;
    if (custom != null && custom.trim().isNotEmpty) return Directory(custom);
    return defaultDirectory();
  }

  /// Creates [dir] and checks it can be written.
  static Future<void> probeWritable(Directory dir) async {
    try {
      await dir.create(recursive: true);
      final probe = File(
        joinPath(
          dir.path,
          '.amusic_probe_${DateTime.now().microsecondsSinceEpoch}',
        ),
      );
      await probe.writeAsString('ok', flush: true);
      await probe.delete();
    } on FileSystemException catch (error) {
      throw DownloadDirectoryException(
        dir.path,
        error.osError?.message ?? error.message,
      );
    }
  }

  // ----------------------------------------------------------------- run

  Future<void> _run(DownloadTask task, _Job job) async {
    task
      ..status = DownloadStatus.downloading
      ..error = null;
    _notifyNow();
    try {
      final root = await downloadDirectory();
      await probeWritable(root);
      final dir = task.folder == null
          ? root
          : Directory(joinPath(root.path, task.folder!));
      await dir.create(recursive: true);

      Object? lastError;
      for (var attempt = 0; attempt < _maxAttempts; attempt++) {
        if (job.canceled) break;
        try {
          await _attempt(task, job, dir);
          lastError = null;
          break;
        } on _Canceled {
          break;
        } on _Retryable catch (error) {
          lastError = error.cause;
          await Future<void>.delayed(Duration(seconds: 1 + attempt * 2));
        }
      }
      if (lastError != null) throw lastError;
    } on _Canceled {
      // Status already set by cancel().
    } on Object catch (error) {
      if (!job.canceled) {
        task
          ..status = DownloadStatus.failed
          ..error = _describe(error);
      }
    } finally {
      _jobs.remove(task.songId);
      job.done.complete();
      _persist();
      _notifyNow();
      if (autoStart) _pump();
    }
  }

  String _describe(Object error) {
    if (error is AppException) return error.message;
    if (error is DownloadDirectoryException) return error.toString();
    if (error is _DownloadError) return error.message;
    if (error is SocketException || error is HttpException) return '网络异常';
    if (error is TimeoutException) return '连接超时';
    if (error is FileSystemException) {
      return '写入失败：${error.osError?.message ?? error.message}';
    }
    return '$error';
  }

  Future<void> _attempt(DownloadTask task, _Job job, Directory dir) async {
    final requested = _settings.value.downloadLevel;
    final source = await _resolve(task.song, requested);
    if (source.trial) {
      throw const _DownloadError('仅能试听，无法下载完整歌曲');
    }
    final previousPart = task.partPath;
    final previousLevel = task.level;
    task
      ..level = source.level
      ..downgraded = source.level.bitrate < requested.bitrate;
    final ext = _extensionFor(source);
    final target = await _reserveTarget(task, dir, ext);
    final part = '$target.part';
    // A previous attempt wrote somewhere else (other format / name): that
    // partial file cannot be resumed into this one. A stray `.part` this
    // task never owned (crash of an older build) is not resumed either.
    if (previousPart != part) {
      if (previousPart != null) await _safeDelete(previousPart);
      await _safeDelete(part);
      task.received = 0;
    }
    final sizeChanged =
        source.size != null &&
        source.size! > 0 &&
        task.total > 0 &&
        task.total != source.size;
    if (sizeChanged ||
        (previousLevel != null && previousLevel != source.level)) {
      // A different file on the server than the one being resumed.
      await _safeDelete(part);
      task.received = 0;
    }
    task.total = source.size ?? task.total;
    _persist();

    await _fetch(task, job, source.url, part);
    if (job.canceled) throw const _Canceled();

    final tagged = await _finalize(task, part, target);
    final size = await File(target).length();
    _done[task.songId] = DownloadRecord(
      song: task.song,
      path: target,
      size: size,
      finishedAt: DateTime.now(),
      level: task.level,
      downgraded: task.downgraded,
      tagged: tagged,
    );
    task.status = DownloadStatus.done;
    _tasks.remove(task);
  }

  Future<DownloadSource> _resolve(Song song, AudioLevel level) async {
    final override = _resolveOverride;
    if (override != null) return override(song, level);
    final PlayUrl url = await _host.api.songUrlWithFallback(
      song.id,
      level: level,
    );
    return (
      url: url.url,
      level: url.level == null ? level : url.grantedLevel,
      type: url.type,
      size: url.size,
      trial: url.isTrial,
    );
  }

  static const Set<String> _knownExtensions = {
    'mp3',
    'flac',
    'm4a',
    'aac',
    'ogg',
    'opus',
    'wav',
  };

  static String _extensionFor(DownloadSource source) {
    final type = source.type?.toLowerCase().trim();
    if (type != null && _knownExtensions.contains(type)) return type;
    final fromUrl = extensionOf(Uri.tryParse(source.url)?.path ?? '');
    if (_knownExtensions.contains(fromUrl)) return fromUrl;
    return 'mp3';
  }

  Future<void> _nameLock = Future<void>.value();

  /// Picks the target name and claims it (sets [DownloadTask.partPath])
  /// under a lock, so two concurrent downloads of different songs with the
  /// same artist / title never pick the same file.
  Future<String> _reserveTarget(DownloadTask task, Directory dir, String ext) {
    final completer = Completer<String>();
    _nameLock = _nameLock.then((_) async {
      try {
        final target = await _targetPath(task, dir, ext);
        task.partPath = '$target.part';
        completer.complete(target);
      } on Object catch (error, stack) {
        completer.completeError(error, stack);
      }
    });
    return completer.future;
  }

  /// `<dir>/<artist> - <title>.<ext>`, made unique when a DIFFERENT song (or
  /// an unrelated file) already owns the name.
  Future<String> _targetPath(DownloadTask task, Directory dir, String ext) {
    final stem = trackFileStem([
      for (final a in task.song.artists) a.name,
    ], task.song.name);
    return uniqueFilePath(dir.path, stem, ext, (candidate) async {
      final key = pathKey(candidate);
      for (final record in _done.values) {
        if (pathKey(record.path) == key) {
          return record.song.id != task.songId;
        }
      }
      for (final other in _tasks) {
        if (other.songId == task.songId) continue;
        final otherPart = other.partPath;
        if (otherPart != null &&
            pathKey(otherPart) == pathKey('$candidate.part')) {
          return true;
        }
      }
      // A file nobody in the index owns: keep it, pick another name. The
      // exception is this task's own partial file from an earlier attempt.
      if (await File(candidate).exists()) return true;
      return false;
    });
  }

  static final RegExp _contentRange = RegExp(r'bytes (\d+)-\d+/(\d+|\*)');

  Future<void> _fetch(
    DownloadTask task,
    _Job job,
    String url,
    String partPath,
  ) async {
    final part = File(partPath);
    var offset = await part.exists() ? await part.length() : 0;
    if (task.total > 0 && offset > task.total) {
      await part.delete();
      offset = 0;
    }
    HttpClientResponse response;
    try {
      final request = await _http.getUrl(Uri.parse(url));
      job.request = request;
      request.headers
        ..set(HttpHeaders.refererHeader, 'https://music.163.com/')
        ..set(HttpHeaders.userAgentHeader, AppConfig.userAgent)
        ..set(HttpHeaders.acceptEncodingHeader, 'identity');
      if (offset > 0) {
        request.headers.set(HttpHeaders.rangeHeader, 'bytes=$offset-');
      }
      response = await request.close().timeout(const Duration(seconds: 20));
    } on Object catch (error) {
      if (job.canceled) throw const _Canceled();
      throw _Retryable(error);
    }

    var append = false;
    switch (response.statusCode) {
      case HttpStatus.partialContent:
        final range = response.headers.value(HttpHeaders.contentRangeHeader);
        final match = _contentRange.firstMatch(range ?? '');
        if (match == null || int.parse(match.group(1)!) != offset) {
          await response.drain<void>();
          await part.delete();
          throw const _Retryable(_DownloadError('续传位置不匹配'));
        }
        final whole = int.tryParse(match.group(2)!);
        if (whole != null) task.total = whole;
        append = true;
      case HttpStatus.ok:
        task.total = response.contentLength > 0
            ? response.contentLength
            : task.total;
        offset = 0;
      case HttpStatus.requestedRangeNotSatisfiable:
        await response.drain<void>();
        if (task.total > 0 && offset == task.total) {
          task.received = offset;
          return; // Already complete.
        }
        await part.delete();
        throw const _Retryable(_DownloadError('续传失败，重新下载'));
      default:
        await response.drain<void>();
        final retryable =
            response.statusCode >= 500 || response.statusCode == 403;
        final error = _DownloadError('服务器返回 ${response.statusCode}');
        // 403: the signed url expired, a fresh one is resolved next attempt.
        if (retryable) throw _Retryable(error);
        throw error;
    }

    task.received = offset;
    final sink = await part.open(
      mode: append ? FileMode.append : FileMode.write,
    );
    try {
      await for (final chunk in response.timeout(const Duration(seconds: 30))) {
        if (job.canceled) throw const _Canceled();
        await sink.writeFrom(chunk);
        task.received += chunk.length;
        _notifyThrottled();
      }
      await sink.flush();
    } on _Canceled {
      rethrow;
    } on Object catch (error) {
      if (job.canceled) throw const _Canceled();
      // Keep the partial file: the next attempt resumes it.
      throw _Retryable(error);
    } finally {
      await sink.close();
      job.request = null;
    }
    final length = await part.length();
    task.received = length;
    if (task.total > 0 && length != task.total) {
      throw _Retryable(_DownloadError('文件不完整（$length / ${task.total}）'));
    }
    if (task.total <= 0) task.total = length;
  }

  /// Tags the finished part file and moves it into place. Returns whether
  /// tags were written. Tagging problems never fail the download.
  Future<bool> _finalize(DownloadTask task, String part, String target) async {
    var source = part;
    var tagged = false;
    final tagging = '$target.tagging';
    try {
      final cover = await _fetchCover(task.song.album.picUrl);
      final lyrics = await _fetchLyrics(task.songId);
      final tag = TagData(
        title: task.song.name,
        artists: [for (final a in task.song.artists) a.name],
        album: task.song.album.name.isEmpty ? null : task.song.album.name,
        trackNumber: task.song.no,
        discNumber: task.song.cd,
        cover: cover,
        lyrics: lyrics,
      );
      if (await TagWriter.writeTagged(part, tagging, tag)) {
        source = tagging;
        tagged = true;
      }
    } on Object catch (error) {
      debugPrint('tagging ${task.songId} failed: $error');
      await _safeDelete(tagging);
    }
    final targetFile = File(target);
    // Same song re-downloaded: replace its old file. Rename does not overwrite
    // on Windows, so move the old file aside first and only drop it once the
    // new one is in place; a failed rename puts it back.
    File? previous;
    if (await targetFile.exists()) {
      previous = await targetFile.rename('$target.old');
    }
    try {
      await File(source).rename(target);
    } on Object {
      if (previous != null) await previous.rename(target);
      rethrow;
    }
    if (previous != null) await _safeDelete(previous.path);
    if (source != part) await _safeDelete(part);
    task.partPath = null;
    return tagged;
  }

  Future<TagPicture?> _fetchCover(String? url) async {
    if (url == null || url.isEmpty || !url.startsWith('http')) return null;
    final sized = url.contains('?') ? url : '$url?param=800y800';
    try {
      final request = await _http
          .getUrl(Uri.parse(sized))
          .timeout(const Duration(seconds: 10));
      request.headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
      final response = await request.close().timeout(
        const Duration(seconds: 10),
      );
      if (response.statusCode != HttpStatus.ok) {
        await response.drain<void>();
        return null;
      }
      final builder = BytesBuilder(copy: false);
      await for (final chunk in response.timeout(const Duration(seconds: 15))) {
        builder.add(chunk);
        if (builder.length > 8 * 1024 * 1024) return null;
      }
      return TagPicture.sniff(builder.takeBytes());
    } on Object {
      return null;
    }
  }

  Future<String?> _fetchLyrics(int songId) async {
    try {
      final override = _lyricsOverride;
      if (override != null) return plainLyrics(await override(songId));
      final payload = await _host.api
          .lyricPayload(songId)
          .timeout(const Duration(seconds: 8));
      if (payload.pureMusic) return null;
      return plainLyrics(payload.lrc);
    } on Object {
      return null;
    }
  }

  Future<void> _deletePart(DownloadTask task) async {
    final part = task.partPath;
    if (part == null) return;
    await _safeDelete(part);
    task.partPath = null;
  }

  static Future<void> _safeDelete(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Best effort.
    }
  }

  // ------------------------------------------------------- persistence

  void _persist() {
    if (_disposed) return;
    _prefs.setString(
      tasksKey,
      jsonEncode([for (final task in _tasks) task.toJson()]),
    );
    _prefs.setString(
      doneKey,
      jsonEncode({
        for (final record in _done.values) '${record.song.id}': record.toJson(),
      }),
    );
  }

  // ---------------------------------------------------- notifications

  void _notifyNow() {
    if (_disposed) return;
    _notifyTimer?.cancel();
    _notifyTimer = null;
    _notifyPending = false;
    _lastNotify = DateTime.now();
    notifyListeners();
  }

  /// At most one notification per [_notifyInterval] while bytes flow.
  void _notifyThrottled() {
    if (_disposed || _notifyPending) return;
    final elapsed = DateTime.now().difference(_lastNotify);
    if (elapsed >= _notifyInterval) {
      _notifyNow();
      return;
    }
    _notifyPending = true;
    _notifyTimer = Timer(_notifyInterval - elapsed, _notifyNow);
  }

  @override
  void dispose() {
    for (final job in _jobs.values) {
      job.cancel();
    }
    _persist();
    _disposed = true;
    _notifyTimer?.cancel();
    _http.close(force: true);
    super.dispose();
  }
}

class _Job {
  bool canceled = false;
  HttpClientRequest? request;
  final Completer<void> done = Completer<void>();

  void cancel() {
    canceled = true;
    request?.abort();
  }
}

class _Canceled implements Exception {
  const _Canceled();
}

class _Retryable implements Exception {
  const _Retryable(this.cause);

  final Object cause;
}

class _DownloadError implements Exception {
  const _DownloadError(this.message);

  final String message;

  @override
  String toString() => message;
}
