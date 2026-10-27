import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../theme/app_theme.dart';
import 'kit.dart';

/// Loading / error / empty / data wrapper around a [Future].
///
/// The future is created once per state; pass a distinct [Key] when the query
/// changes so a new load is started. Switching between the loading, error and
/// data states cross-fades.
class AsyncView<T> extends StatefulWidget {
  const AsyncView({
    super.key,
    required this.load,
    required this.builder,
    this.onRefresh,
    this.emptyWhen,
    this.emptyView,
    this.placeholder,
    this.padding,
    this.skeleton = false,
  });

  final Future<T> Function() load;
  final Widget Function(BuildContext context, T data) builder;

  /// When provided the view becomes pull-to-refreshable.
  final Future<void> Function()? onRefresh;

  /// Decides whether [data] should render [emptyView] instead.
  final bool Function(T data)? emptyWhen;
  final Widget? emptyView;
  final Widget? placeholder;
  final EdgeInsetsGeometry? padding;

  /// Without a [placeholder], show shimmering list-row skeletons instead of
  /// the centred spinner while loading.
  final bool skeleton;

  @override
  State<AsyncView<T>> createState() => _AsyncViewState<T>();
}

class _AsyncViewState<T> extends State<AsyncView<T>> {
  late Future<T> _future = widget.load();

  Future<void> _reload() async {
    setState(() => _future = widget.load());
    try {
      await _future;
    } on Object {
      // The error is rendered by the builder below.
    }
    if (widget.onRefresh != null) await widget.onRefresh!();
  }

  @override
  Widget build(BuildContext context) {
    final content = FutureBuilder<T>(
      future: _future,
      builder: (context, snapshot) {
        final Widget child;
        final String state;
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          state = 'loading';
          child =
              widget.placeholder ??
              (widget.skeleton
                  ? const SingleChildScrollView(
                      physics: NeverScrollableScrollPhysics(),
                      padding: EdgeInsets.symmetric(
                        horizontal: AppMetrics.gutter - 10,
                        vertical: 12,
                      ),
                      child: MediaRowSkeletonList(count: 8),
                    )
                  : const CenteredLoader());
        } else if (snapshot.hasError) {
          state = 'error';
          child = ErrorView(
            message: describeError(snapshot.error!),
            onRetry: _reload,
          );
        } else if (!snapshot.hasData) {
          state = 'none';
          child = const SizedBox.shrink();
        } else {
          final data = snapshot.data as T;
          if (widget.emptyWhen?.call(data) ?? false) {
            state = 'empty';
            child = widget.emptyView ?? const EmptyView(message: '这里什么都没有');
          } else {
            state = 'data';
            child = widget.builder(context, data);
          }
        }
        return AnimatedSwitcher(
          duration: AppMotion.standard,
          switchInCurve: AppMotion.enter,
          switchOutCurve: AppMotion.exit,
          child: KeyedSubtree(key: ValueKey(state), child: child),
        );
      },
    );

    if (widget.onRefresh == null) return content;
    return RefreshIndicator(onRefresh: _reload, child: content);
  }
}

class CenteredLoader extends StatelessWidget {
  const CenteredLoader({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: SizedBox(
        width: 26,
        height: 26,
        child: CircularProgressIndicator(strokeWidth: 2.4),
      ),
    );
  }
}

class ErrorView extends StatelessWidget {
  const ErrorView({
    super.key,
    required this.message,
    this.onRetry,
    this.compact = false,
  });

  final String message;
  final VoidCallback? onRetry;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.wifi_tethering_error_rounded,
              size: compact ? 32 : 44,
              color: context.surfaces.textTertiary,
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.surfaces.textSecondary,
              ),
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              FilledButton.icon(
                icon: const Icon(Icons.refresh_rounded, size: 18),
                label: const Text('重试'),
                onPressed: onRetry,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class EmptyView extends StatelessWidget {
  const EmptyView({
    super.key,
    this.message = '这里什么都没有',
    this.icon = Icons.inbox_rounded,
  });

  final String message;
  final IconData icon;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 44, color: context.surfaces.textTertiary),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: context.text.bodyMedium?.copyWith(
                color: context.surfaces.textSecondary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
