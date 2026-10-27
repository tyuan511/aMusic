import 'dart:convert';

import 'package:amusic/core/format.dart';
import 'package:amusic/core/prefs.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/services/settings_service.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  test('settings persist only changed keys; volume is debounced', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs, readSettings(prefs));

    settings.setThemeMode(ThemeMode.light);
    expect(prefs.getKeys(), {PrefsKeys.themeMode});

    for (var i = 1; i <= 20; i++) {
      settings.setVolume(i / 20);
    }
    expect(prefs.getDouble(PrefsKeys.volume), isNull);
    await Future<void>.delayed(const Duration(milliseconds: 450));
    expect(prefs.getDouble(PrefsKeys.volume), 1.0);

    settings.update((s) => s.copyWith(downloadDirectory: '/tmp/x'));
    expect(prefs.getString(PrefsKeys.downloadDirectory), '/tmp/x');
    settings.update((s) => s.copyWith(clearDownloadDirectory: true));
    expect(prefs.containsKey(PrefsKeys.downloadDirectory), isFalse);

    // Reading back yields the same state.
    final restored = readSettings(prefs);
    expect(restored.themeMode, ThemeMode.light);
    expect(restored.volume, 1.0);
  });

  test('snapshot encode reuses the queue json and stays decodable', () {
    final songs = [
      for (var i = 1; i <= 3; i++)
        Song.fromJson({
          'id': i,
          'name': 'song $i',
          'dt': 1000,
          'ar': [
            {'id': 1, 'name': 'A'},
          ],
          'al': {'id': 2, 'name': 'B', 'picUrl': 'u'},
        }),
    ];
    final a = PlaybackSnapshot(songs: songs, index: 1).encode();
    final b = PlaybackSnapshot(
      songs: songs,
      index: 2,
      position: const Duration(seconds: 5),
      sourceTitle: '歌单 "x"',
    ).encode();
    expect(jsonDecode(a)['index'], 1);
    final decoded = PlaybackSnapshot.decode(b)!;
    expect(decoded.songs.map((s) => s.id), [1, 2, 3]);
    expect(decoded.index, 2);
    expect(decoded.position, const Duration(seconds: 5));
    expect(decoded.sourceTitle, '歌单 "x"');
    expect(const PlaybackSnapshot().encode(), contains('"songs":[]'));
  });

  test('remainingClock prints a single leading minus', () {
    expect(const Duration(minutes: 2, seconds: 15).remainingClock, '-2:15');
    expect(Duration.zero.remainingClock, '-0:00');
    expect(const Duration(seconds: -3).remainingClock, '-0:00');
  });
}
