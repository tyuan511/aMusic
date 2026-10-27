import 'dart:async';

/// Minimal TTL cache for in-flight and completed async work.
///
/// Used for API responses that are re-requested constantly while navigating
/// (playlist details, lyrics, search results) so that going back to a screen is
/// instant and the server is not hammered.
class AsyncCache<K, V> {
  AsyncCache({
    this.ttl = const Duration(minutes: 5),
    this.maxEntries = 32,
    this.keepOnError = false,
  });

  final Duration ttl;
  final int maxEntries;
  final bool keepOnError;

  final Map<K, _Entry<V>> _entries = {};

  _Entry<V>? _valid(K key) {
    final entry = _entries[key];
    if (entry == null) return null;
    if (entry.expiresAt.isBefore(DateTime.now())) {
      _entries.remove(key);
      return null;
    }
    return entry;
  }

  /// Returns a cached value, a running load, or starts [loader].
  Future<V> get(K key, Future<V> Function() loader) {
    final cached = _valid(key);
    if (cached != null) {
      if (cached.future != null) return cached.future!;
      return Future.value(cached.value as V);
    }
    late final _Entry<V> pending;
    final future = loader().then(
      (value) {
        // Only commit when nobody invalidated / replaced the load meanwhile
        // (e.g. a sign out while a private list was still in flight).
        if (identical(_entries[key], pending)) {
          _entries[key] = _Entry(value: value, expiresAt: _expires());
          _evict();
        }
        return value;
      },
      onError: (Object error, StackTrace stack) {
        if (identical(_entries[key], pending)) _entries.remove(key);
        Error.throwWithStackTrace(error, stack);
      },
    );
    // Remember the future so parallel callers share one request.
    pending = _Entry<V>.pending(future, _expires());
    _entries[key] = pending;
    return future;
  }

  /// Synchronous peek, `null` when not cached or still loading.
  V? peek(K key) {
    final entry = _valid(key);
    if (entry == null || entry.future != null) return null;
    return entry.value;
  }

  DateTime _expires() => DateTime.now().add(ttl);

  void invalidate(K key) => _entries.remove(key);

  /// Drops every entry whose key matches [test] (e.g. all scopes of one id).
  void invalidateWhere(bool Function(K key) test) =>
      _entries.removeWhere((key, _) => test(key));

  void clear() => _entries.clear();

  void _evict() {
    while (_entries.length > maxEntries) {
      _entries.remove(_entries.keys.first);
    }
  }
}

class _Entry<V> {
  _Entry({required this.value, required this.expiresAt}) : future = null;

  _Entry.pending(Future<V> this.future, this.expiresAt) : value = null;

  final V? value;
  final Future<V>? future;
  final DateTime expiresAt;
}
