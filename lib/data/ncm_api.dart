import 'dart:async';
import 'dart:convert';

import 'package:crypto/crypto.dart' as crypto;
import 'package:flutter/foundation.dart' show debugPrint;

import '../core/errors.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/comment.dart';
import '../models/comment_target.dart';
import '../models/discovery.dart';
import '../models/json_utils.dart';
import '../models/lyric.dart';
import '../models/lyric_payload.dart';
import '../models/paged.dart';
import '../models/playlist.dart';
import '../models/search.dart';
import '../models/song.dart';
import '../models/user.dart';
import 'netease_client.dart';

/// Result of polling the QR login endpoint.
enum QrLoginState { waiting, scanned, confirmed, expired, riskControl, unknown }

class QrLoginResult {
  const QrLoginResult(this.state, {this.code, this.message});

  final QrLoginState state;

  /// Raw server code (800-803, 8821...).
  final int? code;
  final String? message;

  static QrLoginResult fromCode(int? code, {String? message}) => QrLoginResult(
    switch (code) {
      800 => QrLoginState.expired,
      801 => QrLoginState.waiting,
      802 => QrLoginState.scanned,
      803 => QrLoginState.confirmed,
      8821 => QrLoginState.riskControl,
      _ => QrLoginState.unknown,
    },
    code: code,
    message: message,
  );
}

/// Play url plus the quality that was actually granted.
class PlayUrl {
  const PlayUrl({
    required this.url,
    this.level,
    this.isTrial = false,
    this.bitrate = 0,
    this.size,
    this.type,
  });

  final String url;

  /// Level NetEase granted (`level`), may be lower than requested.
  final String? level;

  /// Only a preview clip (`freeTrialInfo` present), usually 30 s.
  final bool isTrial;
  final int bitrate;

  /// File size in bytes, when reported.
  final int? size;

  /// `mp3` / `flac`...
  final String? type;

  AudioLevel get grantedLevel => AudioLevel.fromValue(level);

  static PlayUrl? fromJson(Map<String, dynamic> item) {
    final url = jsonText(item['url']);
    final code = jsonIntOrNull(item['code']);
    if (url == null || (code != null && code != 200)) return null;
    return PlayUrl(
      url: url,
      level: jsonText(item['level']),
      isTrial: item['freeTrialInfo'] != null,
      bitrate: jsonInt(item['br']),
      size: jsonIntOrNull(item['size']),
      type: jsonText(item['type']),
    );
  }
}

/// Every NetEase endpoint the app uses, with the encryption scheme each one
/// expects. Requests go straight to the official hosts from the device.
class NcmApi {
  NcmApi(this._client);

  final NeteaseClient _client;

  NeteaseClient get client => _client;

  /// Called (at most once per 30 s) when an authenticated request answered
  /// 301, i.e. the stored `MUSIC_U` may have expired. The session layer
  /// re-validates and signs out if needed.
  void Function()? onSessionExpired;
  DateTime? _lastExpiryNotice;

  /// Batch size of `/api/v3/song/detail`.
  static const int songDetailBatch = 500;

  /// Parallel song/detail requests.
  static const int songDetailConcurrency = 4;

  /// Sends a request and rejects a non-200 business code.
  /// [webFallback] sends the request as the PC client first (eapi) and only
  /// retries as the web client (weapi) when the PC call is rejected: the web
  /// scheme is the one NetEase risk-controls (-462) most often.
  Future<Map<String, dynamic>> _call(
    String uri,
    Map<String, dynamic> data, {
    CryptoMode crypto = CryptoMode.eapi,
    Set<int> allowedCodes = const {200},
    bool notifyExpiry = true,
    bool webFallback = false,
  }) async {
    if (webFallback) {
      try {
        return await _send(
          uri,
          data,
          CryptoMode.eapi,
          allowedCodes,
          notifyExpiry: false,
        );
      } on ApiException catch (error) {
        debugPrint('[api] $uri eapi rejected ($error), retrying as weapi');
      }
      crypto = CryptoMode.weapi;
    }
    return _send(uri, data, crypto, allowedCodes, notifyExpiry: notifyExpiry);
  }

  Future<Map<String, dynamic>> _send(
    String uri,
    Map<String, dynamic> data,
    CryptoMode crypto,
    Set<int> allowedCodes, {
    required bool notifyExpiry,
  }) async {
    final body = await _client.request(uri, Map.of(data), crypto: crypto);
    final code =
        jsonIntOrNull(body['code']) ?? jsonIntOrNull(body['status']) ?? 200;
    if (!allowedCodes.contains(code)) {
      final message = jsonText(
        body['message'] ?? body['msg'] ?? body['errmsg'],
      );
      final error = ApiException.fromCode(code, message);
      if (error is SessionExpiredException && notifyExpiry) _noticeExpiry();
      throw error;
    }
    return body;
  }

