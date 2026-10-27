import 'package:amusic/core/async_cache.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('shares one in-flight load between callers', () async {
    var calls = 0;
    final cache = AsyncCache<String, int>();
    final results = await Future.wait([
      cache.get('k', () async {
        calls++;
        await Future<void>.delayed(const Duration(milliseconds: 10));
        return 42;
      }),
      cache.get('k', () async {
        calls++;
        return 0;
      }),
    ]);
    expect(results, [42, 42]);
    expect(calls, 1);
  });

  test('serves cached values and exposes them through peek', () async {
    var calls = 0;
    final cache = AsyncCache<String, int>();
    Future<int> loader() async {
      calls++;
      return calls;
    }

    expect(await cache.get('k', loader), 1);
    expect(await cache.get('k', loader), 1);
    expect(cache.peek('k'), 1);
    expect(calls, 1);

    cache.invalidate('k');
    expect(cache.peek('k'), isNull);
    expect(await cache.get('k', loader), 2);
  });

  test('does not cache failures', () async {
    var calls = 0;
    final cache = AsyncCache<String, int>();
    Future<int> loader() async {
      calls++;
      throw StateError('boom');
    }

    await expectLater(cache.get('k', loader), throwsStateError);
    await expectLater(cache.get('k', loader), throwsStateError);
    expect(calls, 2);
    expect(cache.peek('k'), isNull);
  });

  test('expires entries after the ttl', () async {
    var calls = 0;
    final cache = AsyncCache<String, int>(ttl: const Duration(milliseconds: 1));
    Future<int> loader() async => ++calls;

    expect(await cache.get('k', loader), 1);
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(await cache.get('k', loader), 2);
  });
}
