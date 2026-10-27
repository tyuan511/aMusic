import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/song.dart';
import '../../services/app.dart';
import 'sheets.dart';

/// Plays [songs] as a queue titled [title].
///
/// [index] `null` starts at the first playable track. With [shuffle] the
/// player's shuffle mode is switched on and a random playable track starts.
void playCollection(
  BuildContext context,
  List<Song> songs, {
  int? index,
  bool shuffle = false,
  String? title,
  int? sourceId,
}) {
  if (songs.isEmpty) return;
  final playable = [
    for (var i = 0; i < songs.length; i++)
      if (songs[i].playable) i,
  ];
  if (playable.isEmpty) {
    showToast(context, '这些歌曲暂时无法播放');
    return;
  }
  final player = app.player;
  var start = index ?? playable.first;
  if (shuffle) {
    if (!player.queue.value.shuffle) unawaited(player.toggleShuffle());
    start = playable[math.Random().nextInt(playable.length)];
  }
  if (!songs[start].playable) {
    showToast(context, '《${songs[start].name}》暂无版权');
    return;
  }
  unawaited(
    player.playSongs(
      songs,
      index: start,
      sourceTitle: title,
      sourceId: sourceId,
    ),
  );
}
