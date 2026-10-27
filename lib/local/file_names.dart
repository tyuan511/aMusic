import 'dart:io';

/// File name helpers shared by downloads and imports.
///
/// Pure functions (no plugin calls) so they can be unit tested.

/// Longest stem (name without extension) produced by [sanitizeFileName].
const int maxFileStemLength = 120;

final RegExp _illegalChars = RegExp(r'[<>:"/\\|?*\x00-\x1F\x7F]');
final RegExp _whitespace = RegExp(r'\s+');
final RegExp _trailingDotsSpaces = RegExp(r'[. ]+$');
final RegExp _leadingDotsSpaces = RegExp(r'^[. ]+');
final RegExp _reservedWindowsName = RegExp(
  r'^(con|prn|aux|nul|com[1-9]|lpt[1-9])$',
  caseSensitive: false,
);

/// Makes [raw] safe as a file / folder name on Windows, macOS, Linux and
/// Android: replaces `<>:"/\|?*` and control characters with `_`, collapses
/// whitespace, strips leading / trailing dots and spaces, avoids reserved
/// Windows device names and caps the result at [maxLength] characters
/// (never splitting a surrogate pair). Returns [fallback] when nothing is
/// left.
String sanitizeFileName(
  String raw, {
  String fallback = '未命名',
  int maxLength = maxFileStemLength,
}) {
  // Whitespace (tabs, new lines) first so it becomes a space, not `_`.
  var name = raw
      .replaceAll(_whitespace, ' ')
      .replaceAll(_illegalChars, '_')
      .trim();
  name = _stripEdges(name);
  final runes = name.runes.toList();
  if (runes.length > maxLength) {
    name = _stripEdges(String.fromCharCodes(runes.take(maxLength)));
  }
  if (name.isEmpty) return fallback;
  if (_reservedWindowsName.hasMatch(name)) name = '_$name';
  return name;
}

String _stripEdges(String value) => value
    .replaceAll(_trailingDotsSpaces, '')
    .replaceAll(_leadingDotsSpaces, '');

/// `<artist> - <title>` stem for a downloaded track. Artists are joined with
/// `, ` (the usual `/` separator is not allowed in file names).
String trackFileStem(List<String> artists, String title) {
  final artist = artists.where((a) => a.trim().isNotEmpty).join(', ');
  final safeTitle = title.trim().isEmpty ? '未知歌曲' : title.trim();
  return sanitizeFileName(artist.isEmpty ? safeTitle : '$artist - $safeTitle');
}

/// Joins path segments with the platform separator.
String joinPath(String base, String child) {
  final sep = Platform.pathSeparator;
  if (base.endsWith(sep) || base.endsWith('/')) return '$base$child';
  return '$base$sep$child';
}

/// Last path segment.
String baseName(String path) {
  final normalized = path.replaceAll('\\', '/');
  final index = normalized.lastIndexOf('/');
  return index < 0 ? normalized : normalized.substring(index + 1);
}

/// Parent directory of [path] (`''` when there is none).
String dirName(String path) {
  final index = path.replaceAll('\\', '/').lastIndexOf('/');
  if (index < 0) return '';
  if (index == 0) return path.substring(0, 1);
  return path.substring(0, index);
}

/// Lower case extension without the dot (`''` when missing).
String extensionOf(String path) {
  final name = baseName(path);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? '' : name.substring(dot + 1).toLowerCase();
}

/// File name without its extension.
String stemOf(String path) {
  final name = baseName(path);
  final dot = name.lastIndexOf('.');
  return dot <= 0 ? name : name.substring(0, dot);
}

/// Key used to compare paths: case insensitive where the file system usually
/// is (Windows, macOS), with unified separators.
String pathKey(String path) {
  final unified = path.replaceAll('\\', '/');
  return Platform.isWindows || Platform.isMacOS
      ? unified.toLowerCase()
      : unified;
}

/// Picks `<directory>/<stem>.<ext>`, or `<stem> (2).<ext>`, `<stem> (3).<ext>`
/// ... when [isTaken] reports the name as owned by something else (a
/// different song, an unrelated file).
Future<String> uniqueFilePath(
  String directory,
  String stem,
  String ext,
  Future<bool> Function(String candidate) isTaken,
) async {
  for (var n = 1; n < 1000; n++) {
    final name = n == 1 ? '$stem.$ext' : '$stem ($n).$ext';
    final candidate = joinPath(directory, name);
    if (!await isTaken(candidate)) return candidate;
  }
  return joinPath(
    directory,
    '$stem (${DateTime.now().millisecondsSinceEpoch}).$ext',
  );
}
