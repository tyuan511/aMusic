import 'package:flutter/material.dart';

import '../../models/lyric.dart';
import '../../services/app.dart';

/// Lyric of the current track, or `null` while it loads.
typedef LyricWidgetBuilder = Widget Function(
  BuildContext context,
  int? songId,
  Lyric? lyric,
);

/// Loads the current song's lyric and rebuilds on track change and on
/// imports. A cached lyric is shown synchronously, so switching panels never
/// flashes a spinner.
class CurrentLyricBuilder extends StatefulWidget {
  const CurrentLyricBuilder({super.key, required this.builder});

  final LyricWidgetBuilder builder;

  @override
  State<CurrentLyricBuilder> createState() => _CurrentLyricBuilderState();
}

class _CurrentLyricBuilderState extends State<CurrentLyricBuilder> {
  int? _songId;
  Lyric? _lyric;
  int _generation = 0;
  bool _initialised = false;

  @override
  void initState() {
    super.initState();
    app.player.currentSongId.addListener(_reload);
    app.lyrics.revision.addListener(_reloadForced);
    _reload();
    _initialised = true;
  }

  @override
  void dispose() {
    app.player.currentSongId.removeListener(_reload);
    app.lyrics.revision.removeListener(_reloadForced);
    super.dispose();
  }

  void _reloadForced() => _load(app.player.currentSongId.value, force: true);

  void _reload() => _load(app.player.currentSongId.value);

  void _load(int? songId, {bool force = false}) {
    if (!force && songId == _songId && _lyric != null) return;
    final generation = ++_generation;
    _songId = songId;
    if (songId == null) {
      _setLyric(Lyric.empty);
      return;
    }
    final cached = app.lyrics.peek(songId);
    if (cached != null) {
      _setLyric(cached);
      return;
    }
    _setLyric(null);
    app.lyrics
        .load(songId)
        .then(
          (lyric) {
            if (mounted && generation == _generation) _setLyric(lyric);
          },
          onError: (Object _) {
            if (mounted && generation == _generation) _setLyric(Lyric.empty);
          },
        );
  }

  void _setLyric(Lyric? lyric) {
    if (!_initialised || !mounted) {
      _lyric = lyric;
      return;
    }
    setState(() => _lyric = lyric);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _songId, _lyric);
}
