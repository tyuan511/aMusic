import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../theme/app_theme.dart';
import '../widgets/kit.dart';

/// Marks [future]'s error as handled (a section that is never shown must not
/// report an uncaught error) and returns it unchanged for later listeners.
Future<T> guardFuture<T>(Future<T> future) {
  future.ignore();
  return future;
}

/// One independently loading block of a page (a home shelf, an artist tab).
///
/// Skeleton while loading, a compact error with retry on failure, nothing
/// when [hideWhen] says the data is empty, else [builder]. State changes
/// cross-fade and the block resizes smoothly.
class FutureSection<T> extends StatelessWidget {
  const FutureSection({
    super.key,
    required this.future,
    required this.builder,
    this.onRetry,
    this.skeleton,
    this.hideWhen,
    this.empty,
  });

  final Future<T>? future;
  final Widget Function(BuildContext context, T data) builder;
  final VoidCallback? onRetry;

  /// Defaults to three media-row skeletons.
  final Widget? skeleton;

  /// Data for which the whole section disappears (or shows [empty]).
  final bool Function(T data)? hideWhen;
  final Widget? empty;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<T>(
      future: future,
      builder: (context, snapshot) {
        final String state;
        final Widget child;
        if (snapshot.hasError) {
          state = 'error';
          child = SectionError(
            message: describeError(snapshot.error!),
            onRetry: onRetry,
          );
        } else if (!snapshot.hasData) {
          state = 'loading';
          child =
              skeleton ??
              const MediaRowSkeletonList(
                count: 3,
                padding: EdgeInsets.symmetric(
                  horizontal: AppMetrics.gutter - 10,
                ),
              );
        } else if (hideWhen?.call(snapshot.data as T) ?? false) {
          state = 'empty';
          child = empty ?? const SizedBox(width: double.infinity);
        } else {
          state = 'data';
          child = builder(context, snapshot.data as T);
        }
        return AnimatedSize(
          duration: AppMotion.standard,
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: AnimatedSwitcher(
            duration: AppMotion.standard,
            switchInCurve: AppMotion.enter,
            layoutBuilder: (current, previous) => Stack(
              alignment: Alignment.topCenter,
              children: [...previous, ?current],
            ),
            child: KeyedSubtree(key: ValueKey(state), child: child),
          ),
        );
      },
    );
  }
}

/// Inline error for one section: message + retry, without taking the page.
class SectionError extends StatelessWidget {
  const SectionError({super.key, required this.message, this.onRetry});

  final String message;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.symmetric(
        horizontal: AppMetrics.gutter,
        vertical: 8,
      ),
      child: Container(
        padding: const EdgeInsets.fromLTRB(18, 12, 10, 12),
        decoration: BoxDecoration(
          color: s.card,
          borderRadius: BorderRadius.circular(AppMetrics.radiusMd),
        ),
        child: Row(
          children: [
            Icon(Icons.cloud_off_rounded, size: 20, color: s.textTertiary),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodySmall?.copyWith(color: s.textSecondary),
              ),
            ),
            if (onRetry != null)
              TextButton(onPressed: onRetry, child: const Text('重试')),
          ],
        ),
      ),
    );
  }
}

/// Row of cover-card skeletons for shelves / grids while loading.
class CardShelfSkeleton extends StatelessWidget {
  const CardShelfSkeleton({super.key, this.itemWidth = 150, this.count = 6});

  final double itemWidth;
  final int count;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: itemWidth + 56,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        physics: const NeverScrollableScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: AppMetrics.gutter),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 14),
        itemBuilder: (context, index) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Skeleton(
              width: itemWidth,
              height: itemWidth,
              radius: AppMetrics.radiusMd,
            ),
            const SizedBox(height: 10),
            Skeleton(width: itemWidth * 0.8, height: 13),
            const SizedBox(height: 6),
            Skeleton(width: itemWidth * 0.5, height: 10),
          ],
        ),
      ),
    );
  }
}
