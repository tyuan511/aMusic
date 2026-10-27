/// One page of a server side list.
class PagedList<T> {
  const PagedList({
    required this.items,
    this.total = 0,
    this.hasMore = false,
    this.cursor,
  });

  const PagedList.empty()
    : items = const [],
      total = 0,
      hasMore = false,
      cursor = null;

  final List<T> items;

  /// Total number of results the server reports (0 when unknown).
  final int total;

  /// Whether requesting the next page can return more items.
  final bool hasMore;

  /// Opaque continuation value for cursor based endpoints (e.g. the
  /// `before` timestamp of high quality playlists); `null` for offset paging.
  final int? cursor;

  bool get isEmpty => items.isEmpty;

  /// `hasMore` for offset paged endpoints that only report a total.
  static bool moreByTotal({
    required int offset,
    required int received,
    required int total,
    bool? serverMore,
  }) {
    if (received == 0) return false;
    if (serverMore != null) return serverMore;
    return offset + received < total;
  }
}

/// Search results are plain pages.
typedef SearchPage<T> = PagedList<T>;
