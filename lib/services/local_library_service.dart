import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:file_selector/file_selector.dart';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/file_names.dart';
import '../local/local_scanner.dart';
import '../local/reveal.dart';
import '../local/local_track.dart';
import '../local/tag_picture.dart';
import '../models/song.dart';

/// Storage permission state of the local library (Android only; other
/// platforms are always [granted]).
enum LocalPermission { unknown, granted, denied, permanentlyDenied }

/// State of the running (or last) scan.
class LocalScanState {
  const LocalScanState({
    this.scanning = false,
    this.found = 0,
    this.probed = 0,
    this.current,
    this.message,
  });

  final bool scanning;
  final int found;
  final int probed;
  final String? current;

  /// Summary of the last scan ("新增 3 首" / an error).
  final String? message;
}

/// Audio files on this device (scanned folders + imported files).
///
/// Local songs use NEGATIVE ids so they never collide with NetEase ids; the
/// player resolves them through [pathFor] instead of the song url endpoint.
///
/// The library is persisted as JSON in the app support directory (atomic
/// writes); folder choices live in prefs under `local.`.
class LocalLibraryService extends ChangeNotifier {
  LocalLibraryService({
    required this._prefs,
    @visibleForTesting Future<Directory> Function()? storageDirectory,
    @visibleForTesting Future<Directory> Function()? coverDirectory,
    @visibleForTesting List<String>? defaultRoots,
  }) : _storageDirectory = storageDirectory ?? getApplicationSupportDirectory,
       _coverDirectory = coverDirectory ?? _defaultCoverDirectory,
       _defaultRootsOverride = defaultRoots;

  final SharedPreferences _prefs;
  final Future<Directory> Function() _storageDirectory;
  final Future<Directory> Function() _coverDirectory;
  final List<String>? _defaultRootsOverride;
  final LocalScanner _scanner = LocalScanner();

  static const String _foldersKey = 'local.folders';
  static const String _excludedKey = 'local.excluded';
  static const String _scanDefaultsKey = 'local.scan_defaults';
  static const String _libraryFile = 'local_library.json';

  /// Bumped whenever stored tracks miss a field a scan has to fill in again.
  static const int _libraryVersion = 2;

  /// Playable songs (missing files excluded), most recently added first.
  final ValueNotifier<List<Song>> songs = ValueNotifier(const []);

  /// Tracks whose file disappeared.
  final ValueNotifier<List<LocalTrack>> missing = ValueNotifier(const []);

  final ValueNotifier<LocalScanState> scanState = ValueNotifier(
    const LocalScanState(),
  );

  final ValueNotifier<LocalPermission> permission = ValueNotifier(
    LocalPermission.unknown,
  );

  /// Path key -> track (present and missing).
  final Map<String, LocalTrack> _tracks = {};
  final Set<String> _missingKeys = {};
  final Map<int, LocalTrack> _byId = {};
  bool _initialized = false;
  bool _cancelScan = false;

  /// One full re-probe after reading a library an older build wrote.
  bool _reprobeAll = false;
  Future<void>? _running;

  static bool isLocalId(int id) => id < 0;

  // ------------------------------------------------------------- lifecycle

  Future<void> init() async {
    if (_initialized) return;
    _initialized = true;
    final file = await _file();
    if (file != null && await file.exists()) {
      try {
        final raw = jsonDecode(await file.readAsString());
        final list = raw is Map ? raw['tracks'] : raw;
        if (list is List) {
          for (final item in list) {
            final track = LocalTrack.fromJson(item);
            if (track != null) _tracks[pathKey(track.path)] = track;
          }
        }
        // Tracks stored by an older build miss what it did not know yet (the
        // ReplayGain tag before version 2), so the next scan reads every file.
        final version = raw is Map ? (raw['version'] as num?)?.toInt() ?? 0 : 0;
        _reprobeAll = _tracks.isNotEmpty && version < _libraryVersion;
      } on Object catch (error) {
        debugPrint('local library unreadable: $error');
      }
    }
    await _verifyFiles();
    _publish();
    if (Platform.isAndroid) {
      final granted = await _permissionGranted();
      permission.value = granted
          ? LocalPermission.granted
          : LocalPermission.denied;
    } else {
      permission.value = LocalPermission.granted;
    }
  }

  /// Marks tracks whose file is gone and drops cover files the OS evicted.
  Future<void> _verifyFiles() async {
    _missingKeys.clear();
    var count = 0;
    for (final entry in _tracks.entries.toList()) {
      if (!await File(entry.value.path).exists()) {
        _missingKeys.add(entry.key);
      }
      final cover = entry.value.coverPath;
      if (cover != null && !await File(cover).exists()) {
        _tracks[entry.key] = entry.value.copyWith(clearCover: true);
      }
      if (++count % 50 == 0) await Future<void>.delayed(Duration.zero);
    }
  }

