import 'album.dart';
import 'json_utils.dart';
import 'playlist.dart';
import 'song.dart';

/// `/api/search/defaultkeyword/get`: what the empty search box shows.
class DefaultSearchKeyword {
  const DefaultSearchKeyword({required this.display, required this.keyword});

  /// Placeholder text ("🔥Moments 最近很火哦").
  final String display;

  /// What to actually search when the user submits the empty box.
  final String keyword;

  factory DefaultSearchKeyword.fromJson(Map<String, dynamic> body) {
    final data = jsonMap(body['data']) ?? const <String, dynamic>{};
    final keyword = jsonText(data['realkeyword']) ?? '';
    return DefaultSearchKeyword(
      display: jsonText(data['showKeyword']) ?? keyword,
      keyword: keyword,
    );
  }
}

/// Type-ahead results: plain keywords plus the best matching entities.
class SearchSuggestions {
  const SearchSuggestions({
    this.keywords = const [],
    this.songs = const [],
    this.artists = const [],
    this.albums = const [],
    this.playlists = const [],
  });

  static const SearchSuggestions empty = SearchSuggestions();

  final List<String> keywords;
  final List<Song> songs;
  final List<Artist> artists;
  final List<Album> albums;
  final List<Playlist> playlists;

  bool get isEmpty =>
      keywords.isEmpty &&
      songs.isEmpty &&
      artists.isEmpty &&
      albums.isEmpty &&
      playlists.isEmpty;

  /// `result` of `/api/search/suggest/web` plus the keyword list.
  factory SearchSuggestions.fromJson(
    Map<String, dynamic>? result, {
    List<String> keywords = const [],
  }) {
    if (result == null) return SearchSuggestions(keywords: keywords);
    return SearchSuggestions(
      keywords: keywords,
      songs: Song.listFrom(result['songs']),
      artists: Artist.listFrom(result['artists']),
      albums: Album.listFrom(result['albums']),
      playlists: Playlist.listFrom(result['playlists']),
    );
  }
}
