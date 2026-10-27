import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/audio/audio_cache.dart';
import 'package:amusic/audio/resolving_source.dart';
import 'package:amusic/data/ncm_api.dart';
import 'package:amusic/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

const _song = Song(
  id: 7,
  name: 'cached',
  artists: [],
  album: AlbumRef(id: 0, name: ''),
  duration: Duration(seconds: 1),
);

void main() {
  late HttpServer server;
  late Directory dir;
  final body = Uint8List.fromList(List.generate(4000, (i) => i % 233));
  var hits = 0;

  setUp(() async {
    hits = 0;
    dir = await Directory.systemTemp.createTemp('rcache');
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) async {
      hits++;
      request.response
        ..headers.contentType = ContentType('audio', 'mpeg')
        ..contentLength = body.length
        ..add(body);
      await request.response.close();
    });
  });

  tearDown(() async {
    await server.close(force: true);
    await dir.delete(recursive: true);
  });

  test(
    'a complete download is cached and later ranges come from disk',
    () async {
      final client = HttpClient();
      final cache = AudioCache(
        maxBytes: () => 1 << 20,
        directory: () async => dir,
      );
      final resolved = <String?>[];
      ResolvingAudioSource source() => ResolvingAudioSource(
        song: _song,
        httpClient: client,
        levelProvider: () => AudioLevel.exhigh,
        resolver: (song, level) async => PlayUrl(
          url: 'http://127.0.0.1:${server.port}/a.mp3',
          level: 'exhigh',
        ),
        onResolved: (song, url) => resolved.add(url.level),
        cache: cache,
      );

      final first = await source().request();
      final bytes = [for (final chunk in await first.stream.toList()) ...chunk];
      expect(bytes, body);
      // Commit runs after the stream closes.
      for (var i = 0; i < 20 && await cache.lookup('7_exhigh') == null; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 20));
      }
      expect(await cache.lookup('7_exhigh'), isNotNull);

      final ranged = await source().request(100, 200);
      expect(hits, 1);
      expect(ranged.sourceLength, body.length);
      expect(ranged.offset, 100);
      expect(ranged.contentLength, 100);
      final slice = [
        for (final chunk in await ranged.stream.toList()) ...chunk,
      ];
      expect(slice, body.sublist(100, 200));
      expect(resolved.last, 'exhigh');
      client.close(force: true);
    },
  );
}
