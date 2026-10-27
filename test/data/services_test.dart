import 'package:amusic/core/errors.dart';
import 'package:amusic/data/ncm_api.dart';
import 'package:amusic/models/playlist.dart';
import 'package:amusic/services/api_host.dart';
import 'package:amusic/services/library_service.dart';
import 'package:amusic/services/session_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'fake_client.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late ApiHost host;
  late FakeNeteaseClient client;
  late SessionService session;
  late LibraryService library;
  Map<String, dynamic>? Function(String uri, Map<String, dynamic> data)? route;
  var detailCalls = 0;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    final prefs = await SharedPreferences.getInstance();
    host = ApiHost(prefs: prefs);
    detailCalls = 0;
    client = FakeNeteaseClient((uri, data, crypto) {
      final custom = route?.call(uri, data);
      if (custom != null) return custom;
      switch (uri) {
        case '/api/song/like/get':
          return {'code': 200, 'ids': <int>[]};
        case '/api/v6/playlist/detail':
          detailCalls++;
          return {
            'code': 200,
            'playlist': {'id': data['id'], 'name': 'p$detailCalls'},
          };
        case '/api/user/playlist':
          return {
            'code': 200,
            'more': false,
            'playlist': [
              {
                'id': 10,
                'name': '喜欢',
                'specialType': 5,
                'creator': {'userId': 1},
              },
              {
                'id': 11,
                'name': 'mine',
                'creator': {'userId': 1},
              },
              {
                'id': 12,
                'name': 'theirs',
                'subscribed': true,
                'creator': {'userId': 2},
              },
            ],
          };
      }
      return {'code': 200};
    }, cookies: host.cookies);
    host.api = NcmApi(client);
    session = SessionService(host);
    library = LibraryService(host, session);
  });

  tearDown(() {
    route = null;
    library.dispose();
    session.dispose();
  });

  group('SessionService.signInWithCookie', () {
    test('rolls back the previous cookies when validation fails', () async {
      host.cookies.load({'MUSIC_U': 'old', '__csrf': 'oldcsrf', 'NMTID': 'n'});
      route = (uri, data) =>
          uri == '/api/w/nuser/account/get' ? {'code': 200} : null;
      final revision = session.authRevision.value;
      await expectLater(
        session.signInWithCookie('MUSIC_U=new; __csrf=c'),
        throwsA(isA<SessionExpiredException>()),
      );
      expect(host.cookies.all, {
        'MUSIC_U': 'old',
        '__csrf': 'oldcsrf',
        'NMTID': 'n',
      });
      expect(session.authRevision.value, revision);
      expect(session.value.isLoggedIn, isFalse);
    });

    test('installs, validates and bumps authRevision', () async {
      host.cookies.load({'NMTID': 'n', '__csrf': 'stale'});
      route = (uri, data) => uri == '/api/w/nuser/account/get'
          ? {
              'code': 200,
              'profile': {'userId': 1, 'nickname': 'me'},
            }
          : null;
      final revision = session.authRevision.value;
      final profile = await session.signInWithCookie('MUSIC_U=new%2B');
      expect(profile.id, 1);
      expect(session.value.profile!.nickname, 'me');
      expect(session.authRevision.value, revision + 1);
      expect(host.cookies.all, {'NMTID': 'n', 'MUSIC_U': 'new+'});
    });

    test('rejects text without MUSIC_U', () {
      expect(
        () => session.signInWithCookie('foo=bar'),
        throwsA(isA<ApiException>()),
      );
    });

    test('a failed SMS login keeps the old session cookies', () async {
      host.cookies.load({'MUSIC_U': 'old'});
      route = (uri, data) =>
          uri == '/api/w/login/cellphone' ? {'code': 503} : null;
      await expectLater(
        session.signInWithSms('13800000000', '0000'),
        throwsA(
          isA<ApiException>().having((e) => e.message, 'message', '验证码错误'),
        ),
      );
      expect(host.cookies.musicU, 'old');
    });
  });

  group('LibraryService', () {
    test('caches are scoped per account', () async {
      final first = await library.playlistDetail(5);
      final again = await library.playlistDetail(5);
      expect(identical(first, again), isTrue);
      expect(detailCalls, 1);

      session.value = const SessionState(
        profile: UserProfile(id: 1, nickname: 'me'),
      );
      expect(library.scope, '1');
      final mine = await library.playlistDetail(5);
      expect(
        detailCalls,
        2,
        reason: 'account switch must not reuse guest data',
      );
      expect(mine.name, 'p2');
    });

    test('mutations invalidate the playlist and the user list', () async {
      session.value = const SessionState(
        profile: UserProfile(id: 1, nickname: 'me'),
      );
      await library.playlistDetail(11);
      final collections = await library.userCollections();
      expect(collections.liked!.id, 10);
      expect(collections.created.single.id, 11);
      expect(collections.collected.single.id, 12);
      final listCalls = client.uris.where((u) => u == '/api/user/playlist');
      expect(listCalls.length, 1);

      await library.addToPlaylist(11, [1, 2]);
      await library.playlistDetail(11);
      expect(detailCalls, 2);
      await library.userCollections();
      expect(client.uris.where((u) => u == '/api/user/playlist').length, 2);
    });

    test('guests get empty account data without network calls', () async {
      expect((await library.userCollections()).isEmpty, isTrue);
      expect(await library.playRecord(), isEmpty);
      expect(await library.userDetail(), isNull);
      expect(client.calls, isEmpty);
    });

    test('clearCaches drops everything', () async {
      await library.playlistDetail(5);
      library.clearCaches();
      await library.playlistDetail(5);
      expect(detailCalls, 2);
    });
  });
}
