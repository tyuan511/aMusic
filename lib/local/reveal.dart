import 'dart:io';

import 'package:url_launcher/url_launcher.dart';

import 'file_names.dart';

/// Opens [directory] in the system file manager (desktop only).
Future<bool> openDirectory(String directory) async {
  if (!(Platform.isMacOS || Platform.isWindows || Platform.isLinux)) {
    return false;
  }
  try {
    return await launchUrl(Uri.directory(directory));
  } on Object {
    return false;
  }
}

/// Shows [path] selected in Finder / Explorer; other desktops open its
/// folder. Returns `false` on mobile or failure.
Future<bool> revealInFileManager(String path) async {
  try {
    if (Platform.isMacOS) {
      final result = await Process.run('open', ['-R', path]);
      if (result.exitCode == 0) return true;
    } else if (Platform.isWindows) {
      // explorer.exe returns 1 even on success.
      await Process.run('explorer.exe', ['/select,', path]);
      return true;
    }
  } on Object {
    // Fall back to opening the folder.
  }
  return openDirectory(dirName(path));
}
