import 'dart:ffi' show Abi;
import 'dart:io' show Platform;

/// One file attached to a GitHub release.
class ReleaseAsset {
  const ReleaseAsset({required this.name, required this.url, this.size = 0});

  /// `aMusic-macos.zip`, `app-arm64-v8a-release.apk`, ...
  final String name;

  /// `browser_download_url`, always the original `github.com` URL: routing it
  /// through a mirror is the channel's job (`UpdateChannel.downloadUrl`).
  final String url;

  /// Bytes, 0 when the API did not say.
  final int size;

  static ReleaseAsset? fromGitHub(Object? json) {
    if (json is! Map) return null;
    final name = json['name'];
    final url = json['browser_download_url'];
    if (name is! String || name.isEmpty) return null;
    if (url is! String || url.isEmpty) return null;
    final size = json['size'];
    return ReleaseAsset(
      name: name,
      url: url,
      size: size is num ? size.toInt() : 0,
    );
  }

  static List<ReleaseAsset> listFromGitHub(Object? json) => [
    if (json is List)
      for (final item in json) ?fromGitHub(item),
  ];

  /// `<name>.sha256` or a `SHA256SUMS.txt` style manifest.
  bool get isChecksum =>
      name.toLowerCase().endsWith('.sha256') ||
      name.toLowerCase().endsWith('.sha256sum') ||
      name.toLowerCase() == 'sha256sums.txt' ||
      name.toLowerCase() == 'checksums.txt';

  @override
  String toString() => 'ReleaseAsset($name, $size)';
}

/// ABI token used by the Android split APKs (`--split-per-abi`).
String androidAbiToken(Abi abi) => switch (abi) {
  Abi.androidArm64 => 'arm64-v8a',
  Abi.androidArm => 'armeabi-v7a',
  Abi.androidX64 => 'x86_64',
  Abi.androidIA32 => 'x86',
  _ => '',
};

/// The ABI of the running process, as it appears in asset names. Empty when the
/// platform has no ABI specific build.
String currentAbiToken() {
  try {
    final abi = Abi.current();
    if (Platform.isAndroid) return androidAbiToken(abi);
    return switch (abi) {
      Abi.windowsArm64 => 'arm64',
      Abi.linuxArm64 || Abi.macosArm64 => 'arm64',
      Abi.linuxArm => 'arm',
      Abi.linuxX64 || Abi.windowsX64 || Abi.macosX64 => 'x64',
      _ => '',
    };
  } on Object {
    return '';
  }
}

/// The installer for this machine out of a release's assets, or `null` when the
/// release has nothing installable here (iOS: the unsigned ipa cannot be
/// installed over the air, so the UI opens the release page instead).
///
/// [os] is a `Platform.operatingSystem` value, [abi] a [currentAbiToken] value.
/// Pure so the matching can be tested against the real CI asset names.
ReleaseAsset? pickInstaller(
  List<ReleaseAsset> assets, {
  required String os,
  String abi = '',
}) {
  if (assets.isEmpty) return null;
  var best = 0;
  ReleaseAsset? winner;
  for (final asset in assets) {
    final score = _installerScore(asset.name, os: os, abi: abi);
    if (score > best) {
      best = score;
      winner = asset;
    }
  }
  return winner;
}