  void _noticeExpiry() {
    if (!_client.cookies.isLoggedIn) return;
    final now = DateTime.now();
    final last = _lastExpiryNotice;
    if (last != null && now.difference(last) < const Duration(seconds: 30)) {
      return;
    }
    _lastExpiryNotice = now;
    onSessionExpired?.call();
  }

  // ---------------------------------------------------------------- auth

  Future<String> loginQrKey() async {
    final body = await _call('/api/login/qrcode/unikey', {'type': 3});
    final key = body['unikey'] as String?;
    if (key == null || key.isEmpty) {
      throw const ApiException(null, '获取登录二维码失败');
    }
    return key;
  }

  /// The server answers with 800/801/802/803 (8821 on risk control), so
  /// those are not errors.
  Future<QrLoginResult> checkQrLogin(String key) async {
    final body = await _client.request('/api/login/qrcode/client/login', {
      'key': key,
      'type': 3,
    });
    return QrLoginResult.fromCode(
      jsonIntOrNull(body['code']),
      message: jsonText(body['message']),
    );
  }

  /// `null` when there is no valid session. Uses the web endpoint (weapi),
  /// which is the only one that reports the account reliably.
  ///
  /// Risk control (-462) is thrown as [RiskControlException] instead of being
  /// reported as "signed out", so a temporary block never drops a session.
  Future<UserProfile?> loginStatus() async {
    try {
      final body = await _call(
        '/api/w/nuser/account/get',
        {},
        crypto: CryptoMode.weapi,
        allowedCodes: const {200, 301, 250},
        notifyExpiry: false,
      );
      final profile = jsonMap(body['profile']);
      if (profile == null) return null;
      final parsed = UserProfile.fromJson(profile);
      return parsed.id > 0 ? parsed : null;
    } on SessionExpiredException {
      return null;
    }
  }

  Future<void> logout() => _call('/api/logout', {}, notifyExpiry: false);

  /// Extends the life of the current `MUSIC_U`; new cookies arrive through
  /// `set-cookie`. Throws [SessionExpiredException] when the token is dead.
  Future<void> refreshToken() =>
      _call('/api/login/token/refresh', {}, notifyExpiry: false);

  /// Sends an SMS verification code. Uses the endpoint of the official PC
  /// client (`/api/sms/captcha/sent`, eapi); probed live: answers 400 for a
  /// malformed number, so the route and crypto are accepted.
  Future<void> sendSmsCode(String phone, {int countryCode = 86}) async {
    try {
      await _call('/api/sms/captcha/sent', {
        'cellphone': phone.trim(),
        'ctcode': '$countryCode',
      }, notifyExpiry: false);
    } on ApiException catch (error) {
      throw _loginError(error);
    }
  }

  /// SMS code login. Returns the signed in profile.
  Future<UserProfile> signInWithSms(
    String phone,
    String code, {
    int countryCode = 86,
  }) => _cellphoneLogin(phone, countryCode, {'captcha': code.trim()});

  /// Password login (md5 hashed before sending). NetEase applies heavy risk
  /// control to it; [RiskControlException] tells the user to use QR / SMS.
  Future<UserProfile> signInWithPassword(
    String phone,
    String password, {
    int countryCode = 86,
  }) => _cellphoneLogin(phone, countryCode, {
    'password': crypto.md5.convert(utf8.encode(password)).toString(),
  });

  Future<UserProfile> _cellphoneLogin(
    String phone,
    int countryCode,
    Map<String, String> secret,
  ) async {
    final Map<String, dynamic> body;
    try {
      // eapi: the weapi variant is answered with -462 for most devices.
      body = await _call('/api/w/login/cellphone', {
        'type': '1',
        'https': 'true',
        'phone': phone.trim(),
        'countrycode': '$countryCode',
        'remember': 'true',
        ...secret,
      }, notifyExpiry: false);
    } on ApiException catch (error) {
      throw _loginError(error);
    }
    final profile = jsonMap(body['profile']);
    if (profile != null) {
      final parsed = UserProfile.fromJson(profile);
      if (parsed.id > 0) return parsed;
    }
    // Some responses only carry `account`; the cookie is stored already.
    final status = await loginStatus();
    if (status == null) throw const ApiException(null, '登录失败，请稍后再试');
    return status;
  }

  static ApiException _loginError(ApiException error) {
    if (error is SessionExpiredException ||
        error is RiskControlException ||
        error is RateLimitedException) {
      return error;
    }
    return switch (error.code) {
      400 => const ApiException(400, '手机号格式不正确'),
      501 => const ApiException(501, '账号不存在'),
      502 => const ApiException(502, '密码错误'),
      503 => const ApiException(503, '验证码错误'),
      509 => const ApiException(509, '密码错误次数过多，请稍后再试'),
      _ => error,
    };
  }

