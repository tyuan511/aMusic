import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

import '../../core/config.dart';
import '../../models/playlist.dart';
import '../../models/song.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../shell.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import '../widgets/song_tile.dart';
import 'detail_header.dart';
import 'layout.dart';
import 'track_entries.dart';

/// Scrollable detail page for a list of tracks (playlist, album).
///
/// Owns the scroll controller, the in-list filter, the lazily built track
/// list and the "定位当前播放" button, which appears only when the current
/// song is in this list but scrolled out of view. The hero is supplied by the
/// caller and rendered instantly (from a preview) while [tracks] is `null`.
class TrackCollectionView extends StatefulWidget {
  const TrackCollectionView({
    super.key,
    required this.title,
    required this.hero,
    required this.tracks,
    required this.onPlay,
    this.error,
    this.onRetry,
    this.onRefresh,
    this.byDisc = false,
    this.numbered = false,
    this.removeFrom,
    this.onRemoved,
    this.barActions = const [],
    this.emptyMessage = '这里还没有歌曲',
  });

  final String title;
  final Widget hero;

  /// `null` while loading.
  final List<Song>? tracks;

  /// Plays the unfiltered collection from [index].
  final void Function(int index) onPlay;
  final String? error;
  final VoidCallback? onRetry;
  final Future<void> Function()? onRefresh;

  /// Group by disc and number rows by album track number (albums).
  final bool byDisc;

  /// Track numbers instead of covers in front of each row.
  final bool numbered;

  /// Own playlist the rows belong to (enables removal in the song menu).
  final Playlist? removeFrom;
  final VoidCallback? onRemoved;
  final List<Widget> barActions;
  final String emptyMessage;

  @override
  State<TrackCollectionView> createState() => _TrackCollectionViewState();
}

