import 'dart:async';
import 'dart:io';

import 'package:amusic_engine/amusic_engine.dart';

/// Points the engine at a host build of the Rust library, so code that calls
/// into it (NetEase crypto, tag probing, cover colours) runs under
/// `flutter test`. Builds it first when it is missing.
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final lib = _hostLibrary();
  if (lib != null) AmusicNative.overrideLibrary(lib);
  await testMain();
}

String? _hostLibrary() {
  final override = Platform.environment['AMUSIC_ENGINE_LIB'];
  if (override != null && override.isNotEmpty) return override;
  final name = Platform.isMacOS
      ? 'libamusic_engine.dylib'
      : Platform.isWindows
      ? 'amusic_engine.dll'
      : 'libamusic_engine.so';
  final crate = '${Directory.current.path}/packages/amusic_engine/rust';
  final path = '$crate/target/release/$name';
  if (!File(path).existsSync()) {
    final result = Process.runSync('cargo', [
      'build',
      '--release',
      '--manifest-path',
      '$crate/Cargo.toml',
    ]);
    if (result.exitCode != 0 || !File(path).existsSync()) return null;
  }
  return path;
}