  // ---------------------------------------------------------------- user

  Future<UserDetail> userDetail(int uid) async {
    final body = await _call('/api/v1/user/detail/$uid', {}, webFallback: true);
    return UserDetail.fromJson(body);
  }

  /// Every playlist of [uid] (created + collected). Pages through the
  /// endpoint until `more` is false, so there is no silent cap.
  Future<List<Playlist>> userPlaylists(int uid) async {
    const limit = 1000;
    final result = <Playlist>[];
    final seen = <int>{};
    for (var offset = 0; offset < 20000; offset += limit) {
      final body = await _call('/api/user/playlist', {
        'uid': uid,
        'limit': limit,
        'offset': offset,
        'includeVideo': true,
      }, webFallback: true);
      final page = Playlist.listFrom(body['playlist']);
      for (final playlist in page) {
        if (seen.add(playlist.id)) result.add(playlist);
      }
      if (body['more'] != true || page.isEmpty) break;
    }
    return result;
  }

  /// Creates a playlist on the signed in account.
  Future<Playlist> createPlaylist(String name, {bool private = false}) async {
    final trimmed = name.trim();
    if (trimmed.isEmpty) throw const ApiException(null, '歌单名不能为空');
    if (trimmed.runes.length > 40) {
      throw const ApiException(null, '歌单名不能超过 40 个字');
    }
    final body = await _call('/api/playlist/create', {
      'name': trimmed,
      'privacy': private ? '10' : '0',
      'type': 'NORMAL',
    }, webFallback: true);
    final raw = jsonMap(body['playlist']);
    final id = jsonInt(raw?['id'] ?? body['id']);
    if (id <= 0) throw const ApiException(null, '创建歌单失败');
    return raw != null
        ? Playlist.fromJson(raw)
        : Playlist(id: id, name: trimmed, privacy: private ? 10 : 0);
  }

  Future<void> deletePlaylist(int id) async {
    await _call('/api/playlist/remove', {'ids': '[$id]'}, webFallback: true);
  }

  Future<void> addToPlaylist(int playlistId, List<int> songIds) =>
      _manipulateTracks('add', playlistId, songIds);

  Future<void> removeFromPlaylist(int playlistId, List<int> songIds) =>
      _manipulateTracks('del', playlistId, songIds);

  Future<void> _manipulateTracks(
    String op,
    int playlistId,
    List<int> songIds,
  ) async {
    final ids = songIds.where((id) => id > 0).toSet().toList();
    if (ids.isEmpty) return;
    Future<void> send(List<int> trackIds) =>
        _call('/api/playlist/manipulate/tracks', {
          'op': op,
          'pid': playlistId,
          // A JSON array as a string, not a form list.
          'trackIds': jsonEncode(trackIds),
          'imme': 'true',
        }, webFallback: true);
    try {
      await send(ids);
    } on ApiException catch (error) {
      if (error.code == 502 && op == 'add') {
        throw const ApiException(502, '歌曲已在歌单中');
      }
      // Known server quirk: 512 succeeds when the ids are sent twice.
      if (error.code == 512) return send([...ids, ...ids]);
      rethrow;
    }
  }

  /// Collects (`subscribe = true`) or un-collects a playlist.
  Future<void> subscribePlaylist(int id, {required bool subscribe}) async {
    await _call(
      subscribe ? '/api/playlist/subscribe' : '/api/playlist/unsubscribe',
      {'id': id},
      webFallback: true,
    );
  }

  /// Listening history ranking. [week] `true` for the last week, `false` for
  /// all time. Needs login (or a public record).
  Future<List<PlayRecordEntry>> playRecord(int uid, {bool week = true}) async {
    final body = await _call('/api/v1/play/record', {
      'uid': uid,
      'type': week ? 1 : 0,
    }, webFallback: true);
    return parsePlayRecord(week ? body['weekData'] : body['allData']);
  }

  /// Reports a finished play so it counts in the account's history.
  /// [seconds] is the time actually listened.
  Future<void> scrobble(int songId, {int? sourceId, int seconds = 0}) async {
    await _call('/api/feedback/weblog', {
      'logs': jsonEncode([
        {
          'action': 'play',
          'json': {
            'download': 0,
            'end': 'playend',
            'id': songId,
            'sourceId': '${sourceId ?? ''}',
            'time': seconds,
            'type': 'song',
            'wifi': 0,
            'source': 'list',
            'mainsite': 1,
            'content': '',
          },
        },
      ]),
    }, webFallback: true);
  }

  // ------------------------------------------------------------ library

