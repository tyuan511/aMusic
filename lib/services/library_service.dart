import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/async_cache.dart';
import '../core/errors.dart';
import '../data/ncm_api.dart';
import '../models/album.dart';
import '../models/artist.dart';
import '../models/comment.dart';
import '../models/comment_target.dart';
import '../models/discovery.dart';
import '../models/lyric_payload.dart';
import '../models/paged.dart';
import '../models/playlist.dart';
import '../models/search.dart';
import '../models/song.dart';
import '../models/user.dart';
import 'api_host.dart';
import 'session_service.dart';

/// Cached read API for the UI plus the user's liked song ids and the
/// library mutations.
///
/// Every cache key starts with the account scope (uid or `guest`), so one
/// account never sees another account's private data (privileges, private
/// playlists, subscription flags). Switching accounts clears everything.
class LibraryService {
  LibraryService(this._host, this._session) {
    _scopeUid = _session.value.profile?.id;
    _session.addListener(_onSessionChanged);
  }

  final ApiHost _host;
  final SessionService _session;

  NcmApi get _api => _host.api;

  /// Ids of the user's liked songs. Empty when signed out.
  final ValueNotifier<Set<int>> likedIds = ValueNotifier(const {});

  int? _scopeUid;

  /// Id of "我喜欢的音乐", learned from [userCollections].
  int? _likedPlaylistId;

  final AsyncCache<String, Playlist> _playlists = AsyncCache(
    ttl: const Duration(minutes: 10),
    maxEntries: 24,
  );
  final AsyncCache<int, List<Playlist>> _userPlaylists = AsyncCache(
    ttl: const Duration(minutes: 5),
    maxEntries: 2,
  );
  final AsyncCache<String, UserDetail> _userDetails = AsyncCache(
    ttl: const Duration(minutes: 10),
    maxEntries: 8,
  );
  final AsyncCache<String, List<PlayRecordEntry>> _playRecords = AsyncCache(
    ttl: const Duration(minutes: 5),
    maxEntries: 4,
  );
  final AsyncCache<String, Playlist> _dailyRecommend = AsyncCache(
    ttl: const Duration(minutes: 30),
    maxEntries: 1,
  );
  final AsyncCache<String, List<Playlist>> _discover = AsyncCache(
    ttl: const Duration(minutes: 10),
    maxEntries: 2,
  );
  final AsyncCache<String, ({List<Song> songs, int total})> _search =
      AsyncCache(ttl: const Duration(minutes: 5), maxEntries: 24);

  /// Album / artist / playlist search pages (values are `PagedList<T>`).
  final AsyncCache<String, Object> _searchPages = AsyncCache(
    ttl: const Duration(minutes: 5),
    maxEntries: 36,
  );
  final AsyncCache<String, List<String>> _hotWords = AsyncCache(
    ttl: const Duration(hours: 1),
    maxEntries: 1,
  );
  final AsyncCache<String, DefaultSearchKeyword> _defaultKeyword = AsyncCache(
    ttl: const Duration(minutes: 10),
    maxEntries: 1,
  );
  final AsyncCache<String, List<Toplist>> _toplists = AsyncCache(
    ttl: const Duration(minutes: 30),
    maxEntries: 1,
  );
  final AsyncCache<String, PlaylistCatalogue> _categories = AsyncCache(
    ttl: const Duration(days: 1),
    maxEntries: 1,
  );

  /// New songs / new albums / playlist square / banners (30 min).
  final AsyncCache<String, Object> _feeds = AsyncCache(
    ttl: const Duration(minutes: 30),
    maxEntries: 48,
  );

  /// Artist detail / top songs / songs / albums / description / similar.
  final AsyncCache<String, Object> _artists = AsyncCache(
    ttl: const Duration(minutes: 45),
    maxEntries: 48,
  );
  final AsyncCache<String, Album> _albums = AsyncCache(
    ttl: const Duration(hours: 1),
    maxEntries: 24,
  );
  final AsyncCache<String, LyricPayload> _lyrics = AsyncCache(
    ttl: const Duration(hours: 6),
    maxEntries: 32,
  );

  /// `uid` or `guest`, prefix of every account dependent cache key.
  String get scope => _session.value.profile?.id.toString() ?? 'guest';

