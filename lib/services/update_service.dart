import 'dart:async';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:open_filex/open_filex.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path_provider/path_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../local/release_version.dart';
import 'update_asset.dart';
import 'update_source.dart';

/// A newer release published on GitHub.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    this.notes = '',
    this.name,
    this.publishedAt,
    this.assets = const [],
  });

  /// Normalized version (`2.1.0`, no `v`).
  final String version;

  /// Release page.
  final String url;
  final String notes;
  final String? name;
  final DateTime? publishedAt;

  /// Files attached to the release (installers, checksums).
  final List<ReleaseAsset> assets;

  /// Parses a `releases/latest` payload; `null` when it has no usable tag.
  static AppRelease? fromGitHub(Map<String, dynamic> json) {
    final tag = json['tag_name'];
    if (tag is! String) return null;
    final version = ReleaseVersion.parse(tag);
    if (version == null) return null;
    final url = json['html_url'];
    final published = json['published_at'];
    return AppRelease(
      version: version.toString(),
      url: url is String && url.isNotEmpty ? url : UpdateService.releasesPage,
      notes: (json['body'] as String? ?? '').trim(),
      name: (json['name'] as String?)?.trim(),
      publishedAt: published is String ? DateTime.tryParse(published) : null,
      assets: ReleaseAsset.listFromGitHub(json['assets']),
    );
  }
}

/// Progress of the installer download.
enum UpdateDownloadStatus { idle, downloading, ready, failed }

@immutable
class UpdateDownload {
  const UpdateDownload({
    this.status = UpdateDownloadStatus.idle,
    this.progress = 0,
    this.file,
    this.error,
    this.channel,
  });

  final UpdateDownloadStatus status;

  /// 0 - 1, `0` while the total size is unknown.
  final double progress;

  /// The verified installer once [status] is `ready`.
  final File? file;
  final String? error;

  /// Label of the source currently (or last) used.
  final String? channel;
}

/// Checks GitHub releases for a newer build, downloads and launches the
/// installer.
///
/// Every request goes through the channels of the user's [UpdateSourceConfig]
/// (official GitHub, a mainland China mirror, or a custom prefix) and falls
/// through to the next channel on failure.
///
/// Background checks run at most once per 24 h (`update.checked_at`), only
/// while `settings.checkUpdates` is on, and ignore a version the user chose
/// to skip (`update.skipped`). [checkNow] ignores both.
class UpdateService {
  UpdateService({
    required this._prefs,
    @visibleForTesting Dio? dio,
    @visibleForTesting this._currentVersion,
    @visibleForTesting this._downloadDir,
    @visibleForTesting this._os,
  }) : _dio =
           dio ??
           Dio(
             BaseOptions(
               connectTimeout: _timeout,
               receiveTimeout: _timeout,
               sendTimeout: _timeout,
               headers: const {
                 'Accept': 'application/vnd.github+json',
                 'User-Agent': 'aMusic-update-check',
               },
             ),
           ) {
    config = ValueNotifier(_readConfig());
  }

  final SharedPreferences _prefs;
  final Dio _dio;
  final Future<String> Function()? _currentVersion;
  final Future<Directory> Function()? _downloadDir;
  final String? _os;

  static const String repo = 'tyuan511/amusic';
  static const String latestUrl = '$githubApiBase/repos/$repo/releases/latest';
  static const String _latestPath = '/repos/$repo/releases/latest';
  static const String releasesPage = 'https://github.com/$repo/releases';
  static const String repoPage = 'https://github.com/$repo';
  static const Duration _timeout = Duration(seconds: 8);
  static const Duration throttle = Duration(hours: 24);

  static const String checkedAtKey = 'update.checked_at';
  static const String skippedKey = 'update.skipped';
  static const String sourceKey = 'update.source';
  static const String customPrefixKey = 'update.custom_prefix';
  static const String autoInstallKey = 'update.auto_install';

  /// Latest release newer than the running build, or `null`.
  final ValueNotifier<AppRelease?> available = ValueNotifier(null);

  /// Which source to use, persisted.
  late final ValueNotifier<UpdateSourceConfig> config;

  /// State of the installer download for [available] / the last explicit check.
  final ValueNotifier<UpdateDownload> download = ValueNotifier(
    const UpdateDownload(),
  );

  /// Channel that answered the last metadata request.
  UpdateChannel? lastChannel;

  bool _running = false;
  CancelToken? _cancel;

  UpdateSourceConfig _readConfig() => UpdateSourceConfig(
    source: UpdateSource.fromName(_prefs.getString(sourceKey)),
    customPrefix: _prefs.getString(customPrefixKey) ?? '',
    autoInstall: _prefs.getBool(autoInstallKey) ?? false,
  );

  Future<void> setSource(UpdateSource source) =>
      _writeConfig(config.value.copyWith(source: source));