  /// Full playlist: every id in `trackIds` is resolved (song/detail in
  /// batches of [songDetailBatch], [songDetailConcurrency] in parallel,
  /// original order kept), with privileges applied.
  Future<Playlist> playlistDetail(int id) async {
    final body = await _call('/api/v6/playlist/detail', {
      'id': id,
      'n': 100000,
      's': 8,
    });
    final raw = jsonMap(body['playlist']);
    if (raw == null) throw const ApiException(null, '歌单不存在');
    final playlist = Playlist.fromJson(raw);
    final privileges = jsonMaps(body['privileges']);
    final privById = {for (final p in privileges) jsonInt(p['id']): p};
    final given = [
      for (final track in jsonMaps(raw['tracks']))
        Song.fromJson(track, privilege: privById[jsonInt(track['id'])]),
    ];
    final ids = playlist.trackIds;
    if (ids.isEmpty || given.length >= ids.length) {
      return playlist.copyWith(tracks: given);
    }
    final known = {for (final song in given) song.id: song};
    final missing = [
      for (final trackId in ids)
        if (!known.containsKey(trackId)) trackId,
    ];
    for (final song in await songDetails(missing)) {
      known[song.id] = song;
    }
    return playlist.copyWith(
      tracks: [for (final trackId in ids) ?known[trackId]],
    );
  }

  /// `/api/v3/song/detail` for any number of [ids]: batches of
  /// [songDetailBatch], at most [songDetailConcurrency] in flight, result in
  /// the order of [ids] (ids NetEase does not know are skipped).
  Future<List<Song>> songDetails(List<int> ids) async {
    if (ids.isEmpty) return const [];
    final batches = <List<int>>[
      for (var start = 0; start < ids.length; start += songDetailBatch)
        ids.sublist(
          start,
          start + songDetailBatch > ids.length
              ? ids.length
              : start + songDetailBatch,
        ),
    ];
    final pages = await _pool(batches, songDetailConcurrency, (batch) async {
      final body = await _call('/api/v3/song/detail', {
        'c': jsonEncode([
          for (final id in batch) {'id': id},
        ]),
      });
      return Song.listWithPrivileges(body['songs'], body['privileges']);
    });
    final byId = {
      for (final page in pages)
        for (final song in page) song.id: song,
    };
    return [for (final id in ids) ?byId[id]];
  }

  /// Runs [task] over [inputs] with at most [concurrency] running, results
  /// in input order.
  static Future<List<R>> _pool<T, R>(
    List<T> inputs,
    int concurrency,
    Future<R> Function(T input) task,
  ) async {
    final results = List<R?>.filled(inputs.length, null);
    var next = 0;
    Future<void> worker() async {
      while (next < inputs.length) {
        final index = next++;
        results[index] = await task(inputs[index]);
      }
    }

    await Future.wait([
      for (var i = 0; i < concurrency && i < inputs.length; i++) worker(),
    ]);
    return results.cast<R>();
  }

  /// Playlists recommended for the signed in user.
  Future<List<Playlist>> recommendPlaylists() async {
    final body = await _call(
      '/api/v1/discovery/recommend/resource',
      {},
      webFallback: true,
    );
    return Playlist.listFrom(body['recommend']);
  }

  /// Public "popular playlists" feed, works without an account.
  Future<List<Playlist>> personalizedPlaylists({int limit = 30}) async {
    final body = await _call('/api/personalized/playlist', {
      'limit': limit,
      'total': true,
      'n': 1000,
    }, webFallback: true);
    return Playlist.listFrom(body['result']);
  }

  Future<List<Song>> dailyRecommendSongs() async {
    final body = await _call('/api/v3/discovery/recommend/songs', {
      'afresh': false,
    }, webFallback: true);
    final data = jsonMap(body['data']);
    return Song.listWithPrivileges(data?['dailySongs'], data?['privileges']);
  }

  // ----------------------------------------------------------- discovery

  /// Personal FM batch (needs login, a guest gets a generic batch).
  Future<List<Song>> personalFm() async {
    final body = await _call('/api/v1/radio/get', {}, webFallback: true);
    return Song.listFrom(body['data']);
  }

  /// "不喜欢" in personal FM.
  Future<void> fmTrash(int songId, {int seconds = 25}) async {
    await _call('/api/radio/trash/add?alg=RT&songId=$songId&time=$seconds', {
      'songId': songId,
    }, webFallback: true);
  }

  /// Heart mode (心动模式) continuation for [songId] inside [playlistId]
  /// (usually the liked songs playlist). Needs login.
  Future<List<Song>> heartModeList(int songId, int playlistId) async {
    final body = await _call('/api/playmode/intelligence/list', {
      'songId': songId,
      'type': 'fromPlayOne',
      'playlistId': playlistId,
      'startMusicId': songId,
      'count': 20,
    }, webFallback: true);
    return [
      for (final item in jsonMaps(body['data']))
        Song.fromJson(
          jsonMap(item['songInfo']) ?? jsonMap(item['song']) ?? item,
          privilege: jsonMap(item['privilege']),
        ),
    ].where((song) => song.id > 0).toList(growable: false);
  }

