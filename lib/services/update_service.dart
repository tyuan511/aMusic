import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../local/release_version.dart';

/// A newer release published on GitHub.
class AppRelease {
  const AppRelease({
    required this.version,
    required this.url,
    this.notes = '',
    this.name,
    this.publishedAt,
  });

  /// Normalized version (`2.1.0`, no `v`).
  final String version;

  /// Release page.
  final String url;
  final String notes;
  final String? name;
  final DateTime? publishedAt;

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
    );
  }
}

/// Checks GitHub releases for a newer build.
///
/// Background checks run at most once per 24 h (`update.checked_at`), only
/// while `settings.checkUpdates` is on, and ignore a version the user chose
/// to skip (`update.skipped`). [checkNow] ignores both.
class UpdateService {
  UpdateService({
    required this._prefs,
    @visibleForTesting Dio? dio,
    @visibleForTesting this._currentVersion,
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
           );

  final SharedPreferences _prefs;
  final Dio _dio;
  final Future<String> Function()? _currentVersion;

  static const String repo = 'tyuan511/amusic';
  static const String latestUrl =
      'https://api.github.com/repos/$repo/releases/latest';
  static const String releasesPage = 'https://github.com/$repo/releases';
  static const String repoPage = 'https://github.com/$repo';
  static const Duration _timeout = Duration(seconds: 8);
  static const Duration throttle = Duration(hours: 24);

  static const String checkedAtKey = 'update.checked_at';
  static const String skippedKey = 'update.skipped';

  /// Latest release newer than the running build, or `null`.
  final ValueNotifier<AppRelease?> available = ValueNotifier(null);

  bool _running = false;

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

  /// Throttled background check (no-op when disabled in settings). Never
  /// throws.
  Future<void> checkInBackground() async {
    if (!_enabled || _running) return;
    final last = lastChecked;
    if (last != null && DateTime.now().difference(last) < throttle) return;
    try {
      // `_check` already withholds a skipped version from [available].
      await _check();
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
      final response = await _dio.get<Map<String, dynamic>>(latestUrl);
      await _prefs.setInt(checkedAtKey, DateTime.now().millisecondsSinceEpoch);
      final data = response.data;
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
    } on DioException catch (error) {
      if (error.response?.statusCode == 404) {
        // No release published yet.
        await _prefs.setInt(
          checkedAtKey,
          DateTime.now().millisecondsSinceEpoch,
        );
        available.value = null;
        return null;
      }
      throw Exception(switch (error.type) {
        DioExceptionType.connectionTimeout ||
        DioExceptionType.receiveTimeout ||
        DioExceptionType.sendTimeout => '连接 GitHub 超时',
        DioExceptionType.badResponse =>
          'GitHub 返回 ${error.response?.statusCode}',
        _ => '无法连接 GitHub',
      });
    } finally {
      _running = false;
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
