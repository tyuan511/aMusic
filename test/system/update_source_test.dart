import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:amusic/services/update_service.dart';
import 'package:amusic/services/update_source.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Routes by URL: [routes] maps a URL prefix to (status, body).
class _Router implements HttpClientAdapter {
  _Router(this.routes);

  final Map<String, (int, List<int>)> routes;
  final List<String> requested = [];

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final url = options.uri.toString();
    requested.add(url);
    for (final entry in routes.entries) {
      if (url == entry.key) {
        final (status, body) = entry.value;
        return ResponseBody.fromBytes(
          body,
          status,
          headers: {
            Headers.contentTypeHeader: [Headers.jsonContentType],
            Headers.contentLengthHeader: ['${body.length}'],
          },
        );
      }
    }
    return ResponseBody.fromString('no route', 502);
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  const api = 'https://api.github.com/repos/tyuan511/amusic/releases/latest';
  final payload = utf8.encode(
    jsonEncode({
      'tag_name': 'v2.1.0',
      'html_url': 'https://github.com/tyuan511/amusic/releases/tag/v2.1.0',
      'body': 'notes',
      'assets': [
        {
          'name': 'aMusic-windows-x64.zip',
          'browser_download_url': 'https://github.com/tyuan511/amusic/releases/download/v2.1.0/aMusic-windows-x64.zip',
          'size': 5,
        },
      ],
    }),
  );

  Future<UpdateService> create(
    _Router router, {
    Map<String, Object> prefs = const {},
    Directory? dir,
  }) async {
    SharedPreferences.setMockInitialValues(prefs);
    return UpdateService(
      prefs: await SharedPreferences.getInstance(),
      dio: Dio()..httpClientAdapter = router,
      currentVersion: () async => '2.0.0',
      downloadDir: dir == null ? null : () async => dir,
      os: 'windows',
    );
  }

  test('normalizeMirrorPrefix', () {
    expect(
      normalizeMirrorPrefix('https://gh.example.com'),
      'https://gh.example.com/',
    );
    expect(normalizeMirrorPrefix(' http://h:8080/p?x=1 '), 'http://h:8080/p/');
    expect(normalizeMirrorPrefix('ftp://x'), isNull);
    expect(normalizeMirrorPrefix('nonsense'), isNull);
  });

  test('source persists and mirror falls back to the official api', () async {
    final router = _Router({api: (200, payload)});
    final service = await create(router, prefs: {'update.source': 'ghfast'});
    expect(service.config.value.source, UpdateSource.ghfast);

    final release = await service.checkNow();
    expect(release?.version, '2.1.0');
    // The mirror 502s on the API path, so the official host answers.
    expect(router.requested, ['https://ghfast.top/$api', api]);
  });

  test('auto tries the mirrors in order and works with them', () async {
    final router = _Router({'https://gh-proxy.com/$api': (200, payload)});
    final service = await create(router, prefs: {'update.source': 'auto'});
    expect((await service.checkNow())?.version, '2.1.0');
    expect(service.lastChannel?.label, 'gh-proxy.com');
  });

  test(
    'custom prefix is saved normalized and selects the custom source',
    () async {
      final router = _Router({});
      final service = await create(router);
      await service.setCustomPrefix('https://m.example.com');
      expect(service.config.value.source, UpdateSource.custom);
      expect(service.config.value.customPrefix, 'https://m.example.com/');
      expect(
        service.config.value.channels().single.prefix,
        'https://m.example.com/',
      );
    },
  );

  test('every channel failing reports an error', () async {
    final service = await create(_Router({}));
    expect(service.checkNow(), throwsException);
  });

  test('download goes through the mirror and lands in the directory', () async {
    final dir = await Directory.systemTemp.createTemp('amusic_update_test');
    addTearDown(() => dir.delete(recursive: true));
    const asset =
        'https://github.com/tyuan511/amusic/releases/download/v2.1.0/aMusic-windows-x64.zip';
    final router = _Router({
      'https://gh-proxy.com/$api': (200, payload),
      'https://gh-proxy.com/$asset': (200, utf8.encode('hello')),
    });
    final service = await create(
      router,
      prefs: {'update.source': 'ghProxy'},
      dir: dir,
    );
    final release = (await service.checkNow())!;
    await service.startDownload(release);
    final state = service.download.value;
    expect(state.status, UpdateDownloadStatus.ready);
    expect(await state.file!.readAsString(), 'hello');
  });

  test('a wrong size is rejected', () async {
    final dir = await Directory.systemTemp.createTemp('amusic_update_test');
    addTearDown(() => dir.delete(recursive: true));
    final router = _Router({
      api: (200, payload),
      'https://github.com/tyuan511/amusic/releases/download/v2.1.0/aMusic-windows-x64.zip':
          (200, utf8.encode('far too long')),
    });
    final service = await create(router, dir: dir);
    await service.startDownload((await service.checkNow())!);
    expect(service.download.value.status, UpdateDownloadStatus.failed);
  });
}