  /// Every chart, official ones first as NetEase orders them.
  Future<List<Toplist>> toplists() async {
    final body = await _call('/api/toplist/detail', {}, webFallback: true);
    return Toplist.listFrom(body['list']);
  }

  Future<PlaylistCatalogue> playlistCategories() async {
    final body = await _call('/api/playlist/catalogue', {});
    return PlaylistCatalogue.fromJson(body);
  }

  /// Playlist square. [order] is `hot` or `new`.
  Future<PagedList<Playlist>> topPlaylists({
    String cat = '全部',
    String order = 'hot',
    int limit = 50,
    int offset = 0,
  }) async {
    final body = await _call('/api/playlist/list', {
      'cat': cat,
      'order': order,
      'limit': limit,
      'offset': offset,
      'total': true,
    }, webFallback: true);
    final items = Playlist.listFrom(body['playlists']);
    final total = jsonInt(body['total']);
    return PagedList(
      items: items,
      total: total,
      hasMore: PagedList.moreByTotal(
        offset: offset,
        received: items.length,
        total: total,
        serverMore: body['more'] is bool ? body['more'] as bool : null,
      ),
    );
  }

  /// Boutique playlists. Pass the previous page's [PagedList.cursor] as
  /// [before] to continue.
  Future<PagedList<Playlist>> highQualityPlaylists({
    String cat = '全部',
    int limit = 50,
    int? before,
  }) async {
    final body = await _call('/api/playlist/highquality/list', {
      'cat': cat,
      'limit': limit,
      'lasttime': before ?? 0,
      'total': true,
    }, webFallback: true);
    final items = Playlist.listFrom(body['playlists']);
    return PagedList(
      items: items,
      total: jsonInt(body['total']),
      hasMore: body['more'] == true && items.isNotEmpty,
      cursor: jsonIntOrNull(body['lasttime']),
    );
  }

  /// Newest songs. [areaId]: 0 全部, 7 华语, 96 欧美, 8 日本, 16 韩国.
  Future<List<Song>> newSongs({int areaId = 0}) async {
    try {
      final body = await _call('/api/v1/discovery/new/songs', {
        'areaId': areaId,
        'total': true,
      }, webFallback: true);
      final songs = Song.listFrom(body['data']);
      if (songs.isNotEmpty) return songs;
    } on ApiException catch (error) {
      if (error is SessionExpiredException) rethrow;
    }
    final body = await _call('/api/personalized/newsong', {
      'type': 'recommend',
      'limit': 50,
      'areaId': areaId,
    }, webFallback: true);
    return [
      for (final item in jsonMaps(body['result']))
        Song.fromJson(jsonMap(item['song']) ?? item),
    ];
  }

  /// Newest albums. [area]: `ALL`, `ZH`, `EA`, `KR`, `JP`.
  Future<PagedList<Album>> newAlbums({
    String area = 'ALL',
    int limit = 30,
    int offset = 0,
  }) async {
    final body = await _call('/api/album/new', {
      'limit': limit,
      'offset': offset,
      'total': true,
      'area': area,
    }, webFallback: true);
    final items = Album.listFrom(body['albums']);
    final total = jsonInt(body['total']);
    return PagedList(
      items: items,
      total: total,
      hasMore: PagedList.moreByTotal(
        offset: offset,
        received: items.length,
        total: total,
      ),
    );
  }

  Future<List<HomeBanner>> banners() async {
    final body = await _call('/api/v2/banner/get', {'clientType': 'pc'});
    return HomeBanner.listFrom(body['banners']);
  }

  // ------------------------------------------------------------- search

  Future<List<String>> hotSearchWords({int limit = 12}) async {
    final body = await _call('/api/hotsearchlist/get', {}, webFallback: true);
    final data = body['data'];
    if (data is! List) return const [];
    return data
        .whereType<Map>()
        .map((e) => e['searchWord'] as String? ?? '')
        .where((word) => word.isNotEmpty)
        .take(limit)
        .toList(growable: false);
  }

  /// Keyword completions. Never throws.
  Future<List<String>> searchSuggest(String keywords) async {
    if (keywords.trim().isEmpty) return const [];
    try {
      final body = await _call('/api/search/suggest/keyword', {
        's': keywords.trim(),
      }, webFallback: true);
      return [
        for (final item in jsonMaps(jsonMap(body['result'])?['allMatch']))
          ?jsonText(item['keyword']),
      ];
    } on AppException {
      return const [];
    }
  }