  // --------------------------------------------------------------- queries

  /// File path of a local song, `null` when unknown or missing.
  String? pathFor(int songId) {
    final track = _byId[songId];
    if (track == null || _missingKeys.contains(pathKey(track.path))) {
      return null;
    }
    return track.path;
  }

  LocalTrack? trackFor(int songId) => _byId[songId];

  /// `REPLAYGAIN_TRACK_GAIN` (dB) of the local file at [path]; `null` when the
  /// file is not in the library or carries no such tag. The engine asks by uri,
  /// so a stream (which is never a local path) simply plays at unity gain.
  double? replayGainFor(String path) => _tracks[pathKey(path)]?.replayGainDb;

  /// All present tracks (same order as [songs]).
  List<LocalTrack> get tracks => [
    for (final song in songs.value) ?_byId[song.id],
  ];

  /// Extra folders added by the user.
  List<String> get folders => _prefs.getStringList(_foldersKey) ?? const [];

  /// Whether the platform default music folders are scanned.
  bool get scansDefaultFolders => _prefs.getBool(_scanDefaultsKey) ?? true;

  Future<void> setScansDefaultFolders(bool value) async {
    await _prefs.setBool(_scanDefaultsKey, value);
    notifyListeners();
  }

  // ------------------------------------------------------------ permission

  Future<bool> _permissionGranted() async {
    if (!Platform.isAndroid) return true;
    try {
      // READ_MEDIA_AUDIO on 13+, READ_EXTERNAL_STORAGE below (each plugin
      // group reports "denied" on the API levels where it does not apply).
      final audio = await Permission.audio.status;
      if (audio.isGranted) return true;
      final storage = await Permission.storage.status;
      return storage.isGranted;
    } on Object {
      return false;
    }
  }

  /// Requests storage / audio access (Android). Returns whether it is granted.
  Future<bool> requestPermission() async {
    if (!Platform.isAndroid) {
      permission.value = LocalPermission.granted;
      return true;
    }
    try {
      final results = await [Permission.audio, Permission.storage].request();
      final granted = results.values.any((status) => status.isGranted);
      final permanent = results.values.any(
        (status) => status.isPermanentlyDenied,
      );
      permission.value = granted
          ? LocalPermission.granted
          : (permanent
                ? LocalPermission.permanentlyDenied
                : LocalPermission.denied);
      return granted;
    } on Object {
      permission.value = LocalPermission.denied;
      return false;
    }
  }

  /// Opens the system app settings (after a permanent denial).
  Future<bool> openPermissionSettings() => openAppSettings();

  // ------------------------------------------------------------------ scan

  /// Default music folders of this platform.
  Future<List<String>> defaultRoots() async {
    final override = _defaultRootsOverride;
    if (override != null) return override;
    final env = Platform.environment;
    try {
      if (Platform.isMacOS) {
        final home = env['HOME'];
        if (home != null) return ['$home/Music'];
      } else if (Platform.isWindows) {
        final home = env['USERPROFILE'];
        if (home != null) return ['$home\\Music'];
      } else if (Platform.isLinux) {
        final xdg = env['XDG_MUSIC_DIR'];
        if (xdg != null && xdg.isNotEmpty) return [xdg];
        final home = env['HOME'];
        if (home != null) return ['$home/Music'];
      } else if (Platform.isAndroid) {
        return ['/storage/emulated/0/Music', '/storage/emulated/0/Download'];
      } else if (Platform.isIOS) {
        return [(await getApplicationDocumentsDirectory()).path];
      }
    } on Object {
      // No default folder.
    }
    return const [];
  }

  bool get isScanning => scanState.value.scanning;

  /// Rescans the default folders + user folders. Concurrent calls share one
  /// run.
  Future<void> scan() => _running ??= _scan().whenComplete(() {
    _running = null;
  });

  void cancelScan() => _cancelScan = true;