class _TrackCollectionViewState extends State<TrackCollectionView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _filter = TextEditingController();
  final GlobalKey _listKey = GlobalKey();
  final ValueNotifier<bool> _locateVisible = ValueNotifier(false);

  String _query = '';
  List<TrackEntry> _entries = const [];
  List<double> _offsets = const [];
  List<Song>? _builtFrom;
  String? _builtQuery;
  int _currentEntry = -1;
  DateTime? _rowsAppearedAt;

  @override
  void initState() {
    super.initState();
    _scroll.addListener(_updateLocate);
    app.player.currentSongId.addListener(_onCurrentChanged);
  }

  @override
  void dispose() {
    _scroll
      ..removeListener(_updateLocate)
      ..dispose();
    app.player.currentSongId.removeListener(_onCurrentChanged);
    _filter.dispose();
    _locateVisible.dispose();
    super.dispose();
  }

  void _ensureEntries() {
    final tracks = widget.tracks;
    if (tracks == null) {
      _entries = const [];
      _offsets = const [];
      _builtFrom = null;
      return;
    }
    if (identical(tracks, _builtFrom) && _builtQuery == _query) return;
    _rowsAppearedAt ??= DateTime.now();
    _builtFrom = tracks;
    _builtQuery = _query;
    _entries = buildTrackEntries(tracks, query: _query, byDisc: widget.byDisc);
    final offsets = List<double>.filled(_entries.length, 0);
    var running = 0.0;
    for (var i = 0; i < _entries.length; i++) {
      offsets[i] = running;
      running += _entries[i].extent;
    }
    _offsets = offsets;
    _currentEntry = entryIndexOfSong(_entries, app.player.currentSongId.value);
    WidgetsBinding.instance.addPostFrameCallback((_) => _updateLocate());
  }

  void _onCurrentChanged() {
    _currentEntry = entryIndexOfSong(_entries, app.player.currentSongId.value);
    _updateLocate();
  }

  /// Scroll offset of the first track row, once laid out.
  double? _listTop() {
    final object = _listKey.currentContext?.findRenderObject();
    if (object is! RenderSliver || !object.attached) return null;
    if (object.geometry == null) return null;
    return object.constraints.precedingScrollExtent;
  }

  /// Floating chrome above / below the list, captured during build so the
  /// scroll listener never performs inherited lookups.
  double _topInset = kHeaderBarHeight + kHeaderBarTopGap;
  double _bottomInset = 24;

  void _updateLocate() {
    if (!mounted) return;
    var visible = false;
    final index = _currentEntry;
    if (index >= 0 && index < _offsets.length && _scroll.hasClients) {
      final top = _listTop();
      if (top != null) {
        final position = _scroll.position;
        visible = isRowOffscreen(
          rowTop: top + _offsets[index],
          extent: _entries[index].extent,
          scrollOffset: position.pixels,
          viewport: position.viewportDimension,
          topInset: _topInset,
          bottomInset: _bottomInset,
        );
      }
    }
    if (_locateVisible.value != visible) _locateVisible.value = visible;
  }

  Future<void> _locate() async {
    final index = _currentEntry;
    final top = _listTop();
    if (index < 0 || top == null || !_scroll.hasClients) return;
    final position = _scroll.position;
    final target = centeredScrollTarget(
      rowTop: top + _offsets[index],
      extent: _entries[index].extent,
      viewport: position.viewportDimension,
      maxScrollExtent: position.maxScrollExtent,
      topInset: _topInset,
      bottomInset: _bottomInset,
    );
    await _scroll.animateTo(
      target,
      duration: AppMotion.emphasized,
      curve: AppMotion.enter,
    );
  }

  void _onQuery(String value) {
    if (value == _query) return;
    setState(() => _query = value);
  }

  bool get _animateRows {
    final at = _rowsAppearedAt;
    return at != null &&
        DateTime.now().difference(at) < const Duration(milliseconds: 700);
  }

  @override
  Widget build(BuildContext context) {
    _topInset = headerBarTopInset(context) + kHeaderBarHeight;
    _bottomInset = ShellLayout.bottomInsetOf(context);
    _ensureEntries();
    final tracks = widget.tracks;
    final showAlbum =
        !widget.byDisc &&
        MediaQuery.sizeOf(context).width >= Breakpoints.medium;

    final slivers = <Widget>[
      SliverToBoxAdapter(child: widget.hero),
      if (tracks != null && tracks.isNotEmpty)
        SliverToBoxAdapter(
          child: ContentBox(
            child: _Toolbar(
              count: tracks.length,
              shown: _entries.whereType<SongEntry>().length,
              filtering: _query.trim().isNotEmpty,
              controller: _filter,
              onChanged: _onQuery,
            ),
          ),
        ),
      if (tracks == null && widget.error == null)
        const SliverToBoxAdapter(
          child: ContentBox(
            padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
            child: MediaRowSkeletonList(count: 8),
          ),
        )
      else if (tracks == null)
        SliverToBoxAdapter(
          child: ErrorView(message: widget.error!, onRetry: widget.onRetry),
        )
      else if (tracks.isEmpty)
        SliverToBoxAdapter(
          child: EmptyView(
            message: widget.emptyMessage,
            icon: Icons.music_off_rounded,
          ),
        )
      else if (_entries.isEmpty)
        const SliverToBoxAdapter(
          child: EmptyView(message: '没有匹配的歌曲', icon: Icons.search_off_rounded),
        )
      else
        SliverContent(
          horizontal: AppMetrics.gutter - 10,
          sliver: SliverVariedExtentList.builder(
            key: _listKey,
            itemCount: _entries.length,
            itemExtentBuilder: (index, _) =>
                index < _entries.length ? _entries[index].extent : null,
            itemBuilder: (context, index) {
              final row = _buildRow(context, _entries[index], showAlbum);
              if (_animateRows && index < 14) {
                return EntranceFade(index: index, child: row);
              }
              return row;
            },
          ),
        ),
      const SliverShellBottomInset(),
    ];

    Widget scrollView = CustomScrollView(
      controller: _scroll,
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: slivers,
    );
    if (widget.onRefresh != null) {
      scrollView = RefreshIndicator(
        onRefresh: widget.onRefresh!,
        edgeOffset: _topInset,
        child: scrollView,
      );
    }

    return Stack(
      children: [
        Positioned.fill(child: scrollView),
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          child: CollapsingHeaderBar(
            controller: _scroll,
            title: widget.title,
            actions: widget.barActions,
            threshold: ShellLayout.compactOf(context) ? 300 : 260,
          ),
        ),
        Positioned(
          right: AppMetrics.gutter,
          bottom: _bottomInset + 12,
          child: _LocateButton(visible: _locateVisible, onPressed: _locate),
        ),
      ],
    );
  }

  Widget _buildRow(BuildContext context, TrackEntry entry, bool showAlbum) {
    switch (entry) {
      case DiscHeaderEntry(:final disc):
        return _DiscHeader(disc: disc);
      case SongEntry(:final song, :final sourceIndex, :final label):
        return SongTile(
          key: ValueKey('track-${song.id}-$sourceIndex'),
          song: song,
          index: widget.numbered ? sourceIndex : null,
          numberLabel: widget.numbered ? label : null,
          showAlbum: showAlbum,
          height: kTrackRowExtent,
          removeFrom: widget.removeFrom,
          onRemoved: widget.onRemoved,
          onTap: () => widget.onPlay(sourceIndex),
        );
    }
  }
}

