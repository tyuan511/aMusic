import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../models/paged.dart';
import '../../theme/app_theme.dart';

/// Fetches one page starting at [offset].
typedef PageFetcher<T> = Future<PagedList<T>> Function(int offset, int limit);

/// Infinite, offset-paged list state.
///
/// A [ChangeNotifier] so a list rebuilds when a page lands; responses that
/// arrive after [refresh] (or [dispose]) are dropped by a generation counter.
class PagedController<T> extends ChangeNotifier {
  PagedController(this._fetch, {this.pageSize = 30});

  final PageFetcher<T> _fetch;
  final int pageSize;

  List<T> _items = const [];
  bool _loading = false;
  bool _hasMore = true;
  bool _started = false;
  int _total = 0;
  Object? _error;
  int _generation = 0;
  bool _disposed = false;

  List<T> get items => _items;
  bool get loading => _loading;
  bool get hasMore => _hasMore;
  int get total => _total;
  Object? get error => _error;
  String? get errorText => _error == null ? null : describeError(_error!);

  /// `true` until the first page arrived (or failed).
  bool get initialLoading => !_started || (_loading && _items.isEmpty);

  /// Loads the first page once; later calls are no-ops.
  Future<void> ensureStarted() {
    if (_started) return Future.value();
    return loadMore();
  }

  /// Requests the next page unless one is already in flight or the end was
  /// reached.
  Future<void> loadMore() async {
    if (_loading || (!_hasMore && _started) || _disposed) return;
    _started = true;
    _loading = true;
    _error = null;
    _notify();
    final generation = _generation;
    try {
      final page = await _fetch(_items.length, pageSize);
      if (generation != _generation || _disposed) return;
      _items = [..._items, ...page.items];
      _total = page.total;
      _hasMore = page.hasMore && page.items.isNotEmpty;
    } on Object catch (error) {
      if (generation != _generation || _disposed) return;
      _error = error;
    } finally {
      if (generation == _generation && !_disposed) {
        _loading = false;
        _notify();
      }
    }
  }

  /// Drops everything and loads the first page again.
  Future<void> refresh() {
    _generation++;
    _items = const [];
    _hasMore = true;
    _loading = false;
    _started = false;
    _error = null;
    _total = 0;
    return loadMore();
  }

  void _notify() {
    if (!_disposed) notifyListeners();
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}

/// Calls [onLoadMore] when a vertical scrollable gets within [threshold] px
/// of its end. Wrap any list with it instead of wiring a ScrollController.
class LoadMoreListener extends StatelessWidget {
  const LoadMoreListener({
    super.key,
    required this.child,
    required this.onLoadMore,
    this.threshold = 480,
  });

  final Widget child;
  final VoidCallback onLoadMore;
  final double threshold;

  @override
  Widget build(BuildContext context) {
    return NotificationListener<ScrollNotification>(
      onNotification: (notification) {
        final metrics = notification.metrics;
        if (metrics.axis == Axis.vertical &&
            notification.depth == 0 &&
            metrics.extentAfter < threshold) {
          onLoadMore();
        }
        return false;
      },
      child: child,
    );
  }
}

/// Footer row of a paged list: spinner, error with retry, or "end".
class PagedFooter extends StatelessWidget {
  const PagedFooter({
    super.key,
    required this.loading,
    required this.hasMore,
    this.error,
    this.onRetry,
    this.endText = '已经到底了',
  });

  final bool loading;
  final bool hasMore;
  final String? error;
  final VoidCallback? onRetry;
  final String endText;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final Widget child;
    if (loading) {
      child = const SizedBox(
        key: ValueKey('loading'),
        width: 20,
        height: 20,
        child: CircularProgressIndicator(strokeWidth: 2),
      );
    } else if (error != null) {
      child = TextButton.icon(
        key: const ValueKey('error'),
        onPressed: onRetry,
        icon: const Icon(Icons.refresh_rounded, size: 18),
        label: Text('加载失败，点击重试（$error）', maxLines: 1),
      );
    } else {
      child = Text(
        hasMore ? '' : endText,
        key: ValueKey('end-$hasMore'),
        style: context.text.bodySmall?.copyWith(color: s.textTertiary),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 18),
      child: Center(
        child: AnimatedSwitcher(duration: AppMotion.quick, child: child),
      ),
    );
  }
}
