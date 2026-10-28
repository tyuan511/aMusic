// ignore_for_file: experimental_member_use
// Drives the real Rust engine through the real `just_audio` AudioPlayer.
//
//   cd packages/amusic_engine/rust && cargo build --release
//   flutter test packages/amusic_engine/test
//
// The tests play at volume 0 on the default output device and are skipped when
// the dylib was not built or there is no output device.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:amusic_engine/amusic_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

String? _findDylib() {
  final env = Platform.environment['AMUSIC_ENGINE_LIB'];
  if (env != null && File(env).existsSync()) return env;
  for (final base in ['.', 'packages/amusic_engine', '..']) {
    final f = File('$base/rust/target/release/libamusic_engine.dylib');
    if (f.existsSync()) return f.absolute.path;
  }
  return null;
}

/// A 16-bit stereo WAV with a sine tone.
Uint8List _wav(double seconds, double hz, {int rate = 44100}) {
  final frames = (seconds * rate).round();
  final data = ByteData(44 + frames * 4);
  void tag(int at, String s) {
    for (var i = 0; i < 4; i++) {
      data.setUint8(at + i, s.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  data.setUint32(4, 36 + frames * 4, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  data.setUint32(16, 16, Endian.little);
  data.setUint16(20, 1, Endian.little);
  data.setUint16(22, 2, Endian.little);
  data.setUint32(24, rate, Endian.little);
  data.setUint32(28, rate * 4, Endian.little);
  data.setUint16(32, 4, Endian.little);
  data.setUint16(34, 16, Endian.little);
  tag(36, 'data');
  data.setUint32(40, frames * 4, Endian.little);
  for (var i = 0; i < frames; i++) {
    final v = (math.sin(2 * math.pi * hz * i / rate) * 0.3 * 32767).round();
    data.setInt16(44 + i * 4, v, Endian.little);
    data.setInt16(46 + i * 4, v, Endian.little);
  }
  return data.buffer.asUint8List();
}

/// Serves bytes the way the app's `ResolvingAudioSource` does: as a just_audio
/// `StreamAudioSource`, which just_audio exposes to the backend as a local
/// http url.
class _BytesSource extends StreamAudioSource {
  _BytesSource(this.bytes);

  final Uint8List bytes;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    final from = start ?? 0;
    final to = end ?? bytes.length;
    return StreamAudioResponse(
      sourceLength: bytes.length,
      contentLength: to - from,
      offset: from,
      stream: Stream.value(bytes.sublist(from, to)),
      contentType: 'audio/wav',
    );
  }
}

Future<T> _until<T>(
  Stream<T> stream,
  bool Function(T) test, {
  Duration timeout = const Duration(seconds: 12),
}) => stream.firstWhere(test).timeout(timeout);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final dylib = _findDylib();
  late Directory dir;
  late File a;
  late File b;
  late File c;

  setUpAll(() {
    if (dylib == null) return;
    // The engine opens the library through this override outside the app.
    // (Set before the first lookup.)
    dir = Directory.systemTemp.createTempSync('amusic_engine_test');
    a = File('${dir.path}/a b.wav')..writeAsBytesSync(_wav(1.2, 440));
    b = File('${dir.path}/b.wav')..writeAsBytesSync(_wav(1.2, 660));
    c = File('${dir.path}/c.wav')..writeAsBytesSync(_wav(1.2, 880));
    AmusicJustAudioTestHook.useLibrary(dylib);
    // Registers the backend on any host, so the static equalizer hook reaches
    // the players created below.
    JustAudioPlatform.instance = AmusicJustAudioTestHook.platform();
  });

  tearDownAll(() {
    if (dylib != null) dir.deleteSync(recursive: true);
  });

  AudioPlayer newPlayer() => AudioPlayer(
    handleInterruptions: false,
    androidApplyAudioAttributes: false,
    handleAudioSessionActivation: false,
  );

  final skip = dylib == null ? 'build the Rust engine first' : null;

  test('plays local files and rolls into the next one without a gap', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    final indices = <int?>[];
    player.currentIndexStream.listen(indices.add);

    await player.setAudioSources([
      AudioSource.file(a.path),
      AudioSource.file(b.path),
    ]);
    expect(player.duration, isNotNull);
    expect(player.duration!.inMilliseconds, closeTo(1200, 80));
    final states = <ProcessingState>[];
    player.processingStateStream.listen(states.add);

    unawaited(player.play());
    await _until(player.currentIndexStream, (i) => i == 1);
    // Never dipped into completed between the two tracks.
    expect(states.contains(ProcessingState.completed), isFalse);
    await _until(
      player.processingStateStream,
      (s) => s == ProcessingState.completed,
    );
    expect(indices, containsAllInOrder([0, 1]));
  }, skip: skip);

  test('plays a StreamAudioSource through just_audio\'s local proxy', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setAudioSource(_BytesSource(_wav(1.0, 500)));
    expect(player.duration!.inMilliseconds, closeTo(1000, 80));
    unawaited(player.play());
    await _until(
      player.processingStateStream,
      (s) => s == ProcessingState.completed,
    );
  }, skip: skip);

  test('seeks inside a track and to another track', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setAudioSources([
      AudioSource.file(a.path),
      AudioSource.file(b.path),
      AudioSource.file(c.path),
    ]);
    await player.seek(const Duration(milliseconds: 700));
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(player.position.inMilliseconds, closeTo(700, 150));

    await player.seek(Duration.zero, index: 2);
    expect(player.currentIndex, 2);
    await Future<void>.delayed(const Duration(milliseconds: 300));
    expect(player.position.inMilliseconds, lessThan(400));
    expect(player.hasNext, isFalse);
    expect(player.hasPrevious, isTrue);
  }, skip: skip);

  test('follows the shuffle order and loop mode', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setAudioSources([
      AudioSource.file(a.path),
      AudioSource.file(b.path),
      AudioSource.file(c.path),
    ]);
    await player.setShuffleModeEnabled(true);
    final order = player.effectiveIndices;
    expect(order.toSet(), {0, 1, 2});
    await player.seek(Duration.zero, index: order.first);

    final seen = <int>[];
    player.currentIndexStream.listen((i) {
      if (i != null) seen.add(i);
    });
    await player.setLoopMode(LoopMode.off);
    unawaited(player.play());
    await _until(
      player.processingStateStream,
      (s) => s == ProcessingState.completed,
      timeout: const Duration(seconds: 15),
    );
    expect(seen.toSet(), order.toSet(), reason: 'seen $seen order $order');
    expect(seen.last, order.last);
  }, skip: skip);

  test('loop all wraps back to the first track', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setLoopMode(LoopMode.all);
    await player.setAudioSources([
      AudioSource.file(a.path),
      AudioSource.file(b.path),
    ]);
    final seen = <int>[];
    player.currentIndexStream.listen((i) {
      if (i != null) seen.add(i);
    });
    unawaited(player.play());
    await _until(player.currentIndexStream, (i) => i == 1);
    await _until(
      player.currentIndexStream,
      (i) => i == 0,
      timeout: const Duration(seconds: 10),
    );
    expect(player.processingState, isNot(ProcessingState.completed));
  }, skip: skip);

  test('2x speed finishes in about half the time', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setSpeed(2.0);
    await player.setAudioSource(AudioSource.file(a.path));
    final watch = Stopwatch()..start();
    unawaited(player.play());
    await _until(
      player.processingStateStream,
      (s) => s == ProcessingState.completed,
    );
    expect(watch.elapsedMilliseconds, closeTo(600, 350));
  }, skip: skip);

  test('queue edits keep the current track', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setAudioSources([
      AudioSource.file(a.path),
      AudioSource.file(b.path),
    ]);
    await player.seek(Duration.zero, index: 1);
    await player.insertAudioSource(0, AudioSource.file(c.path));
    expect(player.currentIndex, 2);
    await player.moveAudioSource(0, 2);
    expect(player.currentIndex, 1);
    await player.removeAudioSourceAt(0);
    expect(player.currentIndex, 0);
    expect(player.audioSources.length, 2);
    unawaited(player.play());
    await _until(
      player.processingStateStream,
      (s) => s == ProcessingState.completed,
    );
  }, skip: skip);

  test('every DSP effect can be switched on while playing', () async {
    final player = newPlayer();
    addTearDown(() {
      AmusicJustAudio.setEq(AmusicEq.off);
      return player.dispose();
    });
    await player.setVolume(0);
    await player.setAudioSources([AudioSource.file(a.path)]);
    unawaited(player.play());
    for (final effect in [1, 2, 3, 4, 0]) {
      AmusicJustAudio.setEq(AmusicEq(effect: effect));
      await Future<void>.delayed(const Duration(milliseconds: 150));
      expect(player.processingState, isNot(ProcessingState.idle));
    }
    await _until(
      player.processingStateStream,
      (s) => s == ProcessingState.completed,
    );
  }, skip: skip);

  test('a missing file is reported as an error', () async {
    final player = newPlayer();
    addTearDown(player.dispose);
    await player.setVolume(0);
    await expectLater(
      player.setAudioSource(AudioSource.file('${dir.path}/nope.wav')),
      throwsA(anything),
    );
  }, skip: skip);
}