  Future<void> _scan() async {
    if (Platform.isAndroid && !await _permissionGranted()) {
      final granted = await requestPermission();
      if (!granted && folders.isEmpty) {
        scanState.value = const LocalScanState(message: '没有读取音乐的权限');
        return;
      }
    }
    _cancelScan = false;
    scanState.value = const LocalScanState(scanning: true);
    final roots = <String>{
      if (scansDefaultFolders) ...await defaultRoots(),
      ...folders,
    }.toList();
    final before = _tracks.length - _missingKeys.length;
    var lastTick = DateTime.fromMillisecondsSinceEpoch(0);
    try {
      final result = await _scanner.scan(
        roots,
        previous: Map.of(_tracks),
        excluded: _excluded,
        reprobeAll: _reprobeAll,
        saveCover: _saveCover,
        isCanceled: () => _cancelScan,
        onProgress: (progress) {
          final now = DateTime.now();
          // At most ~10 updates a second.
          if (now.difference(lastTick).inMilliseconds < 100) return;
          lastTick = now;
          scanState.value = LocalScanState(
            scanning: true,
            found: progress.found,
            probed: progress.probed,
            current: progress.current,
          );
        },
      );
      if (result.canceled) {
        scanState.value = const LocalScanState(message: '扫描已取消');
        return;
      }
      _reprobeAll = false;
      final scannedKeys = {for (final t in result.tracks) pathKey(t.path)};
      for (final track in result.tracks) {
        _tracks[pathKey(track.path)] = track;
      }
      // Scanned entries the walk did not see again: still there (beyond the
      // depth cap, an imported file...) or gone.
      for (final entry in _tracks.entries.toList()) {
        if (scannedKeys.contains(entry.key)) continue;
        if (entry.value.source == LocalTrackSource.scan &&
            !_underAny(entry.value.path, roots)) {
          // Its folder is no longer scanned.
          await _dropCover(entry.value);
          _tracks.remove(entry.key);
        }
      }
      await _verifyFiles();
      await _save();
      _publish();
      final after = _tracks.length - _missingKeys.length;
      final delta = after - before;
      scanState.value = LocalScanState(
        found: after,
        message: [
          if (delta > 0) '新增 $delta 首' else '共 $after 首',
          if (result.truncated) '已达上限 ${LocalScanner.maxFiles} 首',
          if (result.unreadableRoots.isNotEmpty)
            '${result.unreadableRoots.length} 个文件夹无法读取',
        ].join('，'),
      );
    } on Object catch (error) {
      scanState.value = LocalScanState(message: '扫描失败：$error');
    }
  }

  static bool _underAny(String path, List<String> roots) {
    final key = pathKey(path);
    return roots.any((root) {
      var rootKey = pathKey(root);
      if (!rootKey.endsWith('/')) rootKey = '$rootKey/';
      return key.startsWith(rootKey);
    });
  }

  // ------------------------------------------------------- folders / files

  /// Lets the user pick a folder, remembers it and rescans. Returns `false`
  /// when the picker was dismissed.
  Future<bool> addFolder() async {
    final picked = await getDirectoryPath(confirmButtonText: '添加');
    if (picked == null || picked.isEmpty) return false;
    final next = {...folders, picked}.toList();
    await _prefs.setStringList(_foldersKey, next);
    // A folder picked explicitly is readable even without the broad
    // permission (Android grants the tree).
    await scan();
    return true;
  }

  Future<void> removeFolder(String folder) async {
    await _prefs.setStringList(
      _foldersKey,
      folders.where((f) => f != folder).toList(),
    );
    notifyListeners();
    await scan();
  }

  static const XTypeGroup _audioTypes = XTypeGroup(
    label: '音频',
    extensions: ['mp3', 'flac', 'm4a', 'aac', 'ogg', 'wav'],
    mimeTypes: [
      'audio/mpeg',
      'audio/flac',
      'audio/x-flac',
      'audio/mp4',
      'audio/x-m4a',
      'audio/aac',
      'audio/ogg',
      'audio/wav',
      'audio/x-wav',
    ],
    uniformTypeIdentifiers: ['public.audio'],
  );

  /// Picks audio files and adds them. On Android / iOS the picked file is a
  /// temporary copy, so it is copied into the app's storage first. Returns
  /// the number of tracks added.
  Future<int> importFiles() async {
    final files = await openFiles(acceptedTypeGroups: const [_audioTypes]);
    if (files.isEmpty) return 0;
    scanState.value = const LocalScanState(scanning: true);
    var added = 0;
    try {
      final excluded = _excluded;
      for (final file in files) {
        var path = file.path;
        if (!LocalScanner.isAudioPath(path) &&
            !LocalScanner.isAudioPath(file.name)) {
          continue;
        }
        if (Platform.isAndroid || Platform.isIOS) {
          path = await _copyIntoLibrary(file);
        }
        final key = pathKey(path);
        if (excluded.contains(key)) {
          await _setExcluded(excluded..remove(key));
        }
        final stat = await File(path).stat();
        if (stat.type == FileSystemEntityType.notFound) continue;
        final track = await _scanner.probeTrack(
          path,
          stat,
          added: DateTime.now(),
          source: LocalTrackSource.import,
          saveCover: _saveCover,
        );
        if (!_tracks.containsKey(key) || _missingKeys.contains(key)) added++;
        _tracks[key] = track;
        _missingKeys.remove(key);
        scanState.value = LocalScanState(
          scanning: true,
          found: added,
          current: path,
        );
      }
      await _save();
      _publish();
      scanState.value = LocalScanState(
        found: _tracks.length,
        message: '已导入 $added 首',
      );
    } on Object catch (error) {
      scanState.value = LocalScanState(message: '导入失败：$error');
    }
    return added;
  }

