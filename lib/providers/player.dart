import 'dart:convert';

import 'package:laji_music/consts/key.dart';
import 'package:laji_music/models/lyric.dart';
import 'package:laji_music/models/player.dart';
import 'package:laji_music/models/song.dart';
import 'package:laji_music/providers/config.dart';
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
  PlayerModel? _cachedState;

  @override
  PlayerModel build() {
    final json = storage.read(playerStorageKey);
    if (json != null) {
      _cachedState = PlayerModel.fromJson(jsonDecode(json));
      return _cachedState!;
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
      if (e.processingState == ProcessingState.loading || e.processingState == ProcessingState.buffering) {
        isLoading = true;
      }

      if (e.processingState == ProcessingState.ready) {
        isLoading = false;
      }

      state = state.copyWith(isPlaying: e.playing, songLoading: isLoading);
      _saveState();
    });

    _audioPlayer.positionStream.listen((e) {
      state = state.copyWith(position: e);
      _saveState();
    });

    _audioPlayer.currentIndexStream.listen((e) {
      state = state.copyWith(currentSongIdx: e);

      if (state.currentSongIdx != null) {
        _getLyric(state.currSong!);
      }

      _saveState();
    });
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

  setVolume(double v) {
    _audioPlayer.setVolume(v);
  }

  resume() async {
    if (_cachedState == null) return;
    if ((_cachedState!.songList?.isEmpty ?? true)) return;
    _currPlaylist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      shuffleOrder: DefaultShuffleOrder(),
      children: (_cachedState!.songList ?? []).map((e) => e.toAudioSource()).toList(),
    );
    await _audioPlayer.stop();
    await _audioPlayer.setAudioSource(
      _currPlaylist!,
      initialIndex: _cachedState!.currentSongIdx,
      initialPosition: _cachedState!.position,
      preload: false,
    );
    state = state.copyWith(currentLyricIdx: _cachedState!.currentLyricIdx);
    if (ref.read(configProvider).autoPlay) {
      await _audioPlayer.play();
    }
  }

  playSongs(List<Song> songs, {int index = 0, Duration position = Duration.zero}) async {
    state = state.copyWith(songList: songs);
    _currPlaylist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      shuffleOrder: DefaultShuffleOrder(),
      children: (state.songList ?? []).map((e) => e.toAudioSource()).toList(),
    );
    state = state.copyWith(currentSongIdx: index);
    await _audioPlayer.stop();
    await _audioPlayer.setAudioSource(
      _currPlaylist!,
      initialIndex: index,
      initialPosition: position,
      preload: false,
    );
    await _audioPlayer.play();
    _saveState();
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
