import 'dart:convert';
import 'dart:math';

import 'package:amusic/core/errors.dart';
import 'package:amusic/data/ncm_api.dart';
import 'package:amusic/data/netease_client.dart';
import 'package:amusic/models/comment.dart';
import 'package:amusic/models/comment_target.dart';
import 'package:amusic/models/song.dart';
import 'package:flutter_test/flutter_test.dart';

import 'fake_client.dart';

Map<String, dynamic> _song(int id) => {
  'id': id,
  'name': 'song $id',
  'ar': [
    {'id': 1, 'name': 'A'},
  ],
  'al': {'id': 2, 'name': 'B'},
};

void main() {
  group('song detail batching', () {
    test('2100 ids: batches of 500, <= 4 in flight, order preserved', () async {
      var inFlight = 0;
      var maxInFlight = 0;
      final random = Random(7);
      final client = FakeNeteaseClient((uri, data, crypto) async {
        expect(uri, '/api/v3/song/detail');
        final ids = [
          for (final item in jsonDecode(data['c'] as String) as List)
            (item as Map)['id'] as int,
        ];
        expect(ids.length, lessThanOrEqualTo(500));
        inFlight++;
        maxInFlight = max(maxInFlight, inFlight);
        await Future<void>.delayed(Duration(milliseconds: random.nextInt(15)));
        inFlight--;
        // Answer shuffled, drop one unknown id, privileges unordered.
        final shuffled = [...ids]..shuffle(random);
        return {
          'code': 200,
          'songs': [
            for (final id in shuffled)
              if (id != 1234) _song(id),
          ],
          'privileges': [
            for (final id in shuffled.reversed)
              {'id': id, 'code': id == 7 ? 404 : 200},
          ],
        };
      });
      final api = NcmApi(client);
      final ids = [for (var i = 2100; i >= 1; i--) i];
      final songs = await api.songDetails(ids);
      expect(client.calls, hasLength(5));
      expect(maxInFlight, lessThanOrEqualTo(4));
      expect(maxInFlight, greaterThan(1));
      expect(songs.map((s) => s.id), [
        for (final id in ids)
          if (id != 1234) id,
      ]);
      expect(songs.firstWhere((s) => s.id == 7).playable, isFalse);
    });

    test(
      'playlistDetail resolves every trackId beyond the given tracks',
      () async {
        final trackIds = [for (var i = 1; i <= 1200; i++) i];
        final client = FakeNeteaseClient((uri, data, crypto) {
          if (uri == '/api/v6/playlist/detail') {
            return {
              'code': 200,
              'playlist': {
                'id': 99,
                'name': 'big',
                'trackCount': 1200,
                'subscribed': true,
                'trackIds': [
                  for (final id in trackIds) {'id': id},
                ],
                // Only the first 1000 come inline (server side cap).
                'tracks': [for (var i = 1; i <= 1000; i++) _song(i)],
              },
              'privileges': [
                {'id': 3, 'code': 404, 'maxBrLevel': 'lossless'},
              ],
            };
          }
          final ids = [
            for (final item in jsonDecode(data['c'] as String) as List)
              (item as Map)['id'] as int,
          ];
          return {
            'code': 200,
            'songs': [for (final id in ids) _song(id)],
          };
        });
        final playlist = await NcmApi(client).playlistDetail(99);
        expect(playlist.tracks, hasLength(1200));
        expect(playlist.tracks.map((s) => s.id), trackIds);
        expect(playlist.trackCount, 1200);
        expect(playlist.subscribed, isTrue);
        expect(playlist.tracks[2].playable, isFalse);
        expect(playlist.tracks[2].maxLevel, 'lossless');
        // Only the 200 missing ids were requested.
        final detailCall = client.calls.singleWhere(
          (c) => c.uri == '/api/v3/song/detail',
        );
        expect(
          (jsonDecode(detailCall.data['c'] as String) as List).length,
          200,
        );
      },
    );
  });

  group('songUrlWithFallback', () {
    Map<String, dynamic> urlBody(int id, {String? url, int code = 200}) => {
      'code': 200,
      'data': [
        {'id': id, 'url': url, 'code': code, 'br': 320000, 'level': 'exhigh'},
      ],
    };

    test('walks down the chain until a url appears', () async {
      final levels = <String>[];
      final client = FakeNeteaseClient((uri, data, crypto) {
        final level = data['level'] as String;
        levels.add(level);
        if (level == 'higher') {
          return {
            'code': 200,
            'data': [
              {
                'id': 5,
                'url': 'https://cdn/x.mp3',
                'code': 200,
                'br': 192000,
                'level': 'higher',
                'freeTrialInfo': {'start': 0, 'end': 30},
              },
            ],
          };
        }
        // lossless: no url; exhigh: per item code 404.
        return urlBody(5, url: level == 'exhigh' ? 'x' : null, code: 404);
      });
      final url = await NcmApi(client)
          .songUrlWithFallback(5, level: AudioLevel.lossless);
      expect(levels, ['lossless', 'exhigh', 'higher']);
      expect(url.url, 'https://cdn/x.mp3');
      expect(url.grantedLevel, AudioLevel.higher);
      expect(url.isTrial, isTrue);
    });

    test('a transport error stops the chain', () async {
      final levels = <String>[];
      final client = FakeNeteaseClient((uri, data, crypto) {
        levels.add(data['level'] as String);
        if (levels.length == 1) return urlBody(5);
        throw const ServerUnreachableException('offline');
      });
      await expectLater(
        NcmApi(client).songUrlWithFallback(5, level: AudioLevel.lossless),
        throwsA(isA<ServerUnreachableException>()),
      );
      expect(levels, ['lossless', 'exhigh']);
    });

    test(
      'exhausted chain is SongUnavailable, songUrl keeps its contract',
      () async {
        final client = FakeNeteaseClient((uri, data, crypto) => urlBody(5));
        final api = NcmApi(client);
        await expectLater(
          api.songUrlWithFallback(5, level: AudioLevel.exhigh),
          throwsA(isA<SongUnavailableException>()),
        );
        expect(client.calls, hasLength(3));
        await expectLater(
          api.songUrl(5),
          throwsA(isA<SongUnavailableException>()),
        );
      },
    );

    test('songUrls batches ids into one request', () async {
      final client = FakeNeteaseClient(
        (uri, data, crypto) => {
          'code': 200,
          'data': [
            {'id': 1, 'url': 'u1', 'code': 200},
            {'id': 2, 'url': null, 'code': 404},
            {'id': 3, 'url': 'u3', 'code': 200},
          ],
        },
      );
      final urls = await NcmApi(client).songUrls([1, 2, 3]);
      expect(client.calls.single.data['ids'], '[1,2,3]');
      expect(urls.keys, [1, 3]);
    });
  });

  group('errors', () {
    test('business codes map to typed exceptions', () async {
      for (final (code, type) in [
        (301, SessionExpiredException),
        (-462, RiskControlException),
        (8821, RiskControlException),
        (-460, RiskControlException),
        (405, RateLimitedException),
      ]) {
        final api = NcmApi(
          FakeNeteaseClient((uri, data, crypto) => {'code': code}),
        );
        try {
          await api.toplists();
          fail('expected $type');
        } on ApiException catch (error) {
          expect(error.runtimeType, type);
          expect(error.code, code);
          expect(error.message, isNotEmpty);
        }
      }
      final plain = ApiException.fromCode(500, '服务器忙');
      expect(plain.runtimeType, ApiException);
      expect(plain.message, '服务器忙');
      expect(const SessionExpiredException().needLogin, isTrue);
    });

    test('301 on an authenticated call notifies once per window', () async {
      final cookies = NeteaseCookies()..load({'MUSIC_U': 'token'});
      final api = NcmApi(
        FakeNeteaseClient(
          (uri, data, crypto) => {'code': 301},
          cookies: cookies,
        ),
      );
      var notified = 0;
      api.onSessionExpired = () => notified++;
      for (var i = 0; i < 3; i++) {
        await expectLater(
          api.toplists(),
          throwsA(isA<SessionExpiredException>()),
        );
      }
      expect(notified, 1);
      // similarArtists swallows 301 and does not notify.
      expect(await api.similarArtists(1), isEmpty);
    });

    test('guests are never notified', () async {
      final api = NcmApi(
        FakeNeteaseClient((uri, data, crypto) => {'code': 301}),
      );
      var notified = 0;
      api.onSessionExpired = () => notified++;
      await expectLater(api.playRecord(1), throwsA(isA<ApiException>()));
      expect(notified, 0);
    });

    test('login errors get short Chinese messages', () async {
      final api = NcmApi(
        FakeNeteaseClient((uri, data, crypto) => {'code': 503, 'msg': 'x'}),
      );
      await expectLater(
        api.signInWithSms('13800000000', '1234'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '验证码错误'),
        ),
      );
      final client = FakeNeteaseClient((uri, data, crypto) => {'code': -462});
      await expectLater(
        NcmApi(client).signInWithPassword('13800000000', '123456'),
        throwsA(isA<RiskControlException>()),
      );
      // md5 of "123456"
      expect(
        client.calls.single.data['password'],
        'e10adc3949ba59abbe56e057f20f883e',
      );
      expect(client.calls.single.uri, '/api/w/login/cellphone');
    });
  });

  group('comments', () {
    const target = CommentTarget(CommentResource.song, 186016);

    test(
      'v2 latest uses the cursor, first page fetches hot comments',
      () async {
        final client = FakeNeteaseClient((uri, data, crypto) {
          if (uri.contains('hotcomments')) {
            return {
              'code': 200,
              'hotComments': [
                {'commentId': 9, 'content': 'hot'},
              ],
            };
          }
          return {
            'code': 200,
            'data': {
              'totalCount': 3,
              'hasMore': true,
              'cursor': '123',
              'comments': [
                {'commentId': 1, 'content': 'a'},
              ],
            },
          };
        });
        final api = NcmApi(client);
        final first = await api.comments(target, sort: CommentSort.latest);
        expect(first.hotComments.single.id, 9);
        expect(first.cursor, 123);
        final v2 = client.calls.firstWhere(
          (c) => c.uri == '/api/v2/resource/comments',
        );
        expect(v2.data['threadId'], 'R_SO_4_186016');
        expect(v2.data['sortType'], 3);
        expect(v2.data['cursor'], 0);

        client.calls.clear();
        final second = await api.comments(
          target,
          sort: CommentSort.latest,
          pageNo: 2,
          cursor: first.cursor,
        );
        expect(second.hotComments, isEmpty);
        expect(client.calls.single.data['cursor'], 123);
        expect(client.calls.single.data['pageNo'], 2);

        client.calls.clear();
        await api.comments(target, sort: CommentSort.hot, pageNo: 3);
        expect(client.calls.single.data['cursor'], 40);
        expect(client.calls.single.data['sortType'], 2);
      },
    );

    test('falls back to v1 when v2 fails', () async {
      final client = FakeNeteaseClient((uri, data, crypto) {
        if (uri == '/api/v2/resource/comments') return {'code': 400};
        if (uri.contains('hotcomments')) return {'code': 200};
        return {
          'code': 200,
          'total': 2,
          'more': false,
          'hotComments': [
            {'commentId': 3, 'content': 'h'},
          ],
          'comments': [
            {'commentId': 1, 'content': 'a', 'time': 5},
          ],
        };
      });
      final page = await NcmApi(client).comments(target);
      expect(page.comments.single.id, 1);
      expect(page.hotComments.single.id, 3);
      expect(client.uris, contains('/api/v1/resource/comments/R_SO_4_186016'));
    });

    test('postComment trims and truncates by runes, reply endpoint', () async {
      final client = FakeNeteaseClient(
        (uri, data, crypto) => {
          'code': 200,
          'comment': {'commentId': 77, 'content': data['content']},
        },
      );
      final api = NcmApi(client);
      final long = '  ${'😀' * 200}  ';
      final created = await api.postComment(target, long, replyToCommentId: 5);
      final sent = client.calls.single.data['content'] as String;
      expect(sent.runes.length, 140);
      expect(sent, '😀' * 140);
      expect(client.calls.single.uri, '/api/resource/comments/reply');
      expect(client.calls.single.data['commentId'], 5);
      expect(created!.id, 77);
      await expectLater(
        api.postComment(target, '   '),
        throwsA(isA<ApiException>()),
      );
    });
  });

  group('normalizeCommentContent', () {
    test('counts runes, not UTF-16 units', () {
      final text = '${'a' * 139}😀😀';
      final cut = normalizeCommentContent(text);
      expect(cut, '${'a' * 139}😀');
      expect(cut.runes.length, 140);
    });

    test('never splits ZWJ sequences, skin tones or flags', () {
      const family = '👨‍👩‍👧'; // 5 runes
      final zwj = normalizeCommentContent('${'a' * 137}$family');
      expect(zwj, 'a' * 137);
      const thumb = '👍🏽'; // 2 runes
      expect(normalizeCommentContent('${'a' * 139}$thumb'), 'a' * 139);
      const flag = '🇨🇳'; // 2 regional indicators
      expect(normalizeCommentContent('${'a' * 139}$flag'), 'a' * 139);
      expect(
        normalizeCommentContent('${'a' * 138}$flag$flag'),
        '${'a' * 138}$flag',
      );
    });

    test('short text is only trimmed', () {
      expect(normalizeCommentContent('  hi 👋  '), 'hi 👋');
      expect(normalizeCommentContent('x' * 5, max: 3), 'xxx');
    });
  });

  group('cookies', () {
    test('parses header text, set-cookie lines and bare tokens', () {
      expect(
        NeteaseCookies.parse('MUSIC_U=abc%3D; __csrf=xyz; Path=/; HttpOnly'),
        {'MUSIC_U': 'abc=', '__csrf': 'xyz'},
      );
      expect(
        NeteaseCookies.parse(
          'Cookie: NMTID=1; MUSIC_U=t\nSet-Cookie: __csrf=c; Max-Age=10',
        ),
        {'NMTID': '1', 'MUSIC_U': 't', '__csrf': 'c'},
      );
      final token = 'f' * 64;
      expect(NeteaseCookies.parse(token), {'MUSIC_U': token});
      expect(NeteaseCookies.parse('garbage'), isEmpty);
    });

    test('snapshot / restore', () {
      var changes = 0;
      final cookies = NeteaseCookies()
        ..load({'MUSIC_U': 'a'})
        ..onChange = () => changes++;
      final backup = cookies.snapshot();
      cookies.restore({'MUSIC_U': 'b', 'x': ''});
      expect(cookies.all, {'MUSIC_U': 'b'});
      cookies.restore(backup);
      expect(cookies.musicU, 'a');
      cookies.remove('MUSIC_U');
      expect(cookies.isLoggedIn, isFalse);
      expect(changes, 3);
    });
  });

  test('playlist mutations send trackIds as a JSON array string', () async {
    final client = FakeNeteaseClient((uri, data, crypto) => {'code': 200});
    final api = NcmApi(client);
    await api.addToPlaylist(9, [3, 1, 3]);
    await api.removeFromPlaylist(9, [2]);
    await api.subscribePlaylist(9, subscribe: false);
    expect(client.calls[0].uri, '/api/playlist/manipulate/tracks');
    expect(client.calls[0].data['trackIds'], '[3,1]');
    expect(client.calls[0].data['op'], 'add');
    expect(client.calls[1].data['op'], 'del');
    expect(client.calls[2].uri, '/api/playlist/unsubscribe');
    expect(client.calls.every((c) => c.crypto == CryptoMode.eapi), isTrue);
  });

  test('scrobble posts a play log', () async {
    final client = FakeNeteaseClient((uri, data, crypto) => {'code': 200});
    await NcmApi(client).scrobble(5, sourceId: 9, seconds: 200);
    final logs = jsonDecode(client.calls.single.data['logs'] as String) as List;
    final entry = logs.single as Map;
    expect(entry['action'], 'play');
    expect((entry['json'] as Map)['end'], 'playend');
    expect((entry['json'] as Map)['id'], 5);
    expect((entry['json'] as Map)['time'], 200);
    expect((entry['json'] as Map)['sourceId'], '9');
  });
}
