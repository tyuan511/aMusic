import 'package:amusic/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Song.fromJson', () {
    test('parses the modern ar/al/dt shape', () {
      final song = Song.fromJson({
        'id': 347230,
        'name': '海阔天空',
        'dt': 326000,
        'fee': 1,
        'ar': [
          {'id': 11127, 'name': 'Beyond'},
        ],
        'al': {
          'id': 34209,
          'name': '海阔天空',
          'picUrl': 'https://example.com/a.jpg',
        },
        'alia': ['Live'],
      });
      expect(song.id, 347230);
      expect(song.artistText, 'Beyond');
      expect(song.album.name, '海阔天空');
      expect(song.duration, const Duration(milliseconds: 326000));
      expect(song.fee, SongFee.vip);
      expect(song.displayTitle, '海阔天空 (Live)');
      expect(song.playable, isTrue);
    });

    test('parses the legacy artists/album shape', () {
      final song = Song.fromJson({
        'id': 1,
        'name': 'legacy',
        'duration': 1000,
        'artists': [
          {'id': 2, 'name': 'A'},
          {'id': 3, 'name': 'B'},
        ],
        'album': {'id': 4, 'name': 'Al'},
      });
      expect(song.artistText, 'A / B');
      expect(song.album.name, 'Al');
      expect(song.duration, const Duration(seconds: 1));
    });

    test('marks greyed out tracks as unplayable', () {
      expect(
        Song.fromJson({'id': 1, 'name': 'x', 'st': -200}).playable,
        isFalse,
      );
      expect(
        Song.fromJson(
          {'id': 1, 'name': 'x'},
          privilege: {'code': 404},
        ).playable,
        isFalse,
      );
      expect(
        Song.fromJson(
          {'id': 1, 'name': 'x'},
          privilege: {'code': 200, 'pl': 320000},
        ).playable,
        isTrue,
      );
    });

    test('applies privileges passed alongside the tracks', () {
      final songs = Song.listFrom(
        [
          {'id': 1, 'name': 'a'},
          {'id': 2, 'name': 'b'},
        ],
        privileges: [
          {'code': 200, 'pl': 320000},
          {'code': 404, 'pl': 0},
        ],
      );
      expect(songs[0].playable, isTrue);
      expect(songs[1].playable, isFalse);
    });

    test('round trips through json', () {
      final song = Song.fromJson({
        'id': 9,
        'name': 'round',
        'dt': 5000,
        'ar': [
          {'id': 1, 'name': 'X'},
        ],
        'al': {'id': 2, 'name': 'Y', 'picUrl': 'u'},
      });
      final restored = Song.fromJson(song.toJson());
      expect(restored.id, song.id);
      expect(restored.name, song.name);
      expect(restored.artistText, 'X');
      expect(restored.album.picUrl, 'u');
      expect(restored.duration, song.duration);
    });
  });

  test('AudioLevel.fromValue falls back to exhigh', () {
    expect(AudioLevel.fromValue('lossless'), AudioLevel.lossless);
    expect(AudioLevel.fromValue('nonsense'), AudioLevel.exhigh);
    expect(AudioLevel.fromValue(null), AudioLevel.exhigh);
  });
}
