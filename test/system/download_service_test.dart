import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/core/prefs.dart';
import 'package:amusic/local/audio_probe.dart';
import 'package:amusic/local/tags/id3_writer.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/services/api_host.dart';
import 'package:amusic/services/download_service.dart';
import 'package:amusic/services/settings_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

Song _song(int id, String name, {String artist = '周杰伦', int? no}) => Song(
  id: id,
  name: name,
  artists: [Artist(id: 1, name: artist)],
  album: const AlbumRef(id: 9, name: '叶惠美'),
  duration: const Duration(seconds: 3),
  no: no,
);

/// Serves `/<id>.mp3` with Range support and records requests.
class _AudioServer {
  _AudioServer(this.files);

  final Map<String, Uint8List> files;
  final List<String?> ranges = [];
  late HttpServer _server;

  String url(String name) => 'http://127.0.0.1:${_server.port}/$name';

  Future<void> start() async {
    _server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    _server.listen((request) async {
      final name = request.uri.pathSegments.last;
      final body = files[name];
      final range = request.headers.value(HttpHeaders.rangeHeader);
      ranges.add(range);
      final response = request.response;
      if (body == null) {
        response.statusCode = 404;
        await response.close();
        return;
      }
      final match = RegExp(r'bytes=(\d+)-').firstMatch(range ?? '');
      if (match != null) {
        final start = int.parse(match.group(1)!);
        if (start >= body.length) {
          response.statusCode = 416;
          await response.close();
          return;
        }
        response
          ..statusCode = 206
          ..headers.set(
            HttpHeaders.contentRangeHeader,
            'bytes $start-${body.length - 1}/${body.length}',
          )
          ..contentLength = body.length - start
          ..add(body.sublist(start));
      } else {
        response
          ..statusCode = 200
          ..contentLength = body.length
          ..add(body);
      }
      await response.close();
    });
  }

  Future<void> stop() => _server.close(force: true);
}

