import 'dart:convert';

import 'package:laji_music/consts/key.dart';
import 'package:laji_music/models/lyric.dart';
import 'package:laji_music/models/player.dart';
import 'package:laji_music/models/song.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:laji_music/utils/storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'player.g.dart';

@Riverpod(keepAlive: true)
class Player extends _$Player {
  final _audioPlayer = AudioPlayer(
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
  );
  ConcatenatingAudioSource? _currPlaylist;

  @override
  PlayerModel build() {
    final json = storage.read(playerStorageKey);
    if (json != null) {
      return PlayerModel.fromJson(jsonDecode(json));
    }

    return const PlayerModel(
      isPlaying: false,
      position: Duration.zero,
      currentSongIdx: null,
      songList: [],
    );
  }

  _saveState() {
    storage.write(playerStorageKey, jsonEncode(state.toJson()));
  }

  Player() {
    _audioPlayer.playerStateStream.listen((e) {
      var isLoading = false;
      if (e.processingState == ProcessingState.loading) {
        isLoading = true;
      }

      state = state.copyWith(isPlaying: e.playing, songLoading: isLoading);
      _saveState();
    });

    _audioPlayer.positionStream.listen((e) {
      state = state.copyWith(position: e);
      _calcCurrLyric();
      _saveState();
    });

    _audioPlayer.currentIndexStream.listen((e) {
      state = state.copyWith(currentSongIdx: e);

      _getLyric(state.currSong!);

      _saveState();
    });
  }

  Future<void> _setPlaylist(List<Song> songs) async {
    state.copyWith(songLoading: true);
    final noURLSongs = songs.where((element) => element.url == null).toList();
    if (noURLSongs.isNotEmpty) {
      for (var element in noURLSongs) {
        element.url = await (await repo.getPlayUrl(element.id)).asFuture;
      }
      state = state.copyWith(songList: songs.where((value) => value.url != null).toList());
    }
    state.copyWith(songLoading: false);
  }

  _getLyric(Song song) async {
    state = state.copyWith(
      lyric: null,
      currentLyricIdx: null,
    );
    final lyric = await repo.lyric(song.id);
    state = state.copyWith(
      lyric: LyricRow.fromString(lyric ?? ''),
      currentLyricIdx: 0,
    );
  }

  _calcCurrLyric() {
    if (state.lyric == null) return;
    var index = state.lyric!.indexWhere((element) => element.time > state.position);
    if (index < 0) index = state.lyric!.length;
    state = state.copyWith(currentLyricIdx: index - 1);
  }

  setVolume(double v) {
    _audioPlayer.setVolume(v);
  }

  resume() async {
    if ((state.songList?.isEmpty ?? true)) return;
    playSongs(state.songList!, index: state.currentSongIdx ?? 0);
  }

  playSongs(List<Song> songs, {int index = 0}) async {
    await _setPlaylist(songs);
    _currPlaylist = ConcatenatingAudioSource(
        useLazyPreparation: true,
        shuffleOrder: DefaultShuffleOrder(),
        children: (state.songList ?? []).map((e) => e.toAudioSource()).toList());
    state = state.copyWith(currentSongIdx: index);
    await _audioPlayer.stop();
    await _audioPlayer.setAudioSource(
      _currPlaylist!,
      initialIndex: index,
      initialPosition: Duration.zero,
      preload: false,
    );
    await _audioPlayer.play();
    _saveState();
    _getLyric(state.currSong!);
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
