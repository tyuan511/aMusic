import 'package:flutter/foundation.dart';

/// GitHub's own endpoints. Every mirror below is a plain URL prefix in front of
/// them, which is what the public Chinese mirrors (`gh-proxy.com`, ...) are.
const String githubApiBase = 'https://api.github.com';

/// Where release metadata and installers are fetched from.
///
/// `api.github.com` usually answers from mainland China, but
/// `github.com/.../releases/download` redirects to `objects.githubusercontent.com`,
/// which is slow or unreachable there. The mirrors below prefix that download
/// URL, so the app can update itself without a VPN.
enum UpdateSource {
  /// Official endpoints first, then every mirror in order.
  auto('自动', '官方优先，失败后依次尝试加速源'),
  github('GitHub 官方', 'api.github.com，海外网络最快'),
  ghProxy('gh-proxy.com', '国内加速，元数据与安装包都走加速'),
  ghfast('ghfast.top', '国内加速，元数据仍走官方'),
  ghLlkk('gh.llkk.cc', '国内加速，元数据与安装包都走加速'),

  /// A user typed prefix ([UpdateSourceConfig.customPrefix]); mirrors come and
  /// go, so the last one is always the user's own.
  custom('自定义', '填写自己的加速前缀');

  const UpdateSource(this.label, this.description);

  final String label;
  final String description;

  /// URL prefix in front of the original GitHub URL, `null` when direct or
  /// user supplied.
  String? get prefix => switch (this) {
    UpdateSource.ghProxy => 'https://gh-proxy.com/',
    UpdateSource.ghfast => 'https://ghfast.top/',
    UpdateSource.ghLlkk => 'https://gh.llkk.cc/',
    UpdateSource.auto || UpdateSource.github || UpdateSource.custom => null,
  };

  /// Built in mirrors, most reliable first.
  static const List<UpdateSource> mirrors = [
    UpdateSource.ghProxy,
    UpdateSource.ghfast,
    UpdateSource.ghLlkk,
  ];

  static UpdateSource fromName(String? name) => UpdateSource.values.firstWhere(
    (source) => source.name == name,
    orElse: () => UpdateSource.github,
  );
}

/// One concrete way of reaching GitHub: either direct or through a prefix.
class UpdateChannel {
  const UpdateChannel({required this.label, this.prefix});

  /// Shown in the UI ("gh-proxy.com", "自定义 · mirror.example.com").
  final String label;

  /// `https://gh-proxy.com/` (always ends with `/`), `null` for direct.
  final String? prefix;

  static const UpdateChannel direct = UpdateChannel(label: 'GitHub 官方');

  bool get isDirect => prefix == null;

  /// API endpoints to try, best first. A mirror that only proxies downloads
  /// (`ghfast.top` answers `403 Invalid input.` for `api.github.com`) fails on
  /// the first candidate, so the official host is always the second one.
  List<String> apiCandidates(String path) {
    final official = '$githubApiBase$path';
    final prefix = this.prefix;
    if (prefix == null) return [official];
    return ['$prefix$official', official];
  }

  /// [browserDownloadUrl] as published by the API, routed through this channel.
  String downloadUrl(String browserDownloadUrl) {
    final prefix = this.prefix;
    return prefix == null ? browserDownloadUrl : '$prefix$browserDownloadUrl';
  }

  @override
  bool operator ==(Object other) =>
      other is UpdateChannel && other.label == label && other.prefix == prefix;

  @override
  int get hashCode => Object.hash(label, prefix);

  @override
  String toString() => 'UpdateChannel($label)';
}

/// Normalizes a user typed prefix into `https://host/base/`.
///
/// `null` when [raw] is not a usable http(s) prefix. The query and fragment are
/// dropped and a missing trailing slash is added, so the concatenation in
/// [UpdateChannel.downloadUrl] cannot swallow a path segment.
String? normalizeMirrorPrefix(String raw) {
  final trimmed = raw.trim();
  if (trimmed.isEmpty) return null;
  final uri = Uri.tryParse(trimmed);
  if (uri == null) return null;
  if (uri.scheme != 'http' && uri.scheme != 'https') return null;
  if (uri.host.isEmpty) return null;
  final port = uri.hasPort ? ':${uri.port}' : '';
  var path = uri.path;
  if (!path.endsWith('/')) path = '$path/';
  return '${uri.scheme}://${uri.host}$port$path';
}

/// The user's update settings: which source, and whether a background check may
/// download the installer on its own.
///
/// Persisted by `UpdateService` under its own `update.` prefix, like the other
/// data a service owns (see the note on `SettingsState`).
@immutable
class UpdateSourceConfig {
  const UpdateSourceConfig({
    this.source = UpdateSource.github,
    this.customPrefix = '',
    this.autoInstall = false,
  });

  final UpdateSource source;

  /// Normalized prefix for [UpdateSource.custom]; ignored otherwise.
  final String customPrefix;

  /// Download the installer as soon as a background check finds a newer
  /// release, then ask the user to install it.
  final bool autoInstall;

  UpdateSourceConfig copyWith({
    UpdateSource? source,
    String? customPrefix,
    bool? autoInstall,
  }) => UpdateSourceConfig(
    source: source ?? this.source,
    customPrefix: customPrefix ?? this.customPrefix,
    autoInstall: autoInstall ?? this.autoInstall,
  );

  /// Whether [customPrefix] is usable; the settings row says so instead of
  /// silently falling back.
  bool get hasValidCustomPrefix => normalizeMirrorPrefix(customPrefix) != null;

  /// Label for the settings row.
  String get label => switch (source) {
    UpdateSource.custom =>
      hasValidCustomPrefix
          ? '自定义 · ${Uri.parse(customPrefix).host}'
          : '自定义 · 未设置',
    _ => source.label,
  };

  /// Channels to try, in order. Never empty: an invalid custom prefix falls
  /// back to the official endpoints so a check still works.
  List<UpdateChannel> channels() => switch (source) {
    UpdateSource.auto => [
      UpdateChannel.direct,
      for (final mirror in UpdateSource.mirrors)
        UpdateChannel(label: mirror.label, prefix: mirror.prefix),
    ],
    UpdateSource.custom => () {
      final prefix = normalizeMirrorPrefix(customPrefix);
      if (prefix == null) return [UpdateChannel.direct];
      return [
        UpdateChannel(label: '自定义 · ${Uri.parse(prefix).host}', prefix: prefix),
      ];
    }(),
    UpdateSource.github => const [UpdateChannel.direct],
    UpdateSource.ghProxy || UpdateSource.ghfast || UpdateSource.ghLlkk => [
      UpdateChannel(label: source.label, prefix: source.prefix),
    ],
  };

  @override
  bool operator ==(Object other) =>
      other is UpdateSourceConfig &&
      other.source == source &&
      other.customPrefix == customPrefix &&
      other.autoInstall == autoInstall;

  @override
  int get hashCode => Object.hash(source, customPrefix, autoInstall);
}
