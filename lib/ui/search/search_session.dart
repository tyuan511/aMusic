import 'dart:async';

import 'package:flutter/foundation.dart';

import '../../models/paged.dart';
import '../../models/search.dart';
import '../../services/app.dart';
import '../browse_widgets/paged.dart';

/// Result tabs of the search page.
enum SearchTab {
  songs('单曲'),
  albums('专辑'),
  artists('歌手'),
  playlists('歌单');

  const SearchTab(this.label);

  final String label;
}

/// Fetches one page of [tab] results for [keyword].
typedef SearchFetcher = Future<PagedList<Object>> Function(
  SearchTab tab,
  String keyword,
  int offset,
  int limit,
);

/// Default fetcher backed by `app.library`.
Future<PagedList<Object>> librarySearch(
  SearchTab tab,
  String keyword,
  int offset,
  int limit,
) async {
  final library = app.library;
  switch (tab) {
    case SearchTab.songs:
      final result = await library.searchSongs(
        keyword,
        offset: offset,
        limit: limit,
      );
      return PagedList<Object>(
        items: result.songs,
        total: result.total,
        hasMore: PagedList.moreByTotal(
          offset: offset,
          received: result.songs.length,
          total: result.total,
        ),
      );
    case SearchTab.albums:
      return _erase(
        await library.searchAlbums(keyword, offset: offset, limit: limit),
      );
    case SearchTab.artists:
      return _erase(
        await library.searchArtists(keyword, offset: offset, limit: limit),
      );
    case SearchTab.playlists:
      return _erase(
        await library.searchPlaylists(keyword, offset: offset, limit: limit),
      );
  }
}

PagedList<Object> _erase<T extends Object>(PagedList<T> page) =>
    PagedList<Object>(
      items: page.items,
      total: page.total,
      hasMore: page.hasMore,
      cursor: page.cursor,
    );

/// Results of one keyword, one lazily created [PagedController] per tab.
///
/// Switching tabs keeps every tab's loaded pages (and the fetch is not
/// repeated); a new keyword disposes them all.
class SearchSession {
  SearchSession({this.fetcher = librarySearch, this.pageSize = 30});

  final SearchFetcher fetcher;
  final int pageSize;

  String _keyword = '';
  final Map<SearchTab, PagedController<Object>> _tabs = {};

  String get keyword => _keyword;

  /// Starts over for [keyword]; returns `false` when it did not change.
  bool setKeyword(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed == _keyword) return false;
    _clear();
    _keyword = trimmed;
    return true;
  }

  /// Controller of [tab], created (and its first page requested) on first
  /// use.
  PagedController<Object> controllerFor(SearchTab tab) {
    return _tabs.putIfAbsent(tab, () {
      final keyword = _keyword;
      final controller = PagedController<Object>(
        (offset, limit) => fetcher(tab, keyword, offset, limit),
        pageSize: pageSize,
      );
      if (keyword.isNotEmpty) unawaited(controller.ensureStarted());
      return controller;
    });
  }

  /// Whether [tab] already has a controller (results cached).
  bool isCached(SearchTab tab) => _tabs.containsKey(tab);

  void _clear() {
    for (final controller in _tabs.values) {
      controller.dispose();
    }
    _tabs.clear();
  }

  void dispose() => _clear();
}

/// Debounced live suggestions with a generation guard: a response that
/// arrives after a newer query was typed (or after [cancel]) is dropped.
class SuggestionDebouncer {
  SuggestionDebouncer({
    required this.fetch,
    this.delay = const Duration(milliseconds: 250),
  });

  final Future<SearchSuggestions> Function(String keyword) fetch;
  final Duration delay;

  /// Latest suggestions for [query] (`null` while none apply).
  final ValueNotifier<SearchSuggestions?> suggestions = ValueNotifier(null);

  Timer? _timer;
  int _generation = 0;
  String _query = '';

  String get query => _query;

  /// Schedules a lookup for [text]; empty text clears immediately.
  void update(String text) {
    final trimmed = text.trim();
    _timer?.cancel();
    final generation = ++_generation;
    _query = trimmed;
    if (trimmed.isEmpty) {
      suggestions.value = null;
      return;
    }
    _timer = Timer(delay, () async {
      SearchSuggestions result;
      try {
        result = await fetch(trimmed);
      } on Object {
        result = SearchSuggestions.empty;
      }
      if (generation != _generation) return;
      suggestions.value = result;
    });
  }

  /// Drops pending lookups and hides the suggestions.
  void cancel() {
    _timer?.cancel();
    _generation++;
    suggestions.value = null;
  }

  void dispose() {
    _timer?.cancel();
    _generation++;
    suggestions.dispose();
  }
}
