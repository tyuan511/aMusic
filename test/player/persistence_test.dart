import 'dart:convert';
import 'dart:io';

import 'package:amusic/audio/audio_cache.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/services/recent_service.dart';
import 'package:amusic/services/scrobble_queue.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

Song _song(int id) => Song(
  id: id,
  name: 'song $id',
  artists: const [Artist(id: 1, name: 'A')],
  album: const AlbumRef(id: 2, name: 'B', picUrl: 'http://x/y.jpg'),
  duration: const Duration(seconds: 200),
);

void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  group('ScrobbleQueue', () {
    test('a failed report stays queued, persisted and is retried', () async {
      final prefs = await SharedPreferences.getInstance();
      var fail = true;
      final sent = <int>[];
      final queue = ScrobbleQueue(
        prefs: prefs,
        retryDelay: const Duration(hours: 1),
        send: (id, source, seconds) async {
          if (fail) throw const SocketException('offline');
          sent.add(id);
        },
      );
      queue.add(const ScrobbleEntry(songId: 1, sourceId: 9, seconds: 31));
      await queue.flush();
      queue.add(const ScrobbleEntry(songId: 2, seconds: 40));
      await queue.flush();
      expect(queue.pending.map((e) => e.songId), [1, 2]);
      final stored = jsonDecode(prefs.getString(ScrobbleQueue.prefsKey)!);
      expect((stored as List).length, 2);

      // A new process picks the queue up again.
      queue.dispose();
      fail = false;
      final revived = ScrobbleQueue(
        prefs: prefs,
        send: (id, source, seconds) async => sent.add(id),
      );
      expect(revived.pending.first.sourceId, 9);
      await revived.flush();
      expect(sent, [1, 2]);
      expect(revived.pending, isEmpty);
      expect(prefs.getString(ScrobbleQueue.prefsKey), isNull);
      revived.dispose();
    });

    test('keeps at most 50 entries, dropping the oldest', () async {
      final prefs = await SharedPreferences.getInstance();
      final queue = ScrobbleQueue(
        prefs: prefs,
        retryDelay: const Duration(hours: 1),
        send: (id, source, seconds) async => throw Exception('down'),
      );
      for (var i = 0; i < 60; i++) {
        queue.add(ScrobbleEntry(songId: i, seconds: 30));
      }
      await queue.flush();
      expect(queue.pending, hasLength(ScrobbleQueue.maxEntries));
      expect(queue.pending.first.songId, 10);
      queue.dispose();
    });
  });

  group('RecentService', () {
    test('newest first, deduplicated, persisted, capped at 100', () async {
      final prefs = await SharedPreferences.getInstance();
      final recent = RecentService(prefs: prefs);
      await recent.init();
      recent
        ..record(_song(1))
        ..record(_song(2))
        ..record(_song(1));
      expect(recent.tracks.value.map((s) => s.id), [1, 2]);

      final reloaded = RecentService(prefs: prefs);
      await reloaded.init();
      expect(reloaded.tracks.value.map((s) => s.id), [1, 2]);
      expect(reloaded.tracks.value.first.album.picUrl, 'http://x/y.jpg');

      for (var i = 10; i < 130; i++) {
        reloaded.record(_song(i));
      }
      expect(reloaded.tracks.value, hasLength(RecentService.maxTracks));
      expect(reloaded.tracks.value.first.id, 129);

      reloaded.clear();
      expect(prefs.getString(RecentService.prefsKey), isNull);
    });

    test('a corrupt entry is dropped', () async {
      SharedPreferences.setMockInitialValues({RecentService.prefsKey: '{x'});
      final prefs = await SharedPreferences.getInstance();
      final recent = RecentService(prefs: prefs);
      await recent.init();
      expect(recent.tracks.value, isEmpty);
    });
  });

  group('AudioCache', () {
    late Directory dir;

    setUp(() async => dir = await Directory.systemTemp.createTemp('cache'));
    tearDown(() async => dir.delete(recursive: true));

    test('commits complete files, discards partial ones, trims LRU', () async {
      var limit = 10000;
      final cache = AudioCache(
        maxBytes: () => limit,
        directory: () async => dir,
      );
      final a = (await cache.openWriter(
        'a',
        expectedLength: 3000,
        level: 'exhigh',
      ))!;
      a.add(List.filled(3000, 1));
      await a.commit();
      final hit = await cache.lookup('a');
      expect(hit!.length, 3000);
      expect(hit.level, 'exhigh');

      final partial = (await cache.openWriter('p', expectedLength: 3000))!;
      partial.add(List.filled(100, 1));
      await partial.commit();
      expect(await cache.lookup('p'), isNull);

      await File('${dir.path}/a.audio')
          .setLastModified(DateTime.now().subtract(const Duration(days: 1)));
      final b = (await cache.openWriter('b', expectedLength: 3000))!;
      b.add(List.filled(3000, 2));
      await b.commit();
      expect(await cache.size(), greaterThanOrEqualTo(6000));

      limit = 4000;
      await cache.trim();
      expect(await cache.lookup('a'), isNull);
      expect(await cache.lookup('b'), isNotNull);

      await cache.clear();
      expect(await cache.size(), 0);
    });

    test('disabled at 0 MB', () async {
      final cache = AudioCache(maxBytes: () => 0, directory: () async => dir);
      expect(await cache.openWriter('a', expectedLength: 10), isNull);
      expect(await cache.lookup('a'), isNull);
    });
  });
}