  int? get _uid => _session.value.profile?.id;

  void _onSessionChanged() {
    final uid = _session.value.profile?.id;
    if (uid == _scopeUid) return;
    _scopeUid = uid;
    _likedPlaylistId = null;
    likedIds.value = const {};
    clearCaches();
    unawaited(refreshLikedIds());
  }

  bool isLiked(int songId) => likedIds.value.contains(songId);

  Future<void> refreshLikedIds() async {
    final uid = _uid;
    if (uid == null) {
      likedIds.value = const {};
      return;
    }
    try {
      final ids = (await _api.likedList(uid)).toSet();
      if (_uid == uid) likedIds.value = ids;
    } on AppException {
      // Keep whatever we had; the list is not worth an error dialog.
    }
  }

  /// Optimistic like/unlike. Returns `false` and rolls back when the server
  /// rejects it.
  Future<bool> toggleLike(int songId, {required bool like}) async {
    final previous = likedIds.value;
    final next = {...previous};
    if (like) {
      next.add(songId);
    } else {
      next.remove(songId);
    }
    likedIds.value = next;
    try {
      await _api.like(songId, like: like, uid: _uid);
      final likedPlaylist = _likedPlaylistId;
      if (likedPlaylist != null) invalidatePlaylist(likedPlaylist);
      return true;
    } catch (error, stack) {
      debugPrint('[like] $songId like=$like failed: $error\n$stack');
      likedIds.value = previous;
      return false;
    }
  }

  // ------------------------------------------------------------ account

  Future<List<Playlist>> userPlaylists() async {
    final uid = _uid;
    if (uid == null) return const [];
    return _userPlaylists.get(uid, () => _api.userPlaylists(uid));
  }

  /// The account's playlists split into liked / created / collected.
  /// [UserCollections.empty] for guests.
  Future<UserCollections> userCollections() async {
    final uid = _uid;
    if (uid == null) return UserCollections.empty;
    final collections = UserCollections.split(await userPlaylists(), uid);
    _likedPlaylistId = collections.liked?.id ?? _likedPlaylistId;
    return collections;
  }

  /// Public profile of any user (defaults to the signed in one).
  Future<UserDetail?> userDetail([int? uid]) async {
    final id = uid ?? _uid;
    if (id == null) return null;
    return _userDetails.get('$scope|$id', () => _api.userDetail(id));
  }

  /// Listening ranking of [uid] (defaults to the signed in account).
  Future<List<PlayRecordEntry>> playRecord({int? uid, bool week = true}) async {
    final id = uid ?? _uid;
    if (id == null) return const [];
    return _playRecords.get(
      '$scope|$id|$week',
      () => _api.playRecord(id, week: week),
    );
  }

  /// Reports a finished play; never throws (history is best effort).
  Future<void> scrobble(int songId, {int? sourceId, int seconds = 0}) async {
    if (_uid == null) return;
    try {
      await _api.scrobble(songId, sourceId: sourceId, seconds: seconds);
      _playRecords.clear();
    } on AppException {
      // Not worth surfacing.
    }
  }

  Future<Playlist> createPlaylist(String name, {bool private = false}) async {
    final playlist = await _api.createPlaylist(name, private: private);
    _userPlaylists.clear();
    return playlist;
  }

  Future<void> deletePlaylist(int id) async {
    await _api.deletePlaylist(id);
    invalidatePlaylist(id);
    _userPlaylists.clear();
  }

  Future<void> addToPlaylist(int playlistId, List<int> songIds) async {
    try {
      await _api.addToPlaylist(playlistId, songIds);
    } finally {
      // Also after a partial failure: the server may have applied it.
      invalidatePlaylist(playlistId);
      _userPlaylists.clear();
    }
  }

  Future<void> removeFromPlaylist(int playlistId, List<int> songIds) async {
    try {
      await _api.removeFromPlaylist(playlistId, songIds);
    } finally {
      invalidatePlaylist(playlistId);
      _userPlaylists.clear();
    }
  }

  Future<void> subscribePlaylist(int id, {required bool subscribe}) async {
    await _api.subscribePlaylist(id, subscribe: subscribe);
    invalidatePlaylist(id);
    _userPlaylists.clear();
  }

