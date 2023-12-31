import 'dart:convert';

import 'package:amusic/consts/key.dart';
import 'package:amusic/models/lyric.dart';
import 'package:amusic/models/player.dart';
import 'package:amusic/models/song.dart';
import 'package:amusic/providers/config.dart';
import 'package:amusic/utils/repo.dart';
import 'package:amusic/utils/storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';
import 'package:just_audio/just_audio.dart';

part 'player.g.dart';

@Riverpod(keepAlive: true)
class Player extends _$Player {
  // final _equalizer = AndroidEqualizer();

  late final _audioPlayer = AudioPlayer(
    userAgent:
        'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/119.0.0.0 Safari/537.36',
    // audioPipeline: AudioPipeline(
    //   androidAudioEffects: [
    //     _equalizer,
    //   ],
    // ),
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

  init() async {
    final config = ref.read(configProvider);

    if (_cachedState == null) return;
    if ((_cachedState!.songList?.isEmpty ?? true)) return;
    _currPlaylist = ConcatenatingAudioSource(
      useLazyPreparation: true,
      shuffleOrder: DefaultShuffleOrder(),
      children: (_cachedState!.songList ?? []).map((e) => e.toAudioSource()).toList(),
    );
    await _audioPlayer.setLoopMode(state.loopMode);
    await _audioPlayer.setShuffleModeEnabled(state.shuffle);
    await _audioPlayer.stop();
    await _audioPlayer.setAudioSource(
      _currPlaylist!,
      initialIndex: _cachedState!.currentSongIdx,
      initialPosition: _cachedState!.position,
      preload: false,
    );
    state = state.copyWith(currentLyricIdx: _cachedState!.currentLyricIdx);
    if (config.autoPlay) {
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

  toggleRepeatMode() async {
    // repeat -> shuffle -> repeatOne
    if (state.loopMode == LoopMode.all && !state.shuffle) {
      state = state.copyWith(shuffle: true, loopMode: LoopMode.all);
    } else if (state.shuffle) {
      state = state.copyWith(shuffle: false, loopMode: LoopMode.one);
    } else if (state.loopMode == LoopMode.one && !state.shuffle) {
      state = state.copyWith(shuffle: false, loopMode: LoopMode.all);
    }
    await _audioPlayer.setLoopMode(state.loopMode);
    await _audioPlayer.setShuffleModeEnabled(state.shuffle);
  }

  // changeEqualizerEnabled(bool enabled) {
  //   _equalizer.setEnabled(enabled);
  // }

  // AndroidEqualizer getEqualizer() {
  //   return _equalizer;
  // }
}
