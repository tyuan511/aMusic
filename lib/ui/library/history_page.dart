import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../models/user.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/layout.dart';
import '../widgets/async_view.dart';
import '../widgets/kit.dart';
import 'library_views.dart';

/// Sources of the history page.
enum HistorySource {
  local('本机'),
  week('本周'),
  all('全部');

  const HistorySource(this.label);

  final String label;
}

/// 播放历史: tracks played on this device, plus the account's cloud play
/// record (this week / all time) when signed in.
class HistoryPage extends StatefulWidget {
  const HistoryPage({super.key});

  @override
  State<HistoryPage> createState() => _HistoryPageState();
}

class _HistoryPageState extends State<HistoryPage> {
  HistorySource _source = HistorySource.local;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final loggedIn = app.session.value.isLoggedIn;
    final sources = loggedIn
        ? HistorySource.values
        : const [HistorySource.local];
    return Column(
      children: [
        SizedBox(height: top),
        ContentBox(
          child: PageHeader(
            title: '播放历史',
            actions: [
              if (_source == HistorySource.local)
                ValueListenableBuilder<List<Song>>(
                  valueListenable: app.recent.tracks,
                  builder: (context, tracks, _) => RoundIconButton(
                    icon: Icons.delete_sweep_outlined,
                    tooltip: '清空本机记录',
                    onPressed: tracks.isEmpty ? null : app.recent.clear,
                  ),
                ),
            ],
          ),
        ),
        if (sources.length > 1)
          ContentBox(
            padding: const EdgeInsets.only(top: 4, bottom: 10),
            child: ChipBar<HistorySource>(
              values: sources,
              selected: _source,
              labelOf: (source) => source.label,
              onSelected: (source) => setState(() => _source = source),
            ),
          ),
        Expanded(
          child: AnimatedSwitcher(
            duration: AppMotion.standard,
            switchInCurve: AppMotion.enter,
            switchOutCurve: AppMotion.exit,
            transitionBuilder: fadeThroughTransition,
            layoutBuilder: topStackLayout,
            child: KeyedSubtree(key: ValueKey(_source), child: _body()),
          ),
        ),
      ],
    );
  }

  Widget _body() {
    if (_source == HistorySource.local) {
      return ValueListenableBuilder<List<Song>>(
        valueListenable: app.recent.tracks,
        builder: (context, tracks, _) => tracks.isEmpty
            ? const EmptyView(
                message: '这台设备上还没有播放记录',
                icon: Icons.history_rounded,
              )
            : SongListView(songs: tracks, title: '最近播放'),
      );
    }
    final week = _source == HistorySource.week;
    return AsyncView<List<PlayRecordEntry>>(
      load: () => app.library.playRecord(week: week),
      skeleton: true,
      emptyWhen: (records) => records.isEmpty,
      emptyView: EmptyView(
        message: week ? '本周还没有听歌记录' : '还没有听歌记录',
        icon: Icons.history_rounded,
      ),
      builder: (context, records) => SongListView(
        songs: [for (final record in records) record.song],
        title: week ? '本周听歌排行' : '听歌排行',
      ),
    );
  }
}
