import 'dart:convert';
import 'dart:io';

import 'package:amusic/local/local_track.dart';
import 'package:amusic/services/local_library_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fixtures.dart';

void main() {
  late Directory temp;
  late Directory music;
  late Directory support;
  late Directory covers;

  setUp(() async {
    temp = await Directory.systemTemp.createTemp('amusic_local_');
    music = Directory('${temp.path}/Music')..createSync();
    support = Directory('${temp.path}/support')..createSync();
    covers = Directory('${temp.path}/covers');
    SharedPreferences.setMockInitialValues({});
  });

  tearDown(() async {
    if (await temp.exists()) await temp.delete(recursive: true);
  });

  Future<LocalLibraryService> create() async {
    final service = LocalLibraryService(
      prefs: await SharedPreferences.getInstance(),
      storageDirectory: () async => support,
      coverDirectory: () async => covers,
      defaultRoots: [music.path],
    );
    await service.init();
    return service;
  }

  test('scan, probe, covers, persistence, rescans and removal', () async {
    Directory('${music.path}/Jay/叶惠美').createSync(recursive: true);
    Directory('${music.path}/.hidden').createSync();
    Directory('${music.path}/node_modules').createSync();
    // 晴天 / 周杰伦 / 叶惠美, with an embedded cover.
    File('test/system/data/song.mp3').copySync(
      '${music.path}/Jay/叶惠美/01.mp3',
    );
    File('test/system/data/song.flac').copySync('${music.path}/Jay/夜曲.flac');
    File('${music.path}/王菲 - 红豆.wav').writeAsBytesSync(wavFile(seconds: 1));
    File('${music.path}/notes.txt').writeAsStringSync('not audio');
    File('${music.path}/.hidden/secret.mp3').writeAsBytesSync(mp3Frames(5));
    File('${music.path}/node_modules/x.mp3').writeAsBytesSync(mp3Frames(5));

    final service = await create();
    await service.scan();
    final songs = service.songs.value;
    expect(songs.map((s) => s.name).toSet(), {'晴天', '夜曲', '红豆'});
    expect(songs.every((s) => s.id < 0), isTrue);

    final sunny = songs.firstWhere((s) => s.name == '晴天');
    expect(sunny.artistText, '周杰伦');
    expect(sunny.album.name, '叶惠美');
    // Cover extracted into the cache and exposed as a file:// url.
    final coverPath = Uri.parse(sunny.album.picUrl!).toFilePath();
    expect(File(coverPath).existsSync(), isTrue);
    expect(coverPath, startsWith(covers.path));

    // File name fallback "artist - title".
    final redBean = songs.firstWhere((s) => s.name == '红豆');
    expect(redBean.artistText, '王菲');
    expect(redBean.duration, const Duration(seconds: 1));

    expect(service.pathFor(sunny.id), '${music.path}/Jay/叶惠美/01.mp3');
    expect(sunny.id, localIdForPath('${music.path}/Jay/叶惠美/01.mp3'));

    // Persisted library JSON, written atomically (no temp file left).
    final file = File('${support.path}/local_library.json');
    expect(file.existsSync(), isTrue);
    expect(File('${file.path}.tmp').existsSync(), isFalse);
    final json = jsonDecode(file.readAsStringSync()) as Map;
    expect((json['tracks'] as List), hasLength(3));

    // A restart restores the library without scanning.
    final restarted = await create();
    expect(restarted.songs.value, hasLength(3));
    expect(restarted.pathFor(sunny.id), isNotNull);

    // Incremental: unchanged files are reused (same `added` stamp), a
    // changed file is re-probed.
    final addedBefore = restarted.trackFor(sunny.id)!.added;
    await Future<void>.delayed(const Duration(milliseconds: 20));
    File('test/system/data/live.flac').copySync('${music.path}/Jay/夜曲.flac');
    await restarted.scan();
    expect(restarted.trackFor(sunny.id)!.added, addedBefore);
    expect(restarted.songs.value.map((s) => s.name), contains('夜曲 (Live)'));

    // Missing file detection + cleanup.
    File('${music.path}/王菲 - 红豆.wav').deleteSync();
    final third = await create();
    expect(third.songs.value, hasLength(2));
    expect(third.missing.value.single.title, '红豆');
    expect(third.pathFor(redBean.id), isNull);
    expect(await third.cleanupMissing(), 1);
    expect(third.missing.value, isEmpty);

    // Remove from library: the file stays, and a rescan does not re-add it.
    await third.remove(sunny.id);
    expect(third.songs.value.map((s) => s.name), isNot(contains('晴天')));
    expect(File('${music.path}/Jay/叶惠美/01.mp3').existsSync(), isTrue);
    expect(File(coverPath).existsSync(), isFalse);
    await third.scan();
    expect(third.songs.value.map((s) => s.name), isNot(contains('晴天')));

    // Delete file.
    final night = third.songs.value.first;
    await third.deleteFile(night.id);
    expect(File('${music.path}/Jay/夜曲.flac').existsSync(), isFalse);
    expect(third.songs.value, isEmpty);
  });

  test('ReplayGain survives a scan and a restart', () async {
    final path = '${music.path}/夜曲.flac';
    File('test/system/data/gain.flac').copySync(path);
    final service = await create();
    await service.scan();
    expect(service.songs.value.single.name, '夜曲');
    expect(service.replayGainFor(path), closeTo(-6.5, 0.01));
    // The gain is persisted with the library and read back without a rescan:
    // this is the value the engine asks for while playing.
    final restarted = await create();
    expect(restarted.replayGainFor(path), closeTo(-6.5, 0.01));
  });

  test('a library written by an older build is re-probed for ReplayGain', () async {
    final path = '${music.path}/夜曲.flac';
    File('test/system/data/gain.flac').copySync(path);
    final first = await create();
    await first.scan();
    expect(first.replayGainFor(path), closeTo(-6.5, 0.01));

    // Rewrite the store the way version 1 did: no `gain` key anywhere.
    final store = File('${support.path}/local_library.json');
    final json = jsonDecode(store.readAsStringSync()) as Map;
    for (final track in json['tracks'] as List) {
      (track as Map).remove('gain');
    }
    store.writeAsStringSync(jsonEncode({...json, 'version': 1}));

    final upgraded = await create();
    expect(upgraded.replayGainFor(path), isNull); // nothing scanned yet
    await upgraded.scan();
    // The file never changed, but the stored entry missed the gain.
    expect(upgraded.replayGainFor(path), closeTo(-6.5, 0.01));
  });

  test('scan progress is reported and depth is capped', () async {
    var dir = music.path;
    for (var i = 0; i < 10; i++) {
      dir = '$dir/d$i';
      Directory(dir).createSync();
      File('$dir/t$i.mp3').writeAsBytesSync(mp3Frames(3));
    }
    final service = await create();
    final states = <bool>[];
    service.scanState.addListener(
      () => states.add(service.scanState.value.scanning),
    );
    await service.scan();
    expect(states.first, isTrue);
    expect(states.last, isFalse);
    expect(service.scanState.value.message, isNotNull);
    // Files below depth 8 are skipped.
    expect(service.songs.value.length, 8);
  });
}