void main() {
  late Directory temp;
  late _AudioServer server;
  final audioA = mp3Frames(60);
  final audioB = mp3Frames(80);

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('amusic_dl_');
    server = _AudioServer({'1.mp3': audioA, '2.mp3': audioB, '3.mp3': audioA});
    await server.start();
  });

  tearDown(() async {
    await server.stop();
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<DownloadService> create(
    SharedPreferences prefs, {
    AudioLevel granted = AudioLevel.exhigh,
  }) async {
    final settings = SettingsService(prefs, readSettings(prefs));
    final service = DownloadService(
      host: ApiHost(prefs: prefs),
      settings: settings,
      prefs: prefs,
      autoStart: false,
      defaultDirectory: () async => Directory('${temp.path}/aMusic'),
      fetchLyrics: (_) async => '[00:01.00]第一行\n[00:02.00]第二行',
      resolveSource: (song, level) async => (
        url: server.url('${song.id}.mp3'),
        level: granted,
        type: 'mp3',
        size: server.files['${song.id}.mp3']?.length,
        trial: false,
      ),
    );
    await service.init();
    return service;
  }

  test('downloads, tags, and persists queue + finished index', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = await create(prefs, granted: AudioLevel.higher);

    await service.enqueue([
      _song(1, '晴天', no: 3),
      _song(2, '七里香'),
    ], folder: '我的/歌单');
    // Queue persisted before anything ran.
    final queued =
        jsonDecode(prefs.getString(DownloadService.tasksKey)!) as List;
    expect(queued, hasLength(2));
    expect(service.progressOf(1), 0);

    await service.runQueue();
    expect(service.tasks, isEmpty);
    expect(service.isDownloaded(1), isTrue);
    expect(service.isDownloaded(2), isTrue);
    final path = service.localPathFor(1)!;
    expect(
      path,
      endsWith(
        '${Platform.pathSeparator}我的_歌单${Platform.pathSeparator}周杰伦 - 晴天.mp3',
      ),
    );
    expect(service.progressOf(1), 1);

    // Requested exhigh, server granted higher -> 降级.
    final record = service.recordFor(1)!;
    expect(record.downgraded, isTrue);
    expect(record.level, AudioLevel.higher);
    expect(record.tagged, isTrue);

    // Tags written, audio intact, no leftovers.
    final meta = await const AudioProbe().probeFile(path);
    expect(meta.title, '晴天');
    expect(meta.artist, '周杰伦');
    expect(meta.album, '叶惠美');
    expect(meta.trackNumber, 3);
    final bytes = await File(path).readAsBytes();
    expect(bytes.sublist(Id3v2Writer.tagSize(bytes)), audioA);
    final leftovers = Directory(File(path).parent.path)
        .listSync()
        .where((e) => e.path.endsWith('.part') || e.path.endsWith('.tagging'));
    expect(leftovers, isEmpty);

    // A fresh service (app restart) restores the finished index.
    final restarted = await create(prefs);
    expect(restarted.localPathFor(1), path);
    expect(restarted.finished, hasLength(2));

    // Files deleted behind the app's back are dropped on init.
    await File(path).delete();
    final again = await create(prefs);
    expect(again.isDownloaded(1), isFalse);
    expect(again.isDownloaded(2), isTrue);
  });

  test('queue survives a restart and resumes a .part with Range', () async {
    final song = _song(1, '晴天');
    final dir = Directory('${temp.path}/aMusic')..createSync(recursive: true);
    final target = '${dir.path}${Platform.pathSeparator}周杰伦 - 晴天.mp3';
    final half = audioA.length ~/ 2;
    await File('$target.part').writeAsBytes(audioA.sublist(0, half));
    SharedPreferences.setMockInitialValues({
      DownloadService.tasksKey: jsonEncode([
        {
          'song': song.toJson(),
          // Was running when the app died.
          'status': 'downloading',
          'received': half,
          'total': audioA.length,
          'part': '$target.part',
        },
      ]),
    });
    final prefs = await SharedPreferences.getInstance();
    final service = await create(prefs);
    expect(service.tasks.single.status, DownloadStatus.queued);
    expect(service.progressOf(1), closeTo(0.5, 0.01));

    await service.runQueue();
    expect(server.ranges.first, 'bytes=$half-');
    expect(service.localPathFor(1), target);
    final bytes = await File(target).readAsBytes();
    expect(bytes.sublist(Id3v2Writer.tagSize(bytes)), audioA);
    expect(File('$target.part').existsSync(), isFalse);
  });

  test('a different song with the same name gets " (2)"', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = await create(prefs);
    // An unrelated file the user already has.
    final dir = Directory('${temp.path}/aMusic')..createSync(recursive: true);
    final existing = File('${dir.path}/周杰伦 - 晴天.mp3')
      ..writeAsStringSync('mine');

    await service.enqueue([_song(1, '晴天'), _song(3, '晴天')]);
    await service.runQueue();
    final a = service.localPathFor(1)!;
    final b = service.localPathFor(3)!;
    expect({a, b}.length, 2);
    expect({a, b}.map((p) => p.split(Platform.pathSeparator).last), {
      '周杰伦 - 晴天 (2).mp3',
      '周杰伦 - 晴天 (3).mp3',
    });
    // The user's file was not touched.
    expect(existing.readAsStringSync(), 'mine');

    // Removed with its file: a new download takes the freed name again.
    await service.remove(1, deleteFile: true);
    await service.enqueue([_song(1, '晴天')]);
    await service.runQueue();
    expect(service.localPathFor(1), a);
    final names = dir
        .listSync()
        .map((e) => e.path.split(Platform.pathSeparator).last)
        .toSet();
    expect(names.where((n) => n.endsWith('.mp3')), hasLength(3));
  });

  test('failure is reported, retry works, cancel and remove', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = await create(prefs);
    await service.enqueue([_song(404, 'Missing')]);
    await service.runQueue();
    final task = service.taskFor(404)!;
    expect(task.status, DownloadStatus.failed);
    expect(task.error, contains('404'));
    expect(service.progressOf(404), isNull);

    // Persisted as failed, kept across restarts.
    final restarted = await create(prefs);
    expect(restarted.taskFor(404)?.status, DownloadStatus.failed);

    await service.remove(404);
    expect(service.tasks, isEmpty);

    await service.enqueue([_song(2, '七里香')]);
    await service.cancel(2);
    expect(service.taskFor(2)?.status, DownloadStatus.canceled);
    service.retry(2);
    await service.runQueue();
    expect(service.isDownloaded(2), isTrue);

    await service.clearFinished(deleteFiles: true);
    expect(service.finished, isEmpty);
    expect(jsonDecode(prefs.getString(DownloadService.doneKey)!), isEmpty);
  });

  test('notifications are throttled while bytes flow', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    server.files['5.mp3'] = mp3Frames(4000); // ~1.6 MB
    final service = await create(prefs);
    var count = 0;
    service.addListener(() => count++);
    final watch = Stopwatch()..start();
    await service.enqueue([_song(5, 'Big')]);
    await service.runQueue();
    watch.stop();
    expect(service.isDownloaded(5), isTrue);
    // Structural events (~4) + at most 10 progress ticks per second.
    final budget = 6 + (watch.elapsedMilliseconds / 100).ceil();
    expect(count, lessThanOrEqualTo(budget));
  });

  test('unwritable directory fails with a clear message', () async {
    SharedPreferences.setMockInitialValues({
      PrefsKeys.downloadDirectory: '${temp.path}/file_not_dir/sub',
    });
    File('${temp.path}/file_not_dir').writeAsStringSync('x');
    final prefs = await SharedPreferences.getInstance();
    final service = await create(prefs);
    await service.enqueue([_song(1, '晴天')]);
    await service.runQueue();
    expect(service.taskFor(1)?.status, DownloadStatus.failed);
    expect(service.taskFor(1)?.error, contains('下载目录不可写'));
  });

  test('a download deleted outside the app self-heals', () async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    final service = await create(prefs);

    await service.enqueue([_song(1, '晴天')]);
    await service.runQueue();
    final path = service.localPathFor(1)!;
    expect(service.verifiedPathFor(1), path);

    // Deleted outside the app: the player falls back to streaming.
    await File(path).delete();
    expect(service.verifiedPathFor(1), isNull);
    expect(service.isDownloaded(1), isFalse);
    final done = jsonDecode(prefs.getString(DownloadService.doneKey)!) as Map;
    expect(done.containsKey('1'), isFalse);
  });
}