  /// Stores the user typed prefix (normalized when valid, as typed otherwise so
  /// the field keeps what was entered) and switches to it.
  Future<void> setCustomPrefix(String raw) {
    final normalized = normalizeMirrorPrefix(raw);
    return _writeConfig(
      config.value.copyWith(
        source: UpdateSource.custom,
        customPrefix: normalized ?? raw.trim(),
      ),
    );
  }

  Future<void> setAutoInstall(bool value) =>
      _writeConfig(config.value.copyWith(autoInstall: value));

  Future<void> _writeConfig(UpdateSourceConfig next) async {
    config.value = next;
    await _prefs.setString(sourceKey, next.source.name);
    await _prefs.setString(customPrefixKey, next.customPrefix);
    await _prefs.setBool(autoInstallKey, next.autoInstall);
  }

  /// Version of the running build (`2.0.0`).
  Future<String> currentVersion() async {
    final override = _currentVersion;
    if (override != null) return override();
    final info = await PackageInfo.fromPlatform();
    return info.version;
  }

  String? get skippedVersion => _prefs.getString(skippedKey);

  DateTime? get lastChecked {
    final ms = _prefs.getInt(checkedAtKey);
    return ms == null ? null : DateTime.fromMillisecondsSinceEpoch(ms);
  }

  bool get _enabled => _prefs.getBool(PrefsKeys.checkUpdates) ?? true;

  String get _platform => _os ?? Platform.operatingSystem;

  /// The installer this machine can run, `null` when the release has none
  /// (iOS, or a release without binaries).
  ReleaseAsset? installerFor(AppRelease release) => pickInstaller(
    release.assets,
    os: _platform,
    abi: _os == null ? currentAbiToken() : '',
  );

  /// Throttled background check (no-op when disabled in settings). Never
  /// throws.
  Future<void> checkInBackground() async {
    if (!_enabled || _running) return;
    final last = lastChecked;
    if (last != null && DateTime.now().difference(last) < throttle) return;
    try {
      // `_check` already withholds a skipped version from [available].
      await _check();
      final release = available.value;
      if (release != null && config.value.autoInstall) {
        unawaited(startDownload(release));
      }
    } on Object catch (error) {
      debugPrint('update check failed: $error');
    }
  }

  /// Explicit check from the settings screen; throws on network errors.
  /// Returns the newer release (even a skipped one) or `null`.
  Future<AppRelease?> checkNow() => _check();

  Future<AppRelease?> _check() async {
    _running = true;
    try {
      final data = await _fetchLatest();
      await _prefs.setInt(checkedAtKey, DateTime.now().millisecondsSinceEpoch);
      final release = data == null ? null : AppRelease.fromGitHub(data);
      if (release == null) {
        available.value = null;
        return null;
      }
      final current = await currentVersion();
      final newer = isNewerVersion(release.version, current);
      available.value = newer && release.version != skippedVersion
          ? release
          : null;
      return newer ? release : null;
    } finally {
      _running = false;
    }
  }

  /// `releases/latest` through the configured channels; `null` when the
  /// repository has no release yet. Throws a readable error when every
  /// channel failed.
  Future<Map<String, dynamic>?> _fetchLatest() async {
    String? failure;
    for (final channel in config.value.channels()) {
      final candidates = channel.apiCandidates(_latestPath);
      for (final url in candidates) {
        try {
          final response = await _dio.get<Map<String, dynamic>>(url);
          final data = response.data;
          if (data == null || data['tag_name'] is! String) {
            failure = '${channel.label} 返回了无法识别的内容';
            continue;
          }
          lastChannel = channel;
          return data;
        } on DioException catch (error) {
          // Only the official host's 404 means "no release"; a mirror's 404
          // is just a mirror that does not know the path.
          if (error.response?.statusCode == 404 &&
              url.startsWith(githubApiBase)) {
            lastChannel = channel;
            return null;
          }
          failure = _describe(error, channel.label);
        }
      }
    }
    throw Exception(failure ?? '无法连接更新源');
  }

