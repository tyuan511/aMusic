import 'package:flutter/material.dart';

import '../../models/search.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/layout.dart';
import '../widgets/kit.dart';

/// Idle state of the search page: history chips and the hot list.
class SearchDiscovery extends StatelessWidget {
  const SearchDiscovery({
    super.key,
    required this.history,
    required this.hotWords,
    required this.onSearch,
    required this.onRemoveHistory,
    required this.onClearHistory,
  });

  final List<String> history;

  /// `null` while loading.
  final List<String>? hotWords;
  final ValueChanged<String> onSearch;
  final ValueChanged<String> onRemoveHistory;
  final VoidCallback onClearHistory;

  @override
  Widget build(BuildContext context) {
    final hot = hotWords;
    return ListView(
      padding: EdgeInsets.only(
        bottom: shellBottomInset(context) + AppMetrics.gutter,
      ),
      children: [
        AnimatedSize(
          duration: AppMotion.standard,
          curve: AppMotion.enter,
          alignment: Alignment.topCenter,
          child: history.isEmpty
              ? const SizedBox(width: double.infinity)
              : Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SectionTitle(
                      title: '搜索历史',
                      actionLabel: '清空',
                      onAction: onClearHistory,
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppMetrics.gutter,
                      ),
                      child: Wrap(
                        spacing: 10,
                        runSpacing: 10,
                        children: [
                          for (var i = 0; i < history.length; i++)
                            EntranceItem(
                              key: ValueKey('history-${history[i]}'),
                              index: i,
                              child: HistoryChip(
                                label: history[i],
                                onTap: () => onSearch(history[i]),
                                onRemove: () => onRemoveHistory(history[i]),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
        const SectionTitle(title: '热搜榜'),
        if (hot == null)
          const MediaRowSkeletonList(
            count: 6,
            padding: EdgeInsets.symmetric(horizontal: AppMetrics.gutter - 10),
          )
        else
          Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: AppMetrics.gutter - 6,
            ),
            child: ResponsiveColumns(
              minColumnWidth: 340,
              maxColumns: 2,
              spacing: 16,
              children: [
                for (var i = 0; i < hot.length; i++)
                  EntranceItem(
                    index: i,
                    child: HotWordRow(
                      rank: i + 1,
                      word: hot[i],
                      onTap: () => onSearch(hot[i]),
                    ),
                  ),
              ],
            ),
          ),
      ],
    );
  }
}

/// History pill: tap searches, the small × removes it.
class HistoryChip extends StatelessWidget {
  const HistoryChip({
    super.key,
    required this.label,
    required this.onTap,
    required this.onRemove,
  });

  final String label;
  final VoidCallback onTap;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Pressable(
      onTap: onTap,
      onLongPress: onRemove,
      semanticLabel: label,
      child: Container(
        padding: const EdgeInsets.only(left: 16, right: 6),
        height: 38,
        decoration: BoxDecoration(
          color: s.chip,
          borderRadius: BorderRadius.circular(AppMetrics.radiusPill),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 200),
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: context.text.bodyMedium?.copyWith(
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
            const SizedBox(width: 2),
            Tooltip(
              message: '删除',
              child: Pressable(
                onTap: onRemove,
                hoverScale: 1.15,
                child: Padding(
                  padding: const EdgeInsets.all(6),
                  child: Icon(
                    Icons.close_rounded,
                    size: 14,
                    color: s.textTertiary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// "1  晴天" row of the hot list; the top three ranks are lime.
class HotWordRow extends StatelessWidget {
  const HotWordRow({
    super.key,
    required this.rank,
    required this.word,
    required this.onTap,
  });

  final int rank;
  final String word;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    final top = rank <= 3;
    return MediaRow(
      title: word,
      onTap: onTap,
      leading: SizedBox(
        width: 34,
        height: 40,
        child: Center(
          child: Text(
            '$rank',
            key: ValueKey('hot-rank-$rank'),
            style: context.text.titleMedium?.copyWith(
              fontSize: top ? 20 : 16,
              fontWeight: top ? FontWeight.w700 : FontWeight.w500,
              color: top ? s.lime : s.textTertiary,
              fontFeatures: const [FontFeature.tabularFigures()],
            ),
          ),
        ),
      ),
      trailing: top
          ? Icon(Icons.local_fire_department_rounded, size: 18, color: s.lime)
          : null,
    );
  }
}

/// Live suggestions while typing: keywords plus quick song / artist /
/// album / playlist matches.
class SuggestionsPanel extends StatelessWidget {
  const SuggestionsPanel({
    super.key,
    required this.query,
    required this.suggestions,
    required this.onSearch,
  });

  final String query;
  final SearchSuggestions suggestions;
  final ValueChanged<String> onSearch;

  @override
  Widget build(BuildContext context) {
    final rows = <Widget>[
      MediaRow(
        key: const ValueKey('suggest-query'),
        title: '搜索 “$query”',
        leading: const _SuggestIcon(icon: Icons.search_rounded, accent: true),
        onTap: () => onSearch(query),
      ),
      for (final keyword in suggestions.keywords)
        if (keyword != query)
          MediaRow(
            title: keyword,
            leading: const _SuggestIcon(icon: Icons.search_rounded),
            onTap: () => onSearch(keyword),
          ),
      for (final song in suggestions.songs.take(4))
        MediaRow(
          title: song.name,
          subtitle: '单曲',
          meta: song.artistText,
          coverUrl: song.album.picUrl,
          coverSize: 44,
          onTap: () => app.player.playSongs([song], sourceTitle: song.name),
        ),
      for (final artist in suggestions.artists.take(3))
        MediaRow(
          title: artist.name,
          subtitle: '歌手',
          coverUrl: artist.picUrl,
          coverSize: 44,
          circleCover: true,
          onTap: () => openArtist(context, artist.id, preview: artist),
        ),
      for (final album in suggestions.albums.take(3))
        MediaRow(
          title: album.name,
          subtitle: '专辑',
          meta: album.artistText,
          coverUrl: album.picUrl,
          coverSize: 44,
          onTap: () => openAlbum(context, album.id, preview: album),
        ),
      for (final playlist in suggestions.playlists.take(3))
        MediaRow(
          title: playlist.name,
          subtitle: '歌单',
          coverUrl: playlist.coverUrl,
          coverSize: 44,
          onTap: () => openPlaylist(context, playlist),
        ),
    ];
    return ListView.builder(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.gutter - 10,
        4,
        AppMetrics.gutter - 10,
        shellBottomInset(context),
      ),
      itemCount: rows.length,
      itemBuilder: (context, index) =>
          EntranceItem(index: index, child: rows[index]),
    );
  }
}

class _SuggestIcon extends StatelessWidget {
  const _SuggestIcon({required this.icon, this.accent = false});

  final IconData icon;
  final bool accent;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: accent ? s.lime : s.chip,
        shape: BoxShape.circle,
      ),
      child: Icon(icon, size: 20, color: accent ? s.onLime : s.textSecondary),
    );
  }
}
