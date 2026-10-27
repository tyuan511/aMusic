import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/audio/resolving_source.dart';
import 'package:amusic/core/errors.dart';
import 'package:amusic/data/ncm_api.dart';
import 'package:amusic/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

/// A tiny CDN stand-in that honours single `Range` headers like the NetEase
/// audio hosts do, and records what it was asked for.
class _FakeCdn {
  _FakeCdn(this.body);

  final Uint8List body;
  final List<String?> ranges = [];
  int status = HttpStatus.ok;
  late final HttpServer _server;

  String get url => 'http://${_server.address.host}:${_server.port}/a.mp3';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final range = request.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final response = request.response;
      if (status != HttpStatus.ok) {
        response.statusCode = status;
        await response.close();
        return;
      }
      response.headers
        ..contentType = ContentType('audio', 'mpeg')
        ..set(HttpHeaders.acceptRangesHeader, 'bytes');
      final match = range == null
          ? null
          : RegExp(r'^bytes=(\d+)-(\d*)$').firstMatch(range);
      if (match == null) {
        response.contentLength = body.length;
        response.add(body);
      } else {
        final first = int.parse(match[1]!);
        final last = match[2]!.isEmpty ? body.length - 1 : int.parse(match[2]!);
        response
          ..statusCode = HttpStatus.partialContent
          ..contentLength = last - first + 1
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $first-$last/${body.length}',
          );
        response.add(body.sublist(first, last + 1));
      }
      await response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

const _song = Song(
  id: 1,
  name: 'probe',
  artists: [],
  album: AlbumRef(id: 0, name: ''),
  duration: Duration(seconds: 1),
);

Future<List<int>> _collect(Stream<List<int>> stream) async => [
  for (final chunk in await stream.toList()) ...chunk,
];

void main() {
  late _FakeCdn cdn;
  late HttpClient client;
  final body = Uint8List.fromList(List.generate(1000, (i) => i % 251));

  ResolvingAudioSource source() => ResolvingAudioSource(
    song: _song,
    httpClient: client,
    levelProvider: () => AudioLevel.exhigh,
    resolver: (song, level) async => PlayUrl(url: cdn.url),
  );

  setUp(() async {
    cdn = _FakeCdn(body);
    await cdn.start();
    client = HttpClient();
  });

  tearDown(() async {
    client.close(force: true);
    await cdn.stop();
  });

  test('the AVPlayer probe range reports the full file length', () async {
    // AVPlayer opens with `Range: bytes=0-1`; the proxy passes end exclusive.
    final response = await source().request(0, 2);
    expect(cdn.ranges.single, 'bytes=0-1');
    expect(response.sourceLength, body.length);
    expect(response.contentLength, 2);
    expect(response.offset, 0);
    expect(await _collect(response.stream), body.sublist(0, 2));
  });

  test('an open ended range from the middle keeps offset and total', () async {
    final response = await source().request(600);
    expect(cdn.ranges.single, 'bytes=600-');
    expect(response.sourceLength, body.length);
    expect(response.contentLength, 400);
    expect(response.offset, 600);
    expect(await _collect(response.stream), body.sublist(600));
  });

  test('a plain request streams the whole file', () async {
    final response = await source().request();
    expect(cdn.ranges.single, isNull);
    expect(response.offset, isNull);
    expect(response.contentLength, body.length);
    expect(await _collect(response.stream), body);
  });

  test('a forbidden stream url surfaces as unavailable', () async {
    cdn.status = HttpStatus.forbidden;
    await expectLater(
      source().request(0, 2),
      throwsA(isA<SongUnavailableException>()),
    );
  });

  test('parseContentRange', () {
    expect(parseContentRange('bytes 0-1/5000'), (
      start: 0,
      end: 1,
      total: 5000,
    ));
    expect(parseContentRange('bytes 10-20/*'), (
      start: 10,
      end: 20,
      total: null,
    ));
    expect(parseContentRange('nonsense'), isNull);
    expect(parseContentRange(null), isNull);
  });
}
