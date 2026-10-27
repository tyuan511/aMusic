import 'package:flutter/material.dart';

import '../../core/format.dart';
import '../../models/discovery.dart';
import '../../router.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/cards.dart';
import '../browse_widgets/layout.dart';
import '../shell.dart';
import '../widgets/async_view.dart';
import '../widgets/cover_image.dart';
import '../widgets/kit.dart';
import '../widgets/motion.dart';
import 'chart_groups.dart';

/// 排行榜: NetEase official charts as big cards with a top-3 preview, then
/// global and featured charts as cover grids. Every chart opens as a
/// playlist.
class ChartsPage extends StatefulWidget {
  const ChartsPage({super.key});

  @override
  State<ChartsPage> createState() => _ChartsPageState();
}

class _ChartsPageState extends State<ChartsPage> {
  int _reload = 0;

  @override
  Widget build(BuildContext context) {
    return AsyncView<ChartGroups>(
      key: ValueKey('charts-$_reload'),
      load: () async => groupCharts(await app.library.toplists()),
      placeholder: const _ChartsSkeleton(),
      emptyWhen: (groups) => groups.isEmpty,
      emptyView: const EmptyView(message: '暂时没有排行榜'),
      onRefresh: () async => setState(() => _reload++),
      builder: (context, groups) => _ChartsBody(groups: groups),
    );
  }
}

class _ChartsBody extends StatelessWidget {
  const _ChartsBody({required this.groups});

  final ChartGroups groups;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      slivers: [
        const SliverToBoxAdapter(child: _ChartsHeader()),
        if (groups.official.isNotEmpty) ...[
          const SliverToBoxAdapter(
            child: ContentBox(
              child: SectionTitle(title: '官方榜', subtitle: '网易云音乐官方出品'),
            ),
          ),
          SliverToBoxAdapter(
            child: ContentBox(
              padding: const EdgeInsets.symmetric(
                horizontal: AppMetrics.gutter,
              ),
              child: ResponsiveColumns(
                minColumnWidth: 420,
                maxColumns: 2,
                spacing: 16,
                runSpacing: 16,
                children: [
                  for (var i = 0; i < groups.official.length; i++)
                    EntranceFade(
                      index: i,
                      child: OfficialChartCard(
                        toplist: groups.official[i],
                        tint: _tints(context)[i % 4],
                      ),
                    ),
                ],
              ),
            ),
          ),
        ],
        ..._grid(context, '全球榜', '各地区权威榜单', groups.global),
        ..._grid(context, '特色榜', '曲风、场景与主题', groups.featured),
        const SliverShellBottomInset(),
      ],
    );
  }

  List<Color> _tints(BuildContext context) {
    final s = context.surfaces;
    return [s.lavender, s.lime, s.peach, const Color(0xFF7FD1E8)];
  }

  List<Widget> _grid(
    BuildContext context,
    String title,
    String subtitle,
    List<Toplist> lists,
  ) {
    if (lists.isEmpty) return const [];
    return [
      SliverToBoxAdapter(
        child: ContentBox(
          child: SectionTitle(title: title, subtitle: subtitle),
        ),
      ),
      SliverContent(
        horizontal: AppMetrics.gutter,
        sliver: SliverCoverGrid(
          itemCount: lists.length,
          maxItemWidth: ShellLayout.compactOf(context) ? 170 : 190,
          itemBuilder: (context, index) =>
              ChartCoverCard(toplist: lists[index]),
        ),
      ),
    ];
  }
}

