import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../models/user.dart';
import '../../services/app.dart';
import '../../theme/app_theme.dart';
import '../browse_widgets/buttons.dart';
import '../browse_widgets/layout.dart';
import '../browse_widgets/playback.dart';
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
  final _remote = ValueNotifier<List<Song>>(const []);

  ValueListenable<List<Song>> get _songs =>
      _source == HistorySource.local ? app.recent.tracks : _remote;

  String get _title => switch (_source) {
    HistorySource.local => '最近播放',
    HistorySource.week => '本周听歌排行',
    HistorySource.all => '听歌排行',
  };

  void _select(HistorySource source) {
    _remote.value = const [];
    setState(() => _source = source);
  }

  @override
  void dispose() {
    _remote.dispose();
    super.dispose();
  }

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
        ContentBox(
          padding: const EdgeInsets.only(top: 4, bottom: 10),
          child: Row(
            children: [
              Expanded(
                child: sources.length > 1
                    ? ChipBar<HistorySource>(
                        values: sources,
                        selected: _source,
                        labelOf: (source) => source.label,
                        onSelected: _select,
                      )
                    : const SizedBox(height: 46),
              ),
              ValueListenableBuilder<List<Song>>(
                valueListenable: _songs,
                builder: (context, songs, _) => songs.isEmpty
                    ? const SizedBox.shrink()
                    : Padding(
                        padding: const EdgeInsets.only(
                          right: AppMetrics.gutter,
                          left: 12,
                        ),
                        child: LimePillButton(
                          label: '播放全部',
                          icon: Icons.play_arrow_rounded,
                          onPressed: () =>
                              playCollection(context, songs, title: _title),
                        ),
                      ),
              ),
            ],
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
            : SongListView(songs: tracks, title: '最近播放', showHeader: false),
      );
    }
    final week = _source == HistorySource.week;
    return AsyncView<List<PlayRecordEntry>>(
      load: () async {
        final records = await app.library.playRecord(week: week);
        _remote.value = [for (final record in records) record.song];
        return records;
      },
      skeleton: true,
      emptyWhen: (records) => records.isEmpty,
      emptyView: EmptyView(
        message: week ? '本周还没有听歌记录' : '还没有听歌记录',
        icon: Icons.history_rounded,
      ),
      builder: (context, records) => SongListView(
        songs: [for (final record in records) record.song],
        title: week ? '本周听歌排行' : '听歌排行',
        showHeader: false,
      ),
    );
  }
}