  // ------------------------------------------------------------ playlists

  Future<Playlist> playlistDetail(int id) {
    if (id == Playlist.dailyRecommendId) {
      return _dailyRecommend.get('$scope|daily', () async {
        final songs = await _api.dailyRecommendSongs();
        return Playlist(
          id: Playlist.dailyRecommendId,
          name: '每日歌曲推荐',
          description: '根据你的口味生成，每天 6:00 更新',
          creator: const PlaylistCreator(id: 0, nickname: 'aMusic'),
          tracks: songs,
          isDailyRecommend: true,
        );
      });
    }
    return _playlists.get('$scope|$id', () => _api.playlistDetail(id));
  }

  /// Recommended playlists; falls back to the public personalized feed when the
  /// user is signed out.
  Future<List<Playlist>> discoverPlaylists() {
    return _discover.get(scope, () async {
      if (_session.value.isLoggedIn) {
        try {
          final list = await _api.recommendPlaylists();
          if (list.isNotEmpty) return list;
        } on AppException {
          // fall through to the public feed
        }
      }
      return _api.personalizedPlaylists();
    });
  }

  void invalidatePlaylist(int id) {
    if (id == Playlist.dailyRecommendId) {
      _dailyRecommend.clear();
      return;
    }
    _playlists.invalidateWhere((key) => key.endsWith('|$id'));
  }

  // ------------------------------------------------------------ discovery

  /// Not cached: every call is a fresh batch.
  Future<List<Song>> personalFm() => _api.personalFm();

  Future<void> fmTrash(int songId) => _api.fmTrash(songId);

  /// Not cached: depends on the seed song.
  Future<List<Song>> heartModeList(int songId, int playlistId) =>
      _api.heartModeList(songId, playlistId);

  Future<List<Toplist>> toplists() => _toplists.get(scope, _api.toplists);

  Future<PlaylistCatalogue> playlistCategories() =>
      _categories.get(scope, _api.playlistCategories);

  Future<PagedList<Playlist>> topPlaylists({
    String cat = '全部',
    String order = 'hot',
    int limit = 50,
    int offset = 0,
  }) => _typed(
    _feeds,
    '$scope|top|$cat|$order|$limit|$offset',
    () =>
        _api.topPlaylists(cat: cat, order: order, limit: limit, offset: offset),
  );

  Future<PagedList<Playlist>> highQualityPlaylists({
    String cat = '全部',
    int limit = 50,
    int? before,
  }) => _typed(
    _feeds,
    '$scope|hq|$cat|$limit|$before',
    () => _api.highQualityPlaylists(cat: cat, limit: limit, before: before),
  );

  Future<List<Song>> newSongs({int areaId = 0}) => _typed(
    _feeds,
    '$scope|newSongs|$areaId',
    () => _api.newSongs(areaId: areaId),
  );

  Future<PagedList<Album>> newAlbums({
    String area = 'ALL',
    int limit = 30,
    int offset = 0,
  }) => _typed(
    _feeds,
    '$scope|newAlbums|$area|$limit|$offset',
    () => _api.newAlbums(area: area, limit: limit, offset: offset),
  );

  Future<List<HomeBanner>> banners() =>
      _typed(_feeds, '$scope|banners', _api.banners);

  // --------------------------------------------------------------- search

  Future<List<String>> hotSearchWords() =>
      _hotWords.get('hot', _api.hotSearchWords);

  /// Keyword completions (not cached, never throws).
  Future<List<String>> searchSuggest(String keyword) =>
      _api.searchSuggest(keyword);

  /// Keywords + matching songs / artists / albums (never throws).
  Future<SearchSuggestions> searchSuggestions(String keyword) =>
      _api.searchSuggestions(keyword);

  Future<DefaultSearchKeyword> defaultKeyword() =>
      _defaultKeyword.get(scope, _api.defaultKeyword);

  Future<({List<Song> songs, int total})> searchSongs(
    String keyword, {
    int offset = 0,
    int limit = 30,
  }) => _search.get(
    '$scope|$keyword|$offset|$limit',
    () => _api.searchSongs(keyword, offset: offset, limit: limit),
  );

