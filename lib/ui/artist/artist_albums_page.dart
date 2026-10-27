import 'dart:async';

import 'package:flutter/material.dart';

import '../../models/album.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/future_section.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/media_cards.dart';
import '../browse_widgets/paged.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';

/// Every release of an artist as an infinitely paged grid.
class ArtistAlbumsPage extends StatefulWidget {
  const ArtistAlbumsPage({super.key, required this.artistId});

  final int artistId;

  @override
  State<ArtistAlbumsPage> createState() => _ArtistAlbumsPageState();
}

class _ArtistAlbumsPageState extends State<ArtistAlbumsPage> {
  late final PagedController<Album> _controller = PagedController<Album>(
    (offset, limit) =>
        app.library.artistAlbums(widget.artistId, offset: offset, limit: limit),
  );
  String _name = '';

  @override
  void initState() {
    super.initState();
    unawaited(_controller.ensureStarted());
    app.library.artistDetail(widget.artistId).then((detail) {
      if (mounted) setState(() => _name = detail.name);
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      children: [
        SizedBox(height: top),
        ContentBox(
          child: PageHeader(title: _name.isEmpty ? '全部专辑' : '$_name 的专辑'),
        ),
        Expanded(
          child: ListenableBuilder(
            listenable: _controller,
            builder: (context, _) {
              final Widget child;
              if (_controller.initialLoading) {
                child = const Padding(
                  key: ValueKey('loading'),
                  padding: EdgeInsets.only(top: 12),
                  child: CardShelfSkeleton(itemWidth: 160),
                );
              } else if (_controller.items.isEmpty &&
                  _controller.errorText != null) {
                child = ErrorView(
                  key: const ValueKey('error'),
                  message: _controller.errorText!,
                  onRetry: _controller.refresh,
                );
              } else if (_controller.items.isEmpty) {
                child = const EmptyView(
                  key: ValueKey('empty'),
                  message: '暂无专辑',
                  icon: Icons.album_outlined,
                );
              } else {
                child = _grid(context);
              }
              return AnimatedSwitcher(
                duration: AppMotion.standard,
                child: child,
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _grid(BuildContext context) {
    final albums = _controller.items;
    return LoadMoreListener(
      key: const ValueKey('grid'),
      onLoadMore: _controller.loadMore,
      child: CustomScrollView(
        slivers: [
          SliverContent(
            horizontal: AppMetrics.gutter,
            top: 8,
            sliver: SliverCoverGrid(
              itemCount: albums.length,
              maxItemWidth: 200,
              itemBuilder: (context, index) =>
                  AlbumCard(album: albums[index], showArtist: false),
            ),
          ),
          SliverToBoxAdapter(
            child: PagedFooter(
              loading: _controller.loading,
              hasMore: _controller.hasMore,
              error: _controller.errorText,
              onRetry: _controller.loadMore,
            ),
          ),
          const SliverShellBottomInset(),
        ],
      ),
    );
  }
}