  Future<String> _copyIntoLibrary(XFile file) async {
    final base = await _storageDirectory();
    final dir = Directory(joinPath(base.path, 'local_imports'));
    await dir.create(recursive: true);
    final name = file.name.isNotEmpty ? file.name : baseName(file.path);
    final ext = extensionOf(name);
    final stem = sanitizeFileName(stemOf(name));
    final target = await uniqueFilePath(
      dir.path,
      stem,
      ext.isEmpty ? 'mp3' : ext,
      (candidate) => File(candidate).exists(),
    );
    await File(file.path).copy(target);
    return target;
  }

  // -------------------------------------------------------------- removal

  /// Removes a track from the library (the file stays). A scanned file is
  /// remembered as excluded so the next scan does not bring it back.
  Future<void> remove(int songId) async {
    final track = _byId[songId];
    if (track == null) return;
    final key = pathKey(track.path);
    if (track.source == LocalTrackSource.scan) {
      await _setExcluded(_excluded..add(key));
    }
    await _forget(key);
  }

  /// Deletes the file from disk and removes it from the library. Imported
  /// copies inside the app storage are deleted the same way.
  Future<void> deleteFile(int songId) async {
    final track = _byId[songId];
    if (track == null) return;
    final file = File(track.path);
    if (await file.exists()) await file.delete();
    await _forget(pathKey(track.path));
  }

  /// Drops every track whose file is missing.
  Future<int> cleanupMissing() async {
    final keys = _missingKeys.toList();
    for (final key in keys) {
      final track = _tracks.remove(key);
      if (track != null) await _dropCover(track);
    }
    _missingKeys.clear();
    await _save();
    _publish();
    return keys.length;
  }

  Future<void> _forget(String key) async {
    final track = _tracks.remove(key);
    _missingKeys.remove(key);
    if (track != null) await _dropCover(track);
    await _save();
    _publish();
  }

  Set<String> get _excluded =>
      (_prefs.getStringList(_excludedKey) ?? const []).toSet();

  Future<void> _setExcluded(Set<String> keys) =>
      _prefs.setStringList(_excludedKey, keys.toList());

  /// Reveals the file in Finder / Explorer (desktop).
  Future<bool> showInFolder(int songId) async {
    final track = _byId[songId];
    if (track == null) return false;
    return revealInFileManager(track.path);
  }

  // --------------------------------------------------------------- covers

  static Future<Directory> _defaultCoverDirectory() async {
    final base = await getApplicationCacheDirectory();
    return Directory(joinPath(base.path, 'local_covers'));
  }

  Future<String?> _saveCover(String path, TagPicture picture) async {
    try {
      final dir = await _coverDirectory();
      await dir.create(recursive: true);
      final name = sha1.convert(utf8.encode(pathKey(path))).toString();
      final file = File(joinPath(dir.path, '$name.${picture.extension}'));
      await file.writeAsBytes(picture.bytes, flush: true);
      return file.path;
    } on Object {
      return null;
    }
  }

  Future<void> _dropCover(LocalTrack track) async {
    final cover = track.coverPath;
    if (cover == null) return;
    try {
      final file = File(cover);
      if (await file.exists()) await file.delete();
    } on FileSystemException {
      // Cache files are disposable.
    }
  }

  // ---------------------------------------------------------- persistence

  Future<File?> _file() async {
    try {
      final dir = await _storageDirectory();
      return File(joinPath(dir.path, _libraryFile));
    } on Object {
      return null;
    }
  }

  /// Atomic write: temp file + rename.
  Future<void> _save() async {
    final file = await _file();
    if (file == null) return;
    try {
      await file.parent.create(recursive: true);
      final temp = File('${file.path}.tmp');
      await temp.writeAsString(
        jsonEncode({
          'version': _libraryVersion,
          'tracks': [for (final t in _tracks.values) t.toJson()],
        }),
        flush: true,
      );
      await temp.rename(file.path);
    } on Object catch (error) {
      debugPrint('local library save failed: $error');
    }
  }

  void _publish() {
    final present = <LocalTrack>[];
    final gone = <LocalTrack>[];
    _byId.clear();
    for (final entry in _tracks.entries) {
      _byId[entry.value.id] = entry.value;
      (_missingKeys.contains(entry.key) ? gone : present).add(entry.value);
    }
    present.sort((a, b) => b.added.compareTo(a.added));
    songs.value = List.unmodifiable(present.map((t) => t.toSong()));
    missing.value = List.unmodifiable(gone);
    notifyListeners();
  }

  @override
  void dispose() {
    _cancelScan = true;
    songs.dispose();
    missing.dispose();
    scanState.dispose();
    permission.dispose();
    super.dispose();
  }
}