  static String _describe(DioException error, String label) =>
      switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => '连接 $label 超时',
        DioExceptionType.badResponse =>
          '$label 返回 ${error.response?.statusCode}',
        DioExceptionType.cancel => '已取消',
        _ => '无法连接 $label',
      };

  // ----------------------------------------------------------------- download

  /// Downloads and verifies the installer of [release]. Idempotent while a
  /// download is running; a finished one is reused. Progress is published on
  /// [download]; failures end in `failed` instead of throwing.
  Future<void> startDownload(AppRelease release) async {
    if (download.value.status == UpdateDownloadStatus.downloading) return;
    final asset = installerFor(release);
    if (asset == null) {
      download.value = const UpdateDownload(
        status: UpdateDownloadStatus.failed,
        error: '此版本没有适用于当前系统的安装包',
      );
      return;
    }
    final cancel = _cancel = CancelToken();
    download.value = const UpdateDownload(
      status: UpdateDownloadStatus.downloading,
    );
    String? failure;
    try {
      final dir = await _ensureDir(release.version);
      final target = File('${dir.path}${Platform.pathSeparator}${asset.name}');
      final channels = config.value.channels();
      for (final channel in channels) {
        if (cancel.isCancelled) break;
        download.value = UpdateDownload(
          status: UpdateDownloadStatus.downloading,
          channel: channel.label,
        );
        try {
          await _fetchInstaller(release, asset, channel, target, cancel);
          download.value = UpdateDownload(
            status: UpdateDownloadStatus.ready,
            progress: 1,
            file: target,
            channel: channel.label,
          );
          return;
        } on DioException catch (error) {
          if (CancelToken.isCancel(error)) break;
          failure = _describe(error, channel.label);
        } on _ChecksumMismatch {
          failure = '${channel.label} 的安装包校验失败';
        }
      }
    } on Object catch (error) {
      failure = '$error';
    }
    download.value = UpdateDownload(
      status: cancel.isCancelled
          ? UpdateDownloadStatus.idle
          : UpdateDownloadStatus.failed,
      error: cancel.isCancelled ? null : (failure ?? '下载失败'),
    );
  }

  Future<void> _fetchInstaller(
    AppRelease release,
    ReleaseAsset asset,
    UpdateChannel channel,
    File target,
    CancelToken cancel,
  ) async {
    final expected = await _expectedChecksum(release, asset, channel);
    if (await target.exists() && await _verified(target, asset, expected)) {
      return;
    }
    final partial = File('${target.path}.part');
    await _dio.download(
      channel.downloadUrl(asset.url),
      partial.path,
      cancelToken: cancel,
      options: Options(
        headers: const {'Accept': '*/*'},
        receiveTimeout: const Duration(seconds: 30),
      ),
      onReceiveProgress: (received, total) {
        final current = download.value;
        if (current.status != UpdateDownloadStatus.downloading) return;
        final size = total > 0 ? total : asset.size;
        download.value = UpdateDownload(
          status: UpdateDownloadStatus.downloading,
          progress: size > 0 ? (received / size).clamp(0.0, 1.0) : 0,
          channel: channel.label,
        );
      },
    );
    if (!await _verified(partial, asset, expected)) {
      await partial.delete();
      throw const _ChecksumMismatch();
    }
    if (await target.exists()) await target.delete();
    await partial.rename(target.path);
  }

  /// SHA-256 published next to the installer, `null` when the release has none
  /// or it could not be read (the size check still applies).
  Future<String?> _expectedChecksum(
    AppRelease release,
    ReleaseAsset asset,
    UpdateChannel channel,
  ) async {
    final checksum = checksumAssetFor(asset, release.assets);
    if (checksum == null) return null;
    for (final url in {channel.downloadUrl(checksum.url), checksum.url}) {
      try {
        final response = await _dio.get<String>(
          url,
          options: Options(
            responseType: ResponseType.plain,
            headers: const {'Accept': '*/*'},
          ),
        );
        final hash = checksumFromManifest(response.data ?? '', asset.name);
        if (hash != null) return hash;
      } on DioException {
        continue;
      }
    }
    return null;
  }

  Future<bool> _verified(
    File file,
    ReleaseAsset asset,
    String? expected,
  ) async {
    if (!await file.exists()) return false;
    if (asset.size > 0 && await file.length() != asset.size) return false;
    if (expected == null) return true;
    final digest = await sha256.bind(file.openRead()).first;
    return digest.toString() == expected;
  }

  Future<Directory> _ensureDir(String version) async {
    final override = _downloadDir;
    final base = override != null
        ? await override()
        : await getTemporaryDirectory();
    final dir = Directory(
      '${base.path}${Platform.pathSeparator}amusic_update${Platform.pathSeparator}$version',
    );
    return dir.create(recursive: true);
  }

  /// Stops a running download.
  void cancelDownload() => _cancel?.cancel();

  /// Hands the downloaded installer to the system. Archives cannot be run, so
  /// their folder is revealed instead. Returns a message when it failed.
  Future<String?> install(File file) async {
    try {
      final name = file.path.toLowerCase();
      final archive =
          name.endsWith('.zip') ||
          name.endsWith('.tar.gz') ||
          name.endsWith('.tgz') ||
          name.endsWith('.tar.xz');
      if (archive && !Platform.isAndroid) {
        if (Platform.isMacOS) {
          await Process.run('open', ['-R', file.path]);
        } else if (Platform.isWindows) {
          await Process.run('explorer', ['/select,', file.path]);
        } else {
          await Process.run('xdg-open', [file.parent.path]);
        }
        return null;
      }
      final result = await OpenFilex.open(file.path);
      return result.type == ResultType.done ? null : result.message;
    } on Object catch (error) {
      return '$error';
    }
  }

  /// Never offer [version] again in background checks.
  Future<void> skip(String version) async {
    await _prefs.setString(skippedKey, version);
    if (available.value?.version == version) available.value = null;
  }

  /// Hides the current offer until the next check ("稍后").
  void dismiss() => available.value = null;
}

class _ChecksumMismatch implements Exception {
  const _ChecksumMismatch();
}