  Future<SearchPage<Album>> searchAlbums(
    String keyword, {
    int offset = 0,
    int limit = 30,
  }) => _typed(
    _searchPages,
    '$scope|album|$keyword|$offset|$limit',
    () => _api.searchAlbums(keyword, offset: offset, limit: limit),
  );

  Future<SearchPage<Artist>> searchArtists(
    String keyword, {
    int offset = 0,
    int limit = 30,
  }) => _typed(
    _searchPages,
    '$scope|artist|$keyword|$offset|$limit',
    () => _api.searchArtists(keyword, offset: offset, limit: limit),
  );

  Future<SearchPage<Playlist>> searchPlaylists(
    String keyword, {
    int offset = 0,
    int limit = 30,
  }) => _typed(
    _searchPages,
    '$scope|playlist|$keyword|$offset|$limit',
    () => _api.searchPlaylists(keyword, offset: offset, limit: limit),
  );

  // --------------------------------------------------------------- artist

  Future<ArtistDetail> artistDetail(int id) =>
      _typed(_artists, '$scope|detail|$id', () => _api.artistDetail(id));

  Future<List<Song>> artistTopSongs(int id) =>
      _typed(_artists, '$scope|top|$id', () => _api.artistTopSongs(id));

  Future<PagedList<Song>> artistSongs(
    int id, {
    String order = 'hot',
    int limit = 50,
    int offset = 0,
  }) => _typed(
    _artists,
    '$scope|songs|$id|$order|$limit|$offset',
    () => _api.artistSongs(id, order: order, limit: limit, offset: offset),
  );

  Future<PagedList<Album>> artistAlbums(
    int id, {
    int limit = 30,
    int offset = 0,
  }) => _typed(
    _artists,
    '$scope|albums|$id|$limit|$offset',
    () => _api.artistAlbums(id, limit: limit, offset: offset),
  );

  Future<ArtistDescription> artistDescription(int id) =>
      _typed(_artists, '$scope|desc|$id', () => _api.artistDescription(id));

  /// `[]` for guests.
  Future<List<Artist>> similarArtists(int id) =>
      _typed(_artists, '$scope|similar|$id', () => _api.similarArtists(id));

  // ---------------------------------------------------------------- album

  Future<Album> albumDetail(int id) =>
      _albums.get('$scope|$id', () => _api.albumDetail(id));

  // --------------------------------------------------------------- lyrics

  /// Raw lyric documents (cached 6 h). Parsing belongs to the lyric layer.
  Future<LyricPayload> lyricPayload(int songId) =>
      _lyrics.get('$scope|$songId', () => _api.lyricPayload(songId));

  // ------------------------------------------------------------- comments

  /// Not cached (like counts / own comments change constantly).
  Future<CommentPage> comments(
    CommentTarget target, {
    CommentSort sort = CommentSort.recommend,
    int pageSize = 20,
    int pageNo = 1,
    int? cursor,
  }) => _api.comments(
    target,
    sort: sort,
    pageSize: pageSize,
    pageNo: pageNo,
    cursor: cursor,
  );

  Future<void> likeComment(
    CommentTarget target,
    int commentId, {
    required bool like,
  }) => _api.likeComment(target, commentId, like: like);

  Future<Comment?> postComment(
    CommentTarget target,
    String content, {
    int? replyToCommentId,
  }) => _api.postComment(target, content, replyToCommentId: replyToCommentId);

  Future<void> deleteComment(CommentTarget target, int commentId) =>
      _api.deleteComment(target, commentId);

  // ---------------------------------------------------------------- misc

  /// Shared caches store `Object`; this restores the static type.
  static Future<T> _typed<T extends Object>(
    AsyncCache<String, Object> cache,
    String key,
    Future<T> Function() loader,
  ) async => await cache.get(key, loader) as T;

  void clearCaches() {
    _playlists.clear();
    _userPlaylists.clear();
    _userDetails.clear();
    _playRecords.clear();
    _dailyRecommend.clear();
    _discover.clear();
    _search.clear();
    _searchPages.clear();
    _hotWords.clear();
    _defaultKeyword.clear();
    _toplists.clear();
    _categories.clear();
    _feeds.clear();
    _artists.clear();
    _albums.clear();
    _lyrics.clear();
  }

  void dispose() => _session.removeListener(_onSessionChanged);
}
