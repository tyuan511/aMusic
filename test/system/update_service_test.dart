import 'dart:convert';
import 'dart:typed_data';

import 'package:amusic/core/prefs.dart';
import 'package:amusic/services/update_service.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Answers every request with [body] and counts calls.
class _FakeAdapter implements HttpClientAdapter {
  _FakeAdapter(this.body);

  Map<String, dynamic> body;
  int status = 200;
  int calls = 0;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    calls++;
    return ResponseBody.fromString(
      jsonEncode(body),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType],
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

void main() {
  Map<String, dynamic> release(String tag) => {
    'tag_name': tag,
    'name': 'aMusic $tag',
    'html_url': 'https://github.com/tyuan511/amusic/releases/tag/$tag',
    'body': '- 新功能',
    'published_at': '2025-01-02T03:04:05Z',
  };

  Future<(UpdateService, _FakeAdapter, SharedPreferences)> create(
    Map<String, Object> initial,
    String tag,
  ) async {
    SharedPreferences.setMockInitialValues(initial);
    final prefs = await SharedPreferences.getInstance();
    final adapter = _FakeAdapter(release(tag));
    final service = UpdateService(
      prefs: prefs,
      dio: Dio()..httpClientAdapter = adapter,
      currentVersion: () async => '2.0.0',
    );
    return (service, adapter, prefs);
  }

  test('newer release is offered, then throttled for 24 h', () async {
    final (service, adapter, prefs) = await create({}, 'v2.1.0');
    await service.checkInBackground();
    expect(service.available.value?.version, '2.1.0');
    expect(service.available.value?.url, contains('/tag/v2.1.0'));
    expect(service.available.value?.notes, '- 新功能');
    expect(prefs.getInt(UpdateService.checkedAtKey), isNotNull);

    await service.checkInBackground();
    expect(adapter.calls, 1);

    // An explicit check ignores the throttle.
    expect((await service.checkNow())?.version, '2.1.0');
    expect(adapter.calls, 2);
  });

  test('same or older version is not offered', () async {
    final (service, _, _) = await create({}, 'v2.0.0');
    expect(await service.checkNow(), isNull);
    expect(service.available.value, isNull);
    final (older, _, _) = await create({}, 'v2.0.0-beta.9');
    expect(await older.checkNow(), isNull);
  });

  test('skipped version is hidden from background checks only', () async {
    final (service, _, prefs) = await create({}, 'v2.1.0');
    await service.checkInBackground();
    await service.skip('2.1.0');
    expect(service.available.value, isNull);
    expect(prefs.getString(UpdateService.skippedKey), '2.1.0');

    await prefs.remove(UpdateService.checkedAtKey);
    await service.checkInBackground();
    expect(service.available.value, isNull);
    // The settings button still reports it.
    expect((await service.checkNow())?.version, '2.1.0');
  });

  test('disabled in settings: no request', () async {
    final (service, adapter, _) = await create({
      PrefsKeys.checkUpdates: false,
    }, 'v9.0.0');
    await service.checkInBackground();
    expect(adapter.calls, 0);
    expect(service.available.value, isNull);
  });

  test('network errors throw from checkNow, not from the background', () async {
    final (service, adapter, _) = await create({}, 'v2.1.0');
    adapter.status = 500;
    await service.checkInBackground();
    expect(service.available.value, isNull);
    await expectLater(service.checkNow(), throwsException);
  });
}
