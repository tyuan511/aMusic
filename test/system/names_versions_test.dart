import 'dart:io';

import 'package:amusic/local/file_names.dart';
import 'package:amusic/local/local_track.dart';
import 'package:amusic/local/release_version.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('sanitizeFileName', () {
    test('replaces reserved characters and control chars', () {
      expect(sanitizeFileName('a<b>c:d"e/f\\g|h?i*j'), 'a_b_c_d_e_f_g_h_i_j');
      expect(sanitizeFileName('tab\there\u0001x'), 'tab here_x');
    });

    test('strips trailing dots and spaces, collapses whitespace', () {
      expect(sanitizeFileName('  Song...  '), 'Song');
      expect(sanitizeFileName('A   B'), 'A B');
      expect(sanitizeFileName('...'), '未命名');
      expect(sanitizeFileName(''), '未命名');
    });

    test('caps at 120 characters without splitting surrogates', () {
      final long = '😀' * 200;
      final result = sanitizeFileName(long);
      expect(result.runes.length, 120);
      expect(result.runes.every((r) => r == 0x1F600), isTrue);
      expect(sanitizeFileName('a' * 119 + ' .x'), 'a' * 119);
    });

    test('reserved Windows device names', () {
      expect(sanitizeFileName('CON'), '_CON');
      expect(sanitizeFileName('lpt1'), '_lpt1');
      expect(sanitizeFileName('console'), 'console');
    });

    test('track stem joins artists', () {
      expect(trackFileStem(['周杰伦', '费玉清'], '千里之外'), '周杰伦, 费玉清 - 千里之外');
      expect(trackFileStem([], 'Solo'), 'Solo');
      expect(trackFileStem(['AC/DC'], 'T.N.T.'), 'AC_DC - T.N.T');
    });
  });

  group('uniqueFilePath', () {
    late Directory temp;

    setUp(() async {
      temp = await Directory.systemTemp.createTemp('amusic_names_');
    });

    tearDown(() async {
      await temp.delete(recursive: true);
    });

    test('appends (2), (3) when taken', () async {
      final first = await uniqueFilePath(
        temp.path,
        'A - B',
        'mp3',
        (c) => File(c).exists(),
      );
      expect(baseName(first), 'A - B.mp3');
      await File(first).writeAsString('x');
      final second = await uniqueFilePath(
        temp.path,
        'A - B',
        'mp3',
        (c) => File(c).exists(),
      );
      expect(baseName(second), 'A - B (2).mp3');
      await File(second).writeAsString('x');
      final third = await uniqueFilePath(
        temp.path,
        'A - B',
        'mp3',
        (c) => File(c).exists(),
      );
      expect(baseName(third), 'A - B (3).mp3');
    });

    test('a name owned by the same song is reused', () async {
      await File('${temp.path}/A - B.mp3').writeAsString('x');
      final path = await uniqueFilePath(
        temp.path,
        'A - B',
        'mp3',
        (c) async => false, // owner check says "mine"
      );
      expect(baseName(path), 'A - B.mp3');
    });
  });

  group('path helpers', () {
    test('extension / stem / dir', () {
      expect(extensionOf('/a/b/Song.FLAC'), 'flac');
      expect(extensionOf('/a/.hidden'), '');
      expect(stemOf('/a/b/x.y.mp3'), 'x.y');
      expect(dirName('/a/b/c.mp3'), '/a/b');
      expect(baseName(r'C:\Music\x.mp3'), 'x.mp3');
    });
  });

  group('local ids', () {
    test('negative and stable', () {
      const path = '/Users/me/Music/周杰伦 - 晴天.mp3';
      final id = localIdForPath(path);
      expect(id, isNegative);
      expect(localIdForPath(path), id);
      // Fits a JSON safe integer.
      expect(id.abs() < (1 << 53), isTrue);
    });

    test('different paths -> different ids', () {
      final ids = {
        for (var i = 0; i < 2000; i++) localIdForPath('/music/track $i.mp3'),
      };
      expect(ids.length, 2000);
    });

    test('case and separators follow the platform', () {
      final a = localIdForPath('/Music/A.mp3');
      final b = localIdForPath('/music/a.mp3');
      if (Platform.isMacOS || Platform.isWindows) {
        expect(a, b);
      } else {
        expect(a, isNot(b));
      }
    });

    test('LocalTrack json round trip + song mapping', () {
      final track = LocalTrack(
        path: '/m/x.flac',
        title: 'T',
        artist: 'A / B',
        album: 'Al',
        duration: const Duration(seconds: 90),
        size: 1234,
        modified: DateTime.fromMillisecondsSinceEpoch(1000),
        added: DateTime.fromMillisecondsSinceEpoch(2000),
        trackNumber: 4,
        coverPath: '/cache/c d.jpg',
        source: LocalTrackSource.import,
        format: 'flac',
      );
      final copy = LocalTrack.fromJson(track.toJson())!;
      expect(copy.toJson(), track.toJson());
      final song = copy.toSong();
      expect(song.id, localIdForPath('/m/x.flac'));
      expect(song.artists.map((a) => a.name), ['A', 'B']);
      expect(song.artists.every((a) => a.id < 0), isTrue);
      expect(song.album.picUrl, Uri.file('/cache/c d.jpg').toString());
      expect(Uri.parse(song.album.picUrl!).toFilePath(), '/cache/c d.jpg');
      expect(song.no, 4);
    });
  });

  group('ReleaseVersion', () {
    ReleaseVersion v(String s) => ReleaseVersion.parse(s)!;

    test('parses tags, build metadata and short forms', () {
      expect(v('v2.1').toString(), '2.1.0');
      expect(v('2.0.0+20').toString(), '2.0.0');
      expect(v('V3.0.0-beta.2').toString(), '3.0.0-beta.2');
      expect(ReleaseVersion.parse('main'), isNull);
      expect(ReleaseVersion.parse('1.2.3.4'), isNull);
      expect(ReleaseVersion.parse('1.0.0-'), isNull);
    });

    test('semver precedence', () {
      final ordered = [
        '1.0.0-alpha',
        '1.0.0-alpha.1',
        '1.0.0-alpha.beta',
        '1.0.0-beta',
        '1.0.0-beta.2',
        '1.0.0-beta.11',
        '1.0.0-rc.1',
        '1.0.0',
        '1.0.1',
        '1.1.0',
        '2.0.0',
      ];
      for (var i = 0; i + 1 < ordered.length; i++) {
        expect(
          v(ordered[i]) < v(ordered[i + 1]),
          isTrue,
          reason: '${ordered[i]} < ${ordered[i + 1]}',
        );
      }
      expect(v('2.0.0') == v('v2.0.0+99'), isTrue);
    });

    test('isNewerVersion', () {
      expect(isNewerVersion('v2.0.1', '2.0.0'), isTrue);
      expect(isNewerVersion('2.0.0', '2.0.0'), isFalse);
      expect(isNewerVersion('2.0.0-beta.1', '2.0.0'), isFalse);
      expect(isNewerVersion('2.0.0', '2.0.0-beta.3'), isTrue);
      expect(isNewerVersion('garbage', '1.0.0'), isFalse);
    });
  });
}
