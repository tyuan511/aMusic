import 'dart:convert';

import 'package:amusic/core/prefs.dart';
import 'package:amusic/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Map<String, dynamic> track(int id) => {
    'id': id,
    'name': 'song $id',
    'dt': 1000,
    'fee': 8,
    'ar': [
      {'id': 1, 'name': 'A'},
    ],
    'al': {'id': 2, 'name': 'B', 'picUrl': 'u'},
  };

  test('a queue persisted by older builds with st=-1 restores as playable', () {
    // Older builds wrote `st: -1` for every track, which marked the whole
    // restored queue as taken down and made the player skip forever.
    final raw = jsonEncode({
      'songs': [
        for (var i = 1; i <= 3; i++) {...track(i), 'st': -1},
      ],
      'index': 1,
      'position': 0,
      'repeat': 'all',
      'shuffle': false,
    });
    final snapshot = PlaybackSnapshot.decode(raw)!;
    expect(snapshot.songs, hasLength(3));
    expect(snapshot.songs.every((song) => song.playable), isTrue);
    expect(snapshot.index, 1);
  });

  test('encode no longer persists a playability flag', () {
    final song = Song.fromJson(track(7), privilege: {'code': 404});
    expect(song.playable, isFalse);
    final raw = PlaybackSnapshot(songs: [song]).encode();
    final stored = (jsonDecode(raw) as Map<String, dynamic>)['songs'] as List;
    expect((stored.single as Map).containsKey('st'), isFalse);
    expect(PlaybackSnapshot.decode(raw)!.songs.single.id, 7);
  });
}
