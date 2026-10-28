import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/local/audio_probe.dart';
import 'package:amusic/local/tag_picture.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fixtures.dart';

void main() {
  late Directory temp;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('amusic_tags_');
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  const probe = AudioProbe();

  group('mp3', () {
    test('ID3v2 tags, cover and duration', () async {
      final meta = await probe.probeFile('test/system/data/song.mp3');
      expect(meta.container, AudioContainer.mp3);
      expect(meta.title, '晴天');
      expect(meta.artist, '周杰伦');
      expect(meta.album, '叶惠美');
      expect(meta.trackNumber, 1);
      expect(meta.replayGainDb, isNull);
      expect(meta.cover, isNotNull);
      expect(meta.cover!.mime, 'image/jpeg');
      expect(
        meta.cover!.bytes,
        File('test/system/data/cover.jpg').readAsBytesSync(),
      );
      // 30 frames * 1152 samples / 44.1 kHz, CBR estimate from 128 kbps.
      expect(meta.duration.inMilliseconds, closeTo(784, 30));
    });

    test('ID3v1 fallback', () async {
      final v1 = Uint8List(128);
      v1.setAll(0, 'TAG'.codeUnits);
      v1.setAll(3, 'Old Song'.codeUnits);
      v1.setAll(33, 'Old Band'.codeUnits);
      v1.setAll(63, 'Old Album'.codeUnits);
      final file = File('${temp.path}/v1.mp3');
      await file.writeAsBytes([...mp3Frames(10), ...v1]);
      final meta = await probe.probeFile(file.path);
      expect(meta.title, 'Old Song');
      expect(meta.artist, 'Old Band');
      expect(meta.album, 'Old Album');
    });
  });

  group('FLAC', () {
    test('STREAMINFO duration + Vorbis comments', () async {
      final meta = await probe.probeFile('test/system/data/song.flac');
      expect(meta.container, AudioContainer.flac);
      expect(meta.duration.inMilliseconds, closeTo(2000, 20));
      expect(meta.title, '夜曲');
      expect(meta.artist, '周杰伦');
      expect(meta.album, '十一月的萧邦');
      expect(meta.trackNumber, 2);
    });
  });

  group('M4A', () {
    test('moov after mdat: mvhd duration + ilst tags + covr', () async {
      final meta = await probe.probeFile('test/system/data/song.m4a');
      expect(meta.container, AudioContainer.m4a);
      expect(meta.duration.inMilliseconds, closeTo(2000, 60));
      expect(meta.title, '稻香');
      expect(meta.artist, '周杰伦');
      expect(meta.album, '魔杰座');
      expect(meta.trackNumber, 7);
      expect(
        meta.cover?.bytes,
        File('test/system/data/cover.jpg').readAsBytesSync(),
      );
    });

    test('moov first works too', () async {
      final meta = await probe.probeFile('test/system/data/faststart.m4a');
      expect(meta.title, 'A');
      expect(meta.duration.inMilliseconds, closeTo(2000, 60));
    });
  });

  group('ReplayGain', () {
    test('a tagged file reports its gain next to the other tags', () async {
      final flac = await probe.probeFile('test/system/data/gain.flac');
      expect(flac.container, AudioContainer.flac);
      expect(flac.title, '夜曲');
      expect(flac.artist, '周杰伦');
      expect(flac.trackNumber, 2);
      expect(flac.replayGainDb, closeTo(-6.5, 0.01));

      final mp3 = await probe.probeFile('test/system/data/gain.mp3');
      expect(mp3.container, AudioContainer.mp3);
      expect(mp3.title, '晴天');
      expect(mp3.replayGainDb, closeTo(-6.5, 0.01));
    });

    test('an untagged file reports none', () async {
      final meta = await probe.probeFile('test/system/data/song.flac');
      expect(meta.title, '夜曲');
      expect(meta.replayGainDb, isNull);
    });
  });

  test('WAV duration and INFO title', () async {
    final file = File('${temp.path}/rain.wav');
    await file.writeAsBytes(wavFile(seconds: 3, title: 'Rain'));
    final meta = await probe.probeFile(file.path);
    expect(meta.container, AudioContainer.wav);
    expect(meta.duration, const Duration(seconds: 3));
    expect(meta.title, 'Rain');
  });

  test('file name fallback', () {
    final parsed = AudioProbe.fromFileName('/music/周杰伦 - 晴天.mp3');
    expect(parsed.artist, '周杰伦');
    expect(parsed.title, '晴天');
    expect(AudioProbe.fromFileName('/music/track01.flac').title, 'track01');
  });

  test('TagPicture sniffing', () {
    expect(TagPicture.mimeOf(fakeJpeg()), 'image/jpeg');
    expect(
      TagPicture.mimeOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
      'image/png',
    );
    expect(TagPicture.mimeOf([1, 2, 3, 4]), isNull);
    expect(TagPicture.sniff(fakeJpeg())?.extension, 'jpg');
  });
}