class _ChartsHeader extends StatelessWidget {
  const _ChartsHeader();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return ContentBox(
      padding: EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        top + 24,
        AppMetrics.gutter,
        0,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '排行榜',
            style: context.text.headlineMedium?.copyWith(
              fontSize: 34,
              fontWeight: FontWeight.w500,
              letterSpacing: -0.8,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '每天都在变化的热门音乐',
            style: context.text.bodyMedium?.copyWith(
              color: context.surfaces.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

/// Big card of an official chart: cover, name, update frequency, the top 3
/// tracks and a play button.
class OfficialChartCard extends StatelessWidget {
  const OfficialChartCard({
    super.key,
    required this.toplist,
    required this.tint,
  });

  final Toplist toplist;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return HoverLift(
      onTap: () => openPlaylist(context, toplist.toPlaylist()),
      radius: AppMetrics.radiusLg,
      glow: tint.withValues(alpha: 0.25),
      builder: (context, hovering) => AnimatedContainer(
        duration: AppMotion.standard,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(AppMetrics.radiusLg),
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              tint.withValues(alpha: hovering ? 0.26 : 0.18),
              s.card,
            ],
          ),
          border: Border.all(color: s.hairline),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                CoverImage(
                  url: toplist.coverUrl,
                  size: 300,
                  width: 112,
                  height: 112,
                  radius: AppMetrics.radiusMd,
                ),
                Positioned(
                  right: 8,
                  bottom: 8,
                  child: CollectionPlayButton(
                    sourceId: toplist.id,
                    sourceTitle: toplist.name,
                    size: 38,
                    accent: true,
                    load: () async =>
                        (await app.library.playlistDetail(toplist.id)).tracks,
                  ),
                ),
              ],
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    toplist.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: context.text.titleMedium?.copyWith(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(height: 4),
                  DotSeparated(
                    parts: [
                      ?toplist.updateFrequency,
                      if (toplist.updateTime != null)
                        '${toplist.updateTime!.month}月${toplist.updateTime!.day}日更新',
                    ],
                  ),
                  const SizedBox(height: 10),
                  for (var i = 0; i < toplist.preview.length && i < 3; i++)
                    _PreviewLine(
                      rank: i + 1,
                      preview: toplist.preview[i],
                      tint: tint,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PreviewLine extends StatelessWidget {
  const _PreviewLine({
    required this.rank,
    required this.preview,
    required this.tint,
  });

  final int rank;
  final ToplistPreview preview;
  final Color tint;

  @override
  Widget build(BuildContext context) {
    final s = context.surfaces;
    return Padding(
      padding: const EdgeInsets.only(bottom: 5),
      child: Row(
        children: [
          SizedBox(
            width: 20,
            child: Text(
              '$rank',
              style: context.text.bodyMedium?.copyWith(
                color: tint,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text.rich(
              TextSpan(
                text: preview.name,
                children: [
                  if (preview.artist.isNotEmpty)
                    TextSpan(
                      text: '  ${preview.artist}',
                      style: TextStyle(color: s.textTertiary),
                    ),
                ],
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.text.bodySmall?.copyWith(fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

/// Grid card of a non-official chart.
class ChartCoverCard extends StatelessWidget {
  const ChartCoverCard({super.key, required this.toplist});

  final Toplist toplist;

  @override
  Widget build(BuildContext context) {
    return CoverCard(
      title: toplist.name,
      subtitle: toplist.updateFrequency,
      coverUrl: toplist.coverUrl,
      onTap: () => openPlaylist(context, toplist.toPlaylist()),
      topRight: toplist.playCount > 0
          ? PlayCountPill(toplist.playCount.compact)
          : null,
      playButton: CollectionPlayButton(
        sourceId: toplist.id,
        sourceTitle: toplist.name,
        accent: true,
        size: 40,
        load: () async => (await app.library.playlistDetail(toplist.id)).tracks,
      ),
    );
  }
}

class _ChartsSkeleton extends StatelessWidget {
  const _ChartsSkeleton();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      padding: EdgeInsets.fromLTRB(
        AppMetrics.gutter,
        top + 24,
        AppMetrics.gutter,
        0,
      ),
      child: ContentBox(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Skeleton(width: 140, height: 34),
            const SizedBox(height: 40),
            ResponsiveColumns(
              minColumnWidth: 420,
              maxColumns: 2,
              spacing: 16,
              runSpacing: 16,
              children: [
                for (var i = 0; i < 4; i++)
                  const Skeleton(height: 144, radius: AppMetrics.radiusLg),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
