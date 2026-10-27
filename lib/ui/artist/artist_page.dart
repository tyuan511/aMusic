import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/errors.dart';
import '../../core/format.dart';
import '../../models/album.dart';
import '../../models/artist.dart';
import '../../models/song.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart' show LimePillButton;
import '../browse_widgets/detail_header.dart';
import '../browse_widgets/future_section.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/playback.dart';
import '../browse_widgets/sheets.dart';
import '../widgets/kit.dart';
import 'artist_sections.dart';

/// Tabs of the artist page.
enum ArtistTab {
  hot('热门'),
  albums('专辑'),
  singles('单曲EP'),
  about('简介');

  const ArtistTab(this.label);

  final String label;
}

/// 歌手: photo hero over a blurred backdrop, then 热门 / 专辑 / 单曲EP / 简介
/// switched by a chip bar.
///
/// [preview] may be an [Artist] (from a song or search row) or an
/// [ArtistDetail]; it renders instantly while the details load.
class ArtistPage extends StatefulWidget {
  const ArtistPage({super.key, required this.artistId, this.preview});

  final int artistId;
  final Object? preview;

  @override
  State<ArtistPage> createState() => _ArtistPageState();
}

class _ArtistPageState extends State<ArtistPage> {
  final ScrollController _scroll = ScrollController();
  ArtistTab _tab = ArtistTab.hot;

  ArtistDetail? _detail;
  late Future<List<Song>> _topSongs;
  late Future<List<Album>> _albums;
  late Future<ArtistDescription> _description;
  late Future<List<Artist>> _similar;

  @override
  void initState() {
    super.initState();
    _detail = switch (widget.preview) {
      final ArtistDetail detail => detail,
      _ => null,
    };
    _start();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  void _start() {
    final id = widget.artistId;
    _topSongs = guardFuture(app.library.artistTopSongs(id));
    _albums = guardFuture(
      app.library.artistAlbums(id, limit: 60).then((page) => page.items),
    );
    _description = guardFuture(app.library.artistDescription(id));
    _similar = app.library
        .similarArtists(id)
        .catchError((Object _) => const <Artist>[]);
    unawaited(_loadDetail());
  }

  Future<void> _loadDetail() async {
    try {
      final detail = await app.library.artistDetail(widget.artistId);
      if (mounted) setState(() => _detail = detail);
    } on Object catch (error) {
      if (mounted && _detail == null) showToast(context, describeError(error));
    }
  }

  void _retry() => setState(_start);

  String get _name =>
      _detail?.name ??
      switch (widget.preview) {
        final Artist artist => artist.name,
        _ => '歌手',
      };

  String? get _photo =>
      _detail?.avatarUrl ??
      _detail?.coverUrl ??
      switch (widget.preview) {
        final Artist artist => artist.picUrl,
        _ => null,
      };

  List<String> get _alias =>
      _detail?.alias ??
      switch (widget.preview) {
        final Artist artist => artist.alias,
        _ => const <String>[],
      };

  Future<void> _playTop({bool shuffle = false}) async {
    try {
      final songs = await _topSongs;
      if (!mounted) return;
      playCollection(
        context,
        songs,
        shuffle: shuffle,
        title: '$_name 热门歌曲',
        sourceId: widget.artistId,
      );
    } on Object catch (error) {
      if (mounted) showToast(context, describeError(error));
    }
  }

  Widget _tabContent() {
    switch (_tab) {
      case ArtistTab.hot:
        return ArtistHotTab(
          artistId: widget.artistId,
          artistName: _name,
          topSongs: _topSongs,
          albums: _albums,
          similar: _similar,
          onRetry: _retry,
        );
      case ArtistTab.albums:
      case ArtistTab.singles:
        return ArtistAlbumsTab(
          artistId: widget.artistId,
          albums: _albums,
          singles: _tab == ArtistTab.singles,
          onRetry: _retry,
        );
      case ArtistTab.about:
        return ArtistAboutTab(
          description: _description,
          identities: _detail?.identities ?? const [],
          onRetry: _retry,
        );
    }
  }

  @override
  Widget build(BuildContext context) {
    final detail = _detail;
    final stats = [
      if ((detail?.musicSize ?? 0) > 0) '${detail!.musicSize.compact} 首歌曲',
      if ((detail?.albumSize ?? 0) > 0) '${detail!.albumSize} 张专辑',
      if ((detail?.mvSize ?? 0) > 0) '${detail!.mvSize} 个 MV',
    ];
    return Stack(
      children: [
        Positioned.fill(
          child: RefreshIndicator(
            onRefresh: () async {
              _retry();
              await _topSongs.catchError((Object _) => const <Song>[]);
            },
            child: CustomScrollView(
              controller: _scroll,
              physics: const AlwaysScrollableScrollPhysics(),
              slivers: [
                SliverToBoxAdapter(
                  child: DetailHero(
                    title: _name,
                    coverUrl: _photo,
                    circleCover: true,
                    eyebrow: (detail?.identities.isNotEmpty ?? false)
                        ? detail!.identities.first
                        : '歌手',
                    subtitle: _alias.isEmpty
                        ? null
                        : Text(
                            _alias.join(' / '),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: context.text.bodyMedium?.copyWith(
                              color: context.surfaces.textSecondary,
                            ),
                          ),
                    stats: stats,
                    description: detail?.briefDesc,
                    actions: DetailActions(
                      primary: LimePillButton(
                        label: '播放热门',
                        icon: Icons.play_arrow_rounded,
                        onPressed: _playTop,
                      ),
                      secondary: [
                        RoundIconButton(
                          icon: Icons.shuffle_rounded,
                          tooltip: '随机播放',
                          onPressed: () => _playTop(shuffle: true),
                        ),
                      ],
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentBox(
                    padding: const EdgeInsets.only(top: 16),
                    child: ChipBar<ArtistTab>(
                      values: ArtistTab.values,
                      selected: _tab,
                      labelOf: (tab) => tab.label,
                      onSelected: (tab) => setState(() => _tab = tab),
                    ),
                  ),
                ),
                SliverToBoxAdapter(
                  child: ContentBox(
                    child: AnimatedSwitcher(
                      duration: AppMotion.standard,
                      switchInCurve: AppMotion.enter,
                      switchOutCurve: AppMotion.exit,
                      transitionBuilder: fadeThroughTransition,
                      layoutBuilder: topStackLayout,
                      child: KeyedSubtree(
                        key: ValueKey(_tab),
                        child: _tabContent(),
                      ),
                    ),
                  ),
                ),
                const SliverShellBottomInset(),
              ],
            ),
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: CollapsingHeaderBar(controller: _scroll, title: _name),
        ),
      ],
    );
  }
}