  /// Keyword completions plus best matching songs / artists / albums /
  /// playlists. Never throws; empty on failure.
  Future<SearchSuggestions> searchSuggestions(String keywords) async {
    final text = keywords.trim();
    if (text.isEmpty) return SearchSuggestions.empty;
    final results = await Future.wait<Object?>([
      searchSuggest(text),
      _call('/api/search/suggest/web', {'s': text}, crypto: CryptoMode.weapi)
          .then<Object?>((b) => b)
          .catchError(
            (Object _) => null,
            test: (error) => error is AppException,
          ),
    ]);
    final body = results[1] as Map<String, dynamic>?;
    return SearchSuggestions.fromJson(
      jsonMap(body?['result']),
      keywords: results[0]! as List<String>,
    );
  }

  /// Placeholder of the search box.
  Future<DefaultSearchKeyword> defaultKeyword() async {
    final body = await _call('/api/search/defaultkeyword/get', {});
    return DefaultSearchKeyword.fromJson(body);
  }

  Future<({List<Song> songs, int total})> searchSongs(
    String keywords, {
    int limit = 30,
    int offset = 0,
  }) async {
    final result = await _cloudsearch(keywords, 1, limit, offset);
    if (result == null) return (songs: const <Song>[], total: 0);
    final privileges = jsonMaps(result['privileges']);
    final songs = Song.listFrom(
      result['songs'],
      privileges: privileges.isEmpty ? null : privileges,
    );
    final count = jsonIntOrNull(result['songCount']) ?? songs.length;
    return (songs: songs, total: count);
  }

  Future<SearchPage<Album>> searchAlbums(
    String keywords, {
    int limit = 30,
    int offset = 0,
  }) => _searchPage(
    keywords,
    10,
    limit,
    offset,
    'albums',
    'albumCount',
    Album.listFrom,
  );

  Future<SearchPage<Artist>> searchArtists(
    String keywords, {
    int limit = 30,
    int offset = 0,
  }) => _searchPage(
    keywords,
    100,
    limit,
    offset,
    'artists',
    'artistCount',
    Artist.listFrom,
  );

  Future<SearchPage<Playlist>> searchPlaylists(
    String keywords, {
    int limit = 30,
    int offset = 0,
  }) => _searchPage(
    keywords,
    1000,
    limit,
    offset,
    'playlists',
    'playlistCount',
    Playlist.listFrom,
  );

  Future<SearchPage<T>> _searchPage<T>(
    String keywords,
    int type,
    int limit,
    int offset,
    String listKey,
    String countKey,
    List<T> Function(Object? raw) parse,
  ) async {
    final result = await _cloudsearch(keywords, type, limit, offset);
    if (result == null) return const PagedList.empty();
    final items = parse(result[listKey]);
    final total = jsonIntOrNull(result[countKey]) ?? items.length;
    return PagedList(
      items: items,
      total: total,
      hasMore: PagedList.moreByTotal(
        offset: offset,
        received: items.length,
        total: total,
      ),
    );
  }

  Future<Map<String, dynamic>?> _cloudsearch(
    String keywords,
    int type,
    int limit,
    int offset,
  ) async {
    if (keywords.trim().isEmpty) return null;
    final body = await _call('/api/cloudsearch/pc', {
      's': keywords,
      'type': type,
      'limit': limit,
      'offset': offset,
      'total': true,
    });
    return jsonMap(body['result']);
  }

  // -------------------------------------------------------------- artist

  Future<ArtistDetail> artistDetail(int id) async {
    try {
      final body = await _call('/api/artist/head/info/get', {'id': id});
      final detail = ArtistDetail.fromJson(body);
      if (detail.id > 0) return detail;
    } on ApiException catch (error) {
      if (error is SessionExpiredException) rethrow;
    }
    // Legacy shape: `artist` at the top level (+ hotSongs, ignored here).
    final body = await _call('/api/v1/artist/$id', {}, webFallback: true);
    return ArtistDetail.fromJson(body);
  }

  /// The artist's 50 most popular songs.
  Future<List<Song>> artistTopSongs(int id) async {
    final body = await _call('/api/artist/top/song', {
      'id': id,
    }, webFallback: true);
    return Song.listFrom(body['songs']);
  }

  /// All songs of an artist. [order] `hot` or `time`.
  Future<PagedList<Song>> artistSongs(
    int id, {
    String order = 'hot',
    int limit = 50,
    int offset = 0,
  }) async {
    final body = await _call('/api/v1/artist/songs', {
      'id': id,
      'order': order,
      'limit': limit,
      'offset': offset,
      'private_cloud': 'true',
      'work_type': 1,
    });
    final items = Song.listFrom(body['songs']);
    final total = jsonInt(body['total']);
    return PagedList(
      items: items,
      total: total,
      hasMore: body['more'] == true && items.isNotEmpty,
    );
  }

