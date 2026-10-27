import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/local/audio_probe.dart';
import 'package:amusic/local/byte_source.dart';
import 'package:amusic/local/tags/flac_writer.dart';
import 'package:amusic/local/tags/id3_writer.dart';
import 'package:amusic/local/tags/tag_data.dart';
import 'package:amusic/local/tags/tag_writer.dart';
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

  group('ID3v2.3 writer -> probe round trip', () {
    test('unicode text, track number, cover and lyrics', () async {
      final cover = fakeJpeg();
      final source = File('${temp.path}/in.mp3');
      // 100 frames * 1152 samples / 44100 Hz = 2.612 s.
      await source.writeAsBytes(mp3Frames(100));
      final target = '${temp.path}/out.mp3';

      final ok = await TagWriter.writeTagged(
        source.path,
        target,
        TagData(
          title: '晴天',
          artists: const ['周杰伦', 'Lara'],
          album: '叶惠美',
          trackNumber: 3,
          cover: TagPicture(bytes: cover, mime: 'image/jpeg'),
          lyrics: plainLyrics('[00:01.00]故事的小黄花\n[00:05.20]从出生那年就飘着'),
        ),
      );
      expect(ok, isTrue);

      final meta = await probe.probeFile(target);
      expect(meta.container, AudioContainer.mp3);
      expect(meta.title, '晴天');
      expect(meta.artist, '周杰伦/Lara');
      expect(meta.album, '叶惠美');
      expect(meta.trackNumber, 3);
      expect(meta.cover, isNotNull);
      expect(meta.cover!.mime, 'image/jpeg');
      expect(meta.cover!.bytes, cover);
      // CBR estimate from 128 kbps.
      expect(meta.duration.inMilliseconds, closeTo(2606, 30));

      // The audio payload is preserved byte for byte after the tag.
      final bytes = await File(target).readAsBytes();
      final tagSize = Id3v2Writer.tagSize(bytes);
      expect(bytes.sublist(tagSize), await source.readAsBytes());
    });

    test('latin-1 text and re-tagging replaces the old tag', () async {
      final source = File('${temp.path}/in.mp3');
      await source.writeAsBytes(mp3Frames(20));
      final first = '${temp.path}/first.mp3';
      final second = '${temp.path}/second.mp3';
      await TagWriter.writeTagged(
        source.path,
        first,
        const TagData(title: 'Old', artists: ['A']),
      );
      await TagWriter.writeTagged(
        first,
        second,
        const TagData(
          title: 'Yesterday',
          artists: ['The Beatles'],
          album: 'Help!',
        ),
      );
      final meta = await probe.probeFile(second);
      expect(meta.title, 'Yesterday');
      expect(meta.artist, 'The Beatles');
      expect(meta.album, 'Help!');
      final bytes = await File(second).readAsBytes();
      // Exactly one tag in front of the audio.
      final size = Id3v2Writer.tagSize(bytes);
      expect(Id3v2Writer.tagSize(bytes.sublist(size)), 0);
      expect(bytes.length - size, mp3Frames(20).length);
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
      final meta = await probe.probe(
        MemoryByteSource(
          flacFile(
            sampleRate: 48000,
            totalSamples: 48000 * 200,
            comments: {
              'TITLE': '夜曲',
              'ARTIST': '周杰伦',
              'ALBUM': '十一月的萧邦',
              'TRACKNUMBER': '2/12',
            },
          ),
        ),
      );
      expect(meta.container, AudioContainer.flac);
      expect(meta.duration, const Duration(seconds: 200));
      expect(meta.title, '夜曲');
      expect(meta.artist, '周杰伦');
      expect(meta.album, '十一月的萧邦');
      expect(meta.trackNumber, 2);
    });

    test('writer replaces comments, adds PICTURE, keeps frames', () async {
      final original = flacFile(
        comments: {'TITLE': 'old'},
        withId3Prefix: true,
      );
      final source = File('${temp.path}/in.flac')..writeAsBytesSync(original);
      final target = '${temp.path}/out.flac';
      final cover = fakeJpeg(900);
      final ok = await TagWriter.writeTagged(
        source.path,
        target,
        TagData(
          title: 'New Title',
          artists: const ['A', 'B'],
          album: 'Album',
          trackNumber: 5,
          cover: TagPicture(bytes: cover, mime: 'image/jpeg'),
          lyrics: 'line one\nline two',
        ),
      );
      expect(ok, isTrue);
      final written = await File(target).readAsBytes();
      // ID3 prefix dropped, file starts with the FLAC marker.
      expect(written.matches(0, 'fLaC'), isTrue);
      final meta = await probe.probeFile(target);
      expect(meta.title, 'New Title');
      expect(meta.artist, 'A / B');
      expect(meta.album, 'Album');
      expect(meta.trackNumber, 5);
      expect(meta.duration, const Duration(seconds: 10));
      expect(meta.cover?.bytes, cover);
      // Audio frames are identical.
      expect(
        written.sublist(written.length - 2048),
        original.sublist(original.length - 2048),
      );
    });

    test('vorbis comment encoder layout', () {
      final body = FlacTagWriter.vorbisComment(
        const TagData(title: 'T', artists: ['X']),
      );
      // vendor length + 'aMusic' + count 2.
      expect(body.u32le(0), 6);
      expect(body.u32le(10), 2);
    });
  });

  group('M4A', () {
    test('moov after mdat: mvhd duration + ilst tags + covr', () async {
      final cover = fakeJpeg(300);
      final meta = await probe.probe(
        MemoryByteSource(
          m4aFile(title: '稻香', artist: '周杰伦', album: '魔杰座', cover: cover),
        ),
      );
      expect(meta.container, AudioContainer.m4a);
      expect(meta.duration, const Duration(seconds: 125));
      expect(meta.title, '稻香');
      expect(meta.artist, '周杰伦');
      expect(meta.album, '魔杰座');
      expect(meta.trackNumber, 7);
      expect(meta.cover?.bytes, cover);
    });

    test('moov first works too', () async {
      final meta = await probe.probe(
        MemoryByteSource(
          m4aFile(title: 'A', artist: 'B', album: 'C', moovLast: false),
        ),
      );
      expect(meta.title, 'A');
      expect(meta.duration, const Duration(seconds: 125));
    });
  });

  test('WAV duration and INFO title', () async {
    final meta = await probe.probe(
      MemoryByteSource(wavFile(seconds: 3, title: 'Rain')),
    );
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

  test('plainLyrics strips timestamps and metadata', () {
    expect(
      plainLyrics(
        '{"t":0,"c":[{"tx":"作词"}]}\n[ar:Jay]\n[00:01.00]A\n[00:02.50][00:09.00]B\n',
      ),
      'A\nB',
    );
    expect(plainLyrics(''), isNull);
  });

  test('TagPicture sniffing', () {
    expect(TagPicture.mimeOf(fakeJpeg()), 'image/jpeg');
    expect(
      TagPicture.mimeOf([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 0]),
      'image/png',
    );
    expect(TagPicture.mimeOf([1, 2, 3, 4]), isNull);
  });
}
