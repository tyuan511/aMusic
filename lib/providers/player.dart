import 'package:flutter/material.dart';
import 'package:laji_music/models/lyric.dart';
import 'package:laji_music/models/song.dart';
import 'package:ncm_api/ncm_api.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'player.g.dart';

@immutable
class PlayerState {
  final bool isPlaying;
  final Duration position;
  final int? currentSongIdx;
  final List<Song>? songList;
  final List<LyricRow>? lyric;
  final int? currentLyricIdx;

  const PlayerState({
    required this.isPlaying,
    required this.position,
    required this.currentSongIdx,
    required this.songList,
    this.lyric,
    this.currentLyricIdx,
  });

  Song? get currSong => currentSongIdx == null || songList == null ? null : songList![currentSongIdx!];

  PlayerState copyWith({
    bool? isPlaying,
    Duration? position,
    int? currentSongIdx,
    List<Song>? songList,
    List<LyricRow>? lyric,
    int? currentLyricIdx,
  }) {
    return PlayerState(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      currentSongIdx: currentSongIdx ?? this.currentSongIdx,
      songList: songList ?? this.songList,
      lyric: lyric ?? this.lyric,
      currentLyricIdx: currentLyricIdx ?? this.currentLyricIdx,
    );
  }
}

@Riverpod(keepAlive: true)
class Player extends _$Player {
  final _audioPlayer = AudioPlayer();
  ConcatenatingAudioSource? _currPlaylist;

  Player() {
    _audioPlayer.playerStateStream.listen((e) {
      state = state.copyWith(isPlaying: e.playing);
    });

    _audioPlayer.positionStream.listen((e) {
      state = state.copyWith(position: e);
      _calcCurrLyric();
    });

    _audioPlayer.currentIndexStream.listen((e) {
      state = state.copyWith(currentSongIdx: e);
      if (state.currSong != null) {
        _getLyric(state.currSong!);
      }
    });
  }

  @override
  PlayerState build() => const PlayerState(
        isPlaying: false,
        position: Duration.zero,
        currentSongIdx: null,
        songList: [],
      );

  Future<void> _setPlaylist(List<Song> songs) async {
    final res = await getSongURL(songs.map((e) => e.id).toList());
    for (var element in songs) {
      element.url = res.data!.firstWhere((e) => e.id == element.id).url;
    }
    state = state.copyWith(songList: songs.where((value) => value.url != null).toList());
  }

  _getLyric(Song song) async {
    state = state.copyWith(
      lyric: null,
      currentLyricIdx: null,
    );
    final res = await getLyric(song.id);
    state = state.copyWith(
      lyric: LyricRow.fromString(res.lrc.lyric),
      currentLyricIdx: 0,
    );
  }

  _calcCurrLyric() {
    if (state.lyric == null) return;
    var index = state.lyric!.indexWhere((element) => element.time > state.position);
    if (index < 0) index = state.lyric!.length;
    state = state.copyWith(currentLyricIdx: index - 1);
  }

  playSongs(List<Song> songs, {int index = 0}) async {
    await _setPlaylist(songs);
    _currPlaylist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: (state.songList ?? []).map((e) => e.toAudioSource()).toList());
    state = state.copyWith(currentSongIdx: index);
    await _audioPlayer.setAudioSource(_currPlaylist!, initialIndex: index, initialPosition: Duration.zero);
    await _audioPlayer.play();
  }

  playSong(Song song) async {
    int idx = state.songList!.indexWhere((element) => element.id == song.id);
    if (idx < 0) {
      final res = await getSongURL([song.id]);
      song.url = res.data!.first.url;
      state = state.copyWith(songList: [...state.songList!, song]);
      idx = state.songList!.length - 1;
      _currPlaylist ??=
          ConcatenatingAudioSource(useLazyPreparation: true, shuffleOrder: DefaultShuffleOrder(), children: []);
      _currPlaylist!.insert(idx, song.toAudioSource());
      await _audioPlayer.setAudioSource(_currPlaylist!, initialIndex: idx, initialPosition: Duration.zero);
    }

    await _audioPlayer.seek(Duration.zero, index: idx);
    await _audioPlayer.play();
  }

  playOrPause() {
    if (!state.isPlaying) {
      _audioPlayer.play();
    } else {
      _audioPlayer.pause();
    }
  }

  prev() {
    _audioPlayer.seekToPrevious();
  }

  next() {
    _audioPlayer.seekToNext();
  }
}