/// Higher wins; 0 means "not an installer for this platform".
int _installerScore(
  String fileName, {
  required String os,
  required String abi,
}) {
  final name = fileName.toLowerCase();
  bool has(String token) => token.isNotEmpty && name.contains(token);
  // Prefer the build that matches this machine's architecture, but never reject
  // an otherwise valid installer for it (CI publishes a universal macOS bundle).
  final arch = switch (abi) {
    'arm64-v8a' => has('arm64-v8a') || has('arm64') || has('aarch64'),
    'armeabi-v7a' => has('armeabi-v7a') || has('armv7'),
    'x86_64' => has('x86_64') || has('x64') || has('amd64'),
    'x86' => has('x86') && !has('x86_64'),
    'arm64' => has('arm64') || has('aarch64'),
    'arm' => has('arm') && !has('arm64'),
    'x64' => has('x64') || has('x86_64') || has('amd64'),
    _ => false,
  };
  final archBonus = arch ? 8 : 0;

  switch (os) {
    case 'android':
      if (!name.endsWith('.apk')) return 0;
      if (has('universal')) return 90;
      // Split APKs: only the one for this ABI installs cleanly.
      if (abi.isEmpty) return 40;
      return switch (abi) {
        'arm64-v8a' => has('arm64-v8a') ? 100 : 10,
        'armeabi-v7a' => has('armeabi-v7a') || has('armv7') ? 100 : 10,
        'x86_64' => has('x86_64') ? 100 : 10,
        'x86' => has('x86') && !has('x86_64') ? 100 : 10,
        _ => 40,
      };
    case 'macos':
      if (name.endsWith('.dmg')) return 100 + archBonus;
      if (name.endsWith('.pkg')) return 95 + archBonus;
      if (name.endsWith('.zip') &&
          (has('macos') || has('osx') || has('darwin'))) {
        return 90 + archBonus;
      }
      if (name.endsWith('.zip')) return 60 + archBonus;
      return 0;
    case 'windows':
      if (name.endsWith('.exe')) return 100 + archBonus;
      if (name.endsWith('.msix')) return 98 + archBonus;
      if (name.endsWith('.msi')) return 96 + archBonus;
      if (name.endsWith('.zip') && (has('windows') || has('win'))) {
        return 90 + archBonus;
      }
      if (name.endsWith('.zip')) return 60 + archBonus;
      return 0;
    case 'linux':
      if (name.endsWith('.appimage')) return 100 + archBonus;
      if (name.endsWith('.deb')) return 95 + archBonus;
      if (name.endsWith('.rpm')) return 90 + archBonus;
      final archive =
          name.endsWith('.tar.gz') ||
          name.endsWith('.tgz') ||
          name.endsWith('.tar.xz') ||
          name.endsWith('.tar.zst');
      if (archive && has('linux')) return 85 + archBonus;
      if (archive) return 60 + archBonus;
      if (name.endsWith('.zip')) return 50 + archBonus;
      return 0;
    default:
      // iOS: an unsigned ipa cannot be installed by the app itself.
      return 0;
  }
}

/// The checksum file for [asset], when the release publishes one: either
/// `<asset>.sha256` or a manifest listing every file.
ReleaseAsset? checksumAssetFor(ReleaseAsset asset, List<ReleaseAsset> assets) {
  final lower = asset.name.toLowerCase();
  for (final candidate in assets) {
    if (candidate.name.toLowerCase() == '$lower.sha256') return candidate;
  }
  for (final candidate in assets) {
    if (!candidate.isChecksum) continue;
    if (candidate.name.toLowerCase() == '$lower.sha256') continue;
    // `SHA256SUMS.txt` / `checksums.txt`: one manifest for the whole release.
    if (!candidate.name.toLowerCase().endsWith('.sha256')) return candidate;
  }
  return null;
}

/// Parses a `sha256sum` style line list (`<hash>  <file>`, `<hash> *<file>`, or
/// a bare hash) and returns the 64 hex chars for [fileName], `null` when the
/// manifest does not cover it.
String? checksumFromManifest(String manifest, String fileName) {
  final wanted = fileName.toLowerCase();
  for (final line in manifest.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isEmpty || trimmed.startsWith('#')) continue;
    final parts = trimmed.split(RegExp(r'\s+'));
    if (parts.length == 1) return _hex64(parts[0]);
    final hash = _hex64(parts[0]);
    if (hash == null) continue;
    var name = parts.last;
    if (name.startsWith('*')) name = name.substring(1);
    final slash = name.lastIndexOf('/');
    if (slash >= 0) name = name.substring(slash + 1);
    if (name.toLowerCase() == wanted) return hash;
  }
  return null;
}

String? _hex64(String value) {
  final cleaned = value.trim().toLowerCase();
  if (cleaned.length != 64) return null;
  return RegExp(r'^[0-9a-f]{64}$').hasMatch(cleaned) ? cleaned : null;
}
