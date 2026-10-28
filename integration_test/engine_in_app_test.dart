// Runs inside the real macOS app bundle, so the Rust engine is loaded from the
// embedded amusic_engine.framework exactly like in production:
//
//   flutter test integration_test/engine_in_app_test.dart -d macos
//
// Plays at volume 0.

import 'dart:async';
import 'dart:io';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:amusic_engine/amusic_engine.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:just_audio/just_audio.dart';

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

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the bundled Rust engine plays and equalizes in the app', (
    tester,
  ) async {
    expect(AmusicJustAudio.ensureInitialized(), isTrue);
    final dir = Directory.systemTemp.createTempSync('amusic_in_app');
    addTearDown(() => dir.deleteSync(recursive: true));
    final a = File('${dir.path}/a.wav')..writeAsBytesSync(_wav(1.0, 440));
    final b = File('${dir.path}/b.wav')..writeAsBytesSync(_wav(1.0, 660));

    AmusicJustAudio.setEq(
      const AmusicEq(bands: [(62.5, 1.41, 6.0), (8000, 1.0, -3.0)]),
    );

    final player = AudioPlayer(
      handleInterruptions: false,
      androidApplyAudioAttributes: false,
      handleAudioSessionActivation: false,
    );
    addTearDown(player.dispose);
    await player.setVolume(0);
    await player.setAudioSources([
      AudioSource.file(a.path),
      AudioSource.file(b.path),
    ]);
    expect(player.duration!.inMilliseconds, closeTo(1000, 80));

    unawaited(player.play());
    await player.currentIndexStream
        .firstWhere((i) => i == 1)
        .timeout(const Duration(seconds: 10));

    // Change the sound effect and the equalizer while playing.
    for (final effect in [1, 2, 3, 4]) {
      AmusicJustAudio.setEq(AmusicEq(effect: effect));
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    AmusicJustAudio.setEq(AmusicEq.off);
    await player.processingStateStream
        .firstWhere((s) => s == ProcessingState.completed)
        .timeout(const Duration(seconds: 10));
  });
}