  Future<PagedList<Album>> artistAlbums(
    int id, {
    int limit = 30,
    int offset = 0,
  }) async {
    final body = await _call('/api/artist/albums/$id', {
      'limit': limit,
      'offset': offset,
      'total': true,
    }, webFallback: true);
    return parseArtistAlbums(body);
  }

  /// Parses an `/api/artist/albums/{id}` body (exposed for tests).
  static PagedList<Album> parseArtistAlbums(Map<String, dynamic> body) {
    final items = Album.listFrom(body['hotAlbums']);
    return PagedList(
      items: items,
      total: jsonInt(jsonMap(body['artist'])?['albumSize']),
      hasMore: body['more'] == true && items.isNotEmpty,
    );
  }

  Future<ArtistDescription> artistDescription(int id) async {
    final body = await _call('/api/artist/introduction', {
      'id': id,
    }, webFallback: true);
    return ArtistDescription.fromJson(body);
  }

  /// Needs login; returns `[]` for guests (301) instead of throwing.
  Future<List<Artist>> similarArtists(int id) async {
    try {
      final body = await _call(
        '/api/discovery/simiArtist',
        {'artistid': id},
        webFallback: true,
        notifyExpiry: false,
      );
      return Artist.listFrom(body['artists']);
    } on SessionExpiredException {
      return const [];
    }
  }

  // --------------------------------------------------------------- album

  Future<Album> albumDetail(int id) async {
    final body = await _call('/api/v1/album/$id', {}, webFallback: true);
    if (jsonMap(body['album']) == null) {
      throw const ApiException(null, '专辑不存在');
    }
    return Album.detailFromJson(body);
  }

  // ---------------------------------------------------------- playback

  /// Resolves a streaming url. Throws [SongUnavailableException] when there is
  /// no playable source (removed / VIP only).
  Future<PlayUrl> songUrl(
    int id, {
    AudioLevel level = AudioLevel.exhigh,
  }) async {
    final urls = await songUrls([id], level: level);
    final url = urls[id];
    if (url == null) {
      throw const SongUnavailableException('歌曲不可播放（版权或会员限制）');
    }
    return url;
  }

  /// Batch variant: one request for many ids. Songs without a url (or with
  /// a per-item code other than 200) are absent from the map.
  Future<Map<int, PlayUrl>> songUrls(
    List<int> ids, {
    AudioLevel level = AudioLevel.exhigh,
  }) async {
    if (ids.isEmpty) return const {};
    final body = await _call('/api/song/enhance/player/url/v1', {
      'ids': jsonEncode(ids),
      'level': level.value,
      'encodeType': 'flac',
    });
    return {
      for (final item in jsonMaps(body['data']))
        jsonInt(item['id']): ?PlayUrl.fromJson(item),
    };
  }

  /// [songUrl] at [level], then every lower tier of
  /// [AudioLevel.fallbackChain] until one has a url. A transport failure
  /// ([ServerUnreachableException]) stops the chain immediately: the lower
  /// tiers would only time out the same way.
  Future<PlayUrl> songUrlWithFallback(
    int id, {
    AudioLevel level = AudioLevel.exhigh,
  }) async {
    AppException? lastError;
    for (final candidate in level.fallbackChain) {
      try {
        final urls = await songUrls([id], level: candidate);
        final url = urls[id];
        if (url != null) return url;
      } on ServerUnreachableException {
        rethrow;
      } on SessionExpiredException {
        rethrow;
      } on ApiException catch (error) {
        lastError = error;
      }
    }
    if (lastError is RiskControlException ||
        lastError is RateLimitedException) {
      throw lastError!;
    }
    throw const SongUnavailableException('歌曲不可播放（版权或会员限制）');
  }

  Future<Lyric> lyric(int id) async {
    final body = await _call('/api/song/lyric', {
      'id': id,
      'tv': -1,
      'lv': -1,
      'rv': -1,
      'kv': -1,
      '_nmclfl': 1,
    });
    return Lyric.parse(
      lrc: (body['lrc'] as Map?)?['lyric'] as String?,
      tlyric: (body['tlyric'] as Map?)?['lyric'] as String?,
      romalrc: (body['romalrc'] as Map?)?['lyric'] as String?,
    );
  }

  /// Every raw lyric document (line, word-by-word, translations, romaji).
  /// `/api/song/lyric/v1` first, the legacy endpoint as fallback.
  Future<LyricPayload> lyricPayload(int id) async {
    try {
      final body = await _call('/api/song/lyric/v1', {
        'id': id,
        'cp': false,
        'tv': -1,
        'lv': -1,
        'rv': -1,
        'kv': -1,
        'yv': -1,
        'ytv': -1,
        'yrv': -1,
      });
      return LyricPayload.fromJson(body);
    } on ApiException catch (error) {
      if (error is RiskControlException || error is RateLimitedException) {
        rethrow;
      }
    }
    final body = await _call('/api/song/lyric', {
      'id': id,
      'tv': -1,
      'lv': -1,
      'rv': -1,
      'kv': -1,
      '_nmclfl': 1,
    });
    return LyricPayload.fromJson(body);
  }