class _Toolbar extends StatelessWidget {
  const _Toolbar({
    required this.count,
    required this.shown,
    required this.filtering,
    required this.controller,
    required this.onChanged,
  });

  final int count;
  final int shown;
  final bool filtering;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final compact = ShellLayout.compactOf(context);
    final field = SizedBox(
      height: 42,
      width: compact ? null : 260,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        textInputAction: TextInputAction.search,
        style: context.text.bodyMedium,
        decoration: InputDecoration(
          isDense: true,
          hintText: '在列表中搜索',
          contentPadding: const EdgeInsets.symmetric(vertical: 10),
          prefixIcon: const Icon(Icons.search_rounded, size: 19),
          suffixIcon: ValueListenableBuilder(
            valueListenable: controller,
            builder: (context, value, _) => value.text.isEmpty
                ? const SizedBox.shrink()
                : IconButton(
                    tooltip: '清除',
                    icon: const Icon(Icons.close_rounded, size: 17),
                    onPressed: () {
                      controller.clear();
                      onChanged('');
                    },
                  ),
          ),
        ),
      ),
    );
    return Padding(
      padding: const EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        14,
        AppMetrics.gutter,
        8,
      ),
      child: Row(
        children: [
          AnimatedSwitcher(
            duration: AppMotion.quick,
            child: Text(
              filtering ? '$shown / $count 首' : '共 $count 首',
              key: ValueKey('$filtering-$shown'),
              style: context.text.bodySmall?.copyWith(color: s.textTertiary),
            ),
          ),
          const SizedBox(width: 16),
          if (compact) Expanded(child: field) else ...[const Spacer(), field],
        ],
      ),
    );
  }
}

class _DiscHeader extends StatelessWidget {
  const _DiscHeader({required this.disc});

  final int disc;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 14, 12, 4),
      child: Row(
        children: [
          Icon(Icons.album_rounded, size: 18, color: context.surfaces.lime),
          const SizedBox(width: 8),
          Text(
            'CD $disc',
            style: context.text.titleSmall?.copyWith(
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _LocateButton extends StatelessWidget {
  const _LocateButton({required this.visible, required this.onPressed});

  final ValueListenable<bool> visible;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: visible,
      builder: (context, shown, child) => IgnorePointer(
        ignoring: !shown,
        child: AnimatedScale(
          scale: shown ? 1 : 0.6,
          duration: AppMotion.standard,
          curve: shown ? AppMotion.pop : AppMotion.exit,
          child: AnimatedOpacity(
            opacity: shown ? 1 : 0,
            duration: AppMotion.quick,
            child: child,
          ),
        ),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: context.surfaces.glow,
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: RoundIconButton(
          icon: Icons.my_location_rounded,
          tooltip: '定位当前播放',
          size: 50,
          active: true,
          onPressed: onPressed,
        ),
      ),
    );
  }
}