  // ------------------------------------------------------------ comments

  /// A page of [target]'s comments. [pageNo] starts at 1; for
  /// [CommentSort.latest] pass the previous page's [CommentPage.cursor].
  /// The first page also carries up to 15 hot comments.
  Future<CommentPage> comments(
    CommentTarget target, {
    CommentSort sort = CommentSort.recommend,
    int pageSize = 20,
    int pageNo = 1,
    int? cursor,
  }) async {
    final hotFuture = pageNo == 1 && sort != CommentSort.hot
        ? _hotComments(target)
        : Future.value(const <Comment>[]);
    try {
      final body = await _call('/api/v2/resource/comments', {
        'threadId': target.threadId,
        'pageNo': pageNo,
        'pageSize': pageSize,
        'showInner': true,
        'sortType': sort.sortType,
        // Latest pages continue from the last timestamp; the other sorts are
        // offset based.
        'cursor': sort == CommentSort.latest
            ? (pageNo > 1 && cursor != null ? cursor : 0)
            : (pageNo - 1) * pageSize,
      }, notifyExpiry: false);
      final data = jsonMap(body['data']) ?? const <String, dynamic>{};
      return CommentPage.fromV2(data, hotComments: await hotFuture);
    } on ApiException catch (error) {
      if (error is RiskControlException || error is RateLimitedException) {
        rethrow;
      }
    }
    // v1: offset paging, newest first.
    final body = await _call(
      '/api/v1/resource/comments/${target.threadId}',
      {
        'rid': target.id,
        'limit': pageSize,
        'offset': (pageNo - 1) * pageSize,
        'beforeTime': sort == CommentSort.latest ? (cursor ?? 0) : 0,
      },
      webFallback: true,
      notifyExpiry: false,
    );
    final page = CommentPage.fromV1(body);
    if (pageNo > 1) {
      return CommentPage(
        total: page.total,
        hasMore: page.hasMore,
        cursor: page.cursor,
        comments: page.comments,
      );
    }
    return page;
  }

  Future<List<Comment>> _hotComments(CommentTarget target) async {
    try {
      final body = await _call(
        '/api/v1/resource/hotcomments/${target.threadId}',
        {'rid': target.id, 'limit': 15, 'offset': 0, 'beforeTime': 0},
        webFallback: true,
        notifyExpiry: false,
      );
      return Comment.listFrom(body['hotComments']);
    } on AppException {
      return const [];
    }
  }

  /// Likes / unlikes a comment. Needs login.
  Future<void> likeComment(
    CommentTarget target,
    int commentId, {
    required bool like,
  }) async {
    await _call(like ? '/api/v1/comment/like' : '/api/v1/comment/unlike', {
      'threadId': target.threadId,
      'commentId': commentId,
    }, webFallback: true);
  }

  /// Posts a comment (or a reply to [replyToCommentId]). [content] is trimmed
  /// and cut to [commentMaxLength] characters without splitting emoji.
  /// Returns the created comment when the server echoes it.
  Future<Comment?> postComment(
    CommentTarget target,
    String content, {
    int? replyToCommentId,
  }) async {
    final text = normalizeCommentContent(content);
    if (text.isEmpty) throw const ApiException(null, '评论内容不能为空');
    final body = await _call(
      replyToCommentId == null
          ? '/api/resource/comments/add'
          : '/api/resource/comments/reply',
      {
        'threadId': target.threadId,
        'content': text,
        'commentId': ?replyToCommentId,
      },
      webFallback: true,
    );
    final raw = jsonMap(body['comment']);
    return raw == null ? null : Comment.fromJson(raw);
  }

  /// Deletes one of the account's own comments.
  Future<void> deleteComment(CommentTarget target, int commentId) async {
    await _call('/api/resource/comments/delete', {
      'threadId': target.threadId,
      'commentId': commentId,
    }, webFallback: true);
  }

  // -------------------------------------------------------------- like

  /// eapi: the weapi variant is answered with -462 (risk control).
  Future<void> like(int id, {required bool like, int? uid}) async {
    await _call('/api/radio/like', {
      'alg': 'itembased',
      'trackId': id,
      'like': like,
      'time': '3',
      'userid': ?uid,
    });
  }

  Future<List<int>> likedList(int uid) async {
    final body = await _call('/api/song/like/get', {'uid': uid});
    final ids = body['ids'];
    if (ids is! List) return const [];
    return ids.whereType<num>().map((e) => e.toInt()).toList(growable: false);
  }
}
