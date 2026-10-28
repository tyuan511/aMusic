// ignore_for_file: prefer_initializing_formals
// Named parameters cannot start with an underscore, so the private fields are
// assigned in the initializer list.

import 'dart:async';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:just_audio/just_audio.dart';

import '../audio/audio_cache.dart';
import '../audio/resolving_source.dart';
import '../audio/sleep_timer.dart';
import '../core/config.dart';
import '../core/errors.dart';
import '../core/prefs.dart';
import '../data/ncm_api.dart';
import '../models/loop_mode.dart';
import '../models/song.dart';
import '../models/user.dart';
import 'accent_service.dart';
import 'api_host.dart';
import 'local_library_service.dart';
import 'lyric_service.dart';
import 'recent_service.dart';
import 'scrobble_queue.dart';
import 'settings_service.dart';

/// Immutable queue. Replaced wholesale so listeners can compare cheaply.
class PlayQueue {
  const PlayQueue({
    this.songs = const [],
    this.index = 0,
    this.repeat = LoopMode.all,
    this.shuffle = false,
    this.sourceTitle,
    this.sourceId,
  });

  final List<Song> songs;
  final int index;
  final LoopMode repeat;
  final bool shuffle;
  final String? sourceTitle;
  final int? sourceId;

  bool get isEmpty => songs.isEmpty;
  int get length => songs.length;

  Song? get current =>
      (index < 0 || index >= songs.length) ? null : songs[index];

  Song? songAt(int i) => (i < 0 || i >= songs.length) ? null : songs[i];

  PlayQueue copyWith({
    List<Song>? songs,
    int? index,
    LoopMode? repeat,
    bool? shuffle,
    String? sourceTitle,
    int? sourceId,
  }) => PlayQueue(
    songs: songs ?? this.songs,
    index: index ?? this.index,
    repeat: repeat ?? this.repeat,
    shuffle: shuffle ?? this.shuffle,
    sourceTitle: sourceTitle ?? this.sourceTitle,
    sourceId: sourceId ?? this.sourceId,
  );
}

class PlaybackState {
  const PlaybackState({
    this.playing = false,
    this.loading = false,
    this.error,
    this.isTrial = false,
    this.level,
  });

  final bool playing;
  final bool loading;

  /// Transient failure of the current track (unavailable / expired url).
  final String? error;

  /// The server only granted a short preview.
  final bool isTrial;

  /// Quality actually granted for the current track, e.g. `lossless`.
  final String? level;

  bool get hasTrack => !loading || playing;

  PlaybackState copyWith({
    bool? playing,
    bool? loading,
    String? error,
    bool? isTrial,
    String? level,
    bool clearError = false,
    bool clearLevel = false,
  }) => PlaybackState(
    playing: playing ?? this.playing,
    loading: loading ?? this.loading,
    error: clearError ? null : (error ?? this.error),
    isTrial: isTrial ?? this.isTrial,
    level: clearLevel ? null : (level ?? this.level),
  );
}

class PositionState {
  const PositionState({
    this.position = Duration.zero,
    this.duration = Duration.zero,
    this.buffered = Duration.zero,
  });

  final Duration position;
  final Duration duration;
  final Duration buffered;

  double get progress => duration == Duration.zero
      ? 0
      : (position.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  double get bufferedProgress => duration == Duration.zero
      ? 0
      : (buffered.inMilliseconds / duration.inMilliseconds).clamp(0.0, 1.0);

  PositionState copyWith({
    Duration? position,
    Duration? duration,
    Duration? buffered,
  }) => PositionState(
    position: position ?? this.position,
    duration: duration ?? this.duration,
    buffered: buffered ?? this.buffered,
  );
}

/// Frame accurate position for painters.
///
/// The progress bar repaints at display refresh rate; rebuilding widgets from a
/// 5 Hz stream would either look choppy or cost far too much. Instead the
/// painter asks this clock for an interpolated position every frame.
class PlaybackClock {
  Duration _position = Duration.zero;
  Duration _duration = Duration.zero;
  DateTime _syncedAt = DateTime.now();
  bool _running = false;
  double _speed = 1;

  void sync(Duration position, {required bool running, Duration? duration}) {
    _position = position;
    _running = running;
    _syncedAt = DateTime.now();
    if (duration != null) _duration = duration;
  }

  void setDuration(Duration duration) => _duration = duration;

  /// Playback rate; the interpolation advances this much faster.
  void setSpeed(double speed) {
    if (speed == _speed) return;
    _position = now();
    _syncedAt = DateTime.now();
    _speed = speed;
  }

  void setRunning(bool running) {
    if (running == _running) return;
    if (running) {
      _syncedAt = DateTime.now();
    } else {
      _position = now();
    }
    _running = running;
  }

  Duration get duration => _duration;
  bool get running => _running;

  Duration now() {
    if (!_running) return _position;
    final elapsed = DateTime.now().difference(_syncedAt);
    final estimate = _position + elapsed * _speed;
    if (_duration > Duration.zero && estimate > _duration) return _duration;
    return estimate;
  }
}

/// Which endless stream feeds the queue.
enum RadioKind { fm, heart }

/// The audio engine: queue, transport controls and the streams the UI binds to.
class PlayerService {
  PlayerService({
    required this._host,
    required this._settings,
    required this._lyrics,
    required this._accent,
    required this._localLibrary,
    required this._recent,
  }) {
    _lyrics.localPathFor = _localLibrary.pathFor;
    _sleep.trackRemaining = _trackRemaining;
  }

  final ApiHost _host;
  final SettingsService _settings;
  final LyricService _lyrics;
  final AccentService _accent;
  final LocalLibraryService _localLibrary;
  final RecentService _recent;

  late final AudioCache _cache = AudioCache(
    maxBytes: () => _settings.value.audioCacheMb * 1024 * 1024,
  );

  late final ScrobbleQueue _scrobbles = ScrobbleQueue(
    prefs: _settings.prefs,
    send: (songId, sourceId, seconds) =>
        _host.api.scrobble(songId, sourceId: sourceId, seconds: seconds),
  );

  late final SleepTimer _sleep = SleepTimer(
    onFade: _applyFade,
    onExpire: _onSleepExpired,
  );

  // --------------------------------------------------------- sleep / speed

  /// Remaining time of the sleep timer, `null` when off. `Duration.zero`
  /// while waiting for the current track to end.
  ValueNotifier<Duration?> get sleepRemaining => _sleep.remaining;

  /// `true` when the running timer stops at the end of a track.
  bool get sleepAtTrackEnd => _sleep.endOfTrack;

  /// Starts (or with `null` cancels) the sleep timer. [endOfTrack] waits for
  /// the current song to finish once the time is up; `Duration.zero` with
  /// [endOfTrack] stops after the current song. The last ~8 s fade out.
  void setSleepTimer(Duration? duration, {bool endOfTrack = false}) =>
      _sleep.start(duration, endOfTrack: endOfTrack);

  /// Current playback speed.
  final ValueNotifier<double> speed = ValueNotifier(1.0);

  /// Playback speed 0.5 - 2.0 (persisted in settings).
  Future<void> setSpeed(double value) async {
    final clamped = (value.clamp(0.5, 2.0) * 100).roundToDouble() / 100;
    speed.value = clamped;
    clock.setSpeed(clamped);
    if (_settings.value.playbackSpeed != clamped) {
      _settings.update((s) => s.copyWith(playbackSpeed: clamped));
    }
    try {
      await _player.setSpeed(clamped);
    } on Object catch (error) {
      debugPrint('set speed failed: $error');
    }
  }

  // ------------------------------------------------------------------ cache

  /// Bytes used by the audio cache.
  Future<int> cacheSize() => _cache.size();

  Future<void> clearCache() => _cache.clear();

  // ------------------------------------------------------------------ radio

  /// `true` while the queue is an FM / heart mode stream.
  final ValueNotifier<bool> radioMode = ValueNotifier(false);

  /// Which stream is active, `null` for a normal queue.
  final ValueNotifier<RadioKind?> radioKind = ValueNotifier(null);

  int? _heartPlaylistId;
  bool _refilling = false;

  /// Starts personal FM ("私人漫游"): an endless queue refilled from the FM
  /// endpoint.
  Future<void> startPersonalFm() async {
    final List<Song> songs;
    try {
      songs = await _host.api.personalFm();
    } on Object catch (error) {
      _reportError('私人漫游加载失败：${describeError(error)}');
      return;
    }
    if (songs.isEmpty) {
      _reportError('私人漫游暂时没有歌曲');
      return;
    }
    await _playSongs(songs, sourceTitle: '私人漫游', radio: RadioKind.fm);
  }

  /// Starts heart mode ("心动模式") seeded by the current / given song inside
  /// [playlistId] (defaults to the account's liked songs playlist).
  Future<void> startHeartMode({int? seedSongId, int? playlistId}) async {
    if (!_host.isLoggedIn) {
      _reportError('心动模式需要先登录');
      return;
    }
    try {
      final pid = playlistId ?? await _likedPlaylistId();
      if (pid == null) {
        _reportError('没有找到“我喜欢的音乐”歌单');
        return;
      }
      var seed = seedSongId ?? currentSong?.id;
      if (seed == null) {
        // Nothing playing: seed from a random liked song.
        final liked = (await _host.api.playlistDetail(pid)).tracks;
        if (liked.isEmpty) {
          _reportError('“我喜欢的音乐”还没有歌曲，先收藏几首吧');
          return;
        }
        seed = liked[DateTime.now().millisecond % liked.length].id;
      }
      _heartPlaylistId = pid;
      final more = await _host.api.heartModeList(seed, pid);
      final current = currentSong;
      if (current != null && current.id == seed) {
        // Keep the song that is playing; replace everything after it.
        await _replaceUpcoming(more.where((song) => song.id != seed).toList());
        queue.value = queue.value.copyWith(sourceTitle: '心动模式');
        _setRadio(RadioKind.heart);
        return;
      }
      final seedSong = (await _host.api.songDetails([seed])).firstOrNull;
      await _playSongs(
        [?seedSong, ...more.where((song) => song.id != seed)],
        sourceTitle: '心动模式',
        sourceId: pid,
        radio: RadioKind.heart,
      );
    } on Object catch (error) {
      _reportError('心动模式加载失败：${describeError(error)}');
    }
  }

  /// Heart mode as a play mode: on → recommendations seeded by the current
  /// song, off → back to the queue, repeat and shuffle it replaced.
  Future<void> toggleHeartMode() async {
    if (radioKind.value == RadioKind.heart) {
      await _leaveHeartMode();
      return;
    }
    if (radioKind.value == null && !queue.value.isEmpty) {
      _preHeart = queue.value;
    }
    await startHeartMode();
    if (radioKind.value != RadioKind.heart) _preHeart = null;
  }

  PlayQueue? _preHeart;

  Future<void> _leaveHeartMode() async {
    final saved = _preHeart;
    _preHeart = null;
    _setRadio(null);
    final current = currentSong;
    if (saved == null || saved.isEmpty || current == null) {
      queue.value = PlayQueue(
        songs: queue.value.songs,
        index: queue.value.index,
        repeat: queue.value.repeat,
        shuffle: queue.value.shuffle,
        sourceId: queue.value.sourceId,
      );
      _persistNow();
      return;
    }
    // The song that is playing stays; the rest goes back to how it was. A
    // heart mode song that was not in the old queue slots in after the
    // position the user left.
    var songs = saved.songs;
    var at = songs.indexWhere((song) => song.id == current.id);
    if (at < 0) {
      final after = saved.index.clamp(0, songs.length - 1) + 1;
      songs = [...songs.take(after), current, ...songs.skip(after)];
      at = after;
    }
    final index = queue.value.index;
    final length = queue.value.length;
    if (index + 1 < length) {
      await _player.removeAudioSourceRange(index + 1, length);
    }
    if (index > 0) await _player.removeAudioSourceRange(0, index);
    if (at > 0) {
      await _player.insertAudioSources(0, _buildSources(songs.sublist(0, at)));
    }
    if (at + 1 < songs.length) {
      await _player.addAudioSources(_buildSources(songs.sublist(at + 1)));
    }
    queue.value = PlayQueue(
      songs: List.unmodifiable(songs),
      index: at,
      repeat: saved.repeat,
      shuffle: saved.shuffle,
      sourceTitle: saved.sourceTitle,
      sourceId: saved.sourceId,
    );
    await _player.setLoopMode(saved.repeat);
    await _player.setShuffleModeEnabled(saved.shuffle);
    _persistNow();
  }

  Future<int?> _likedPlaylistId() async {
    final profile = await _host.api.loginStatus();
    if (profile == null) return null;
    final playlists = await _host.api.userPlaylists(profile.id);
    return UserCollections.split(playlists, profile.id).liked?.id;
  }

  /// FM "不喜欢": reports the track and skips it.
  Future<void> fmTrash() async {
    final song = currentSong;
    if (song == null) return;
    final seconds = _player.position.inSeconds;
    unawaited(
      _host.api
          .fmTrash(song.id, seconds: seconds)
          .catchError((Object error) => debugPrint('fm trash failed: $error')),
    );
    await next();
  }

  void _setRadio(RadioKind? kind) {
    radioKind.value = kind;
    radioMode.value = kind != null;
  }

  Future<void> _maybeRefill() async {
    final kind = radioKind.value;
    if (kind == null || _refilling) return;
    final left = queue.value.length - 1 - queue.value.index;
    if (left > 2) return;
    _refilling = true;
    try {
      final more = switch (kind) {
        RadioKind.fm => await _host.api.personalFm(),
        RadioKind.heart => await _host.api.heartModeList(
          currentSong?.id ?? 0,
          _heartPlaylistId ?? 0,
        ),
      };
      if (radioKind.value != kind) return;
      final known = {for (final song in queue.value.songs) song.id};
      final fresh = more.where((song) => known.add(song.id)).toList();
      if (fresh.isEmpty) return;
      await _player.addAudioSources(_buildSources(fresh));
      queue.value = queue.value.copyWith(
        songs: List.unmodifiable([...queue.value.songs, ...fresh]),
      );
      await _trimPlayedRadio();
      _persistNow();
    } on Object catch (error) {
      debugPrint('radio refill failed: $error');
    } finally {
      _refilling = false;
    }
  }

  /// Keeps an endless stream from growing forever: tracks played long ago are
  /// dropped once more than 30 lie behind the current one.
  Future<void> _trimPlayedRadio() async {
    final index = queue.value.index;
    if (index <= 30) return;
    final drop = index - 10;
    final songs = queue.value.songs.sublist(drop);
    // Publish the shifted index first: the index stream fires during the
    // removal and must find the same song at the new position.
    queue.value = queue.value.copyWith(
      songs: List.unmodifiable(songs),
      index: index - drop,
    );
    try {
      await _player.removeAudioSourceRange(0, drop);
    } on Object catch (error) {
      debugPrint('trim radio queue failed: $error');
    }
  }

  Future<void> _replaceUpcoming(List<Song> songs) async {
    final index = queue.value.index;
    final length = queue.value.length;
    if (index + 1 < length) {
      await _player.removeAudioSourceRange(index + 1, length);
    }
    final known = <int>{?currentSong?.id};
    final fresh = songs.where((song) => known.add(song.id)).toList();
    if (fresh.isNotEmpty) await _player.addAudioSources(_buildSources(fresh));
    queue.value = queue.value.copyWith(
      songs: List.unmodifiable([
        ...queue.value.songs.take(index + 1),
        ...fresh,
      ]),
    );
    _persistNow();
  }

  // ----------------------------------------------------------------- engine

  final HttpClient _httpClient = HttpClient()
    ..connectionTimeout = const Duration(seconds: 20)
    ..autoUncompress = false;

  late final AudioPlayer _player = AudioPlayer(
    userAgent: AppConfig.userAgent,
    useLazyPreparation: true,
    handleInterruptions: true,
  );

  // ------------------------------------------------------------------ state

  final ValueNotifier<PlayQueue> queue = ValueNotifier(const PlayQueue());

  /// Changes only when the track changes: song rows listen to this instead of
  /// the whole queue so a shuffle toggle does not rebuild every list item.
  final ValueNotifier<int?> currentSongId = ValueNotifier(null);

  final ValueNotifier<PlaybackState> playback = ValueNotifier(
    const PlaybackState(),
  );
  final ValueNotifier<PositionState> position = ValueNotifier(
    const PositionState(),
  );
  final ValueNotifier<double> volume = ValueNotifier(1.0);
  final ValueNotifier<bool> ready = ValueNotifier(false);

  final PlaybackClock clock = PlaybackClock();

  Song? get currentSong => queue.value.current;

  final List<StreamSubscription<Object?>> _subscriptions = [];

  int _consecutiveFailures = 0;
  Timer? _skipTimer;
  DateTime? _lastFailureAt;

  /// Restored position not yet confirmed by the engine (the player reports
  /// zero until the lazily prepared source loads).
  Duration? _pendingRestore;

  /// `false` after a restore until the user starts playback: failures of a
  /// restored queue must not auto-skip through it on launch.
  bool _userStarted = true;

  double _fade = 1;
  double _volumeBeforeMute = 1;

  // ------------------------------------------------------------------- init

  /// Wires the streams and restores the previous session. Call once from
  /// `main()` after the platform audio backend is initialised.
  Future<void> init({required PlaybackSnapshot? snapshot}) async {
    volume.value = _settings.value.volume;
    unawaited(_player.setVolume(_settings.value.volume));
    final savedSpeed = _settings.value.playbackSpeed.clamp(0.5, 2.0);
    speed.value = savedSpeed;
    clock.setSpeed(savedSpeed);
    if (savedSpeed != 1.0) unawaited(_player.setSpeed(savedSpeed));

    _subscriptions.addAll([
      _player.playerStateStream.listen(_onPlayerState, onError: _onPlayerError),
      _player.errorStream.listen(_onPlayerError),
      _player.currentIndexStream.listen(_onIndexChanged),
      _player.createPositionStream().listen(_onPosition),
      _player.durationStream.listen((duration) {
        if (duration == null) return;
        clock.setDuration(duration);
        position.value = position.value.copyWith(duration: duration);
      }),
      _player.playbackEventStream.listen((event) {
        if (event.bufferedPosition != position.value.buffered) {
          position.value = position.value.copyWith(
            buffered: event.bufferedPosition,
          );
        }
      }, onError: (Object _) {}),
      _player.positionDiscontinuityStream.listen(_onDiscontinuity),
    ]);
    unawaited(_scrobbles.flush());

    if (snapshot == null || snapshot.isEmpty) {
      ready.value = true;
      return;
    }

    final index = snapshot.index.clamp(0, snapshot.songs.length - 1);
    queue.value = PlayQueue(
      songs: List.unmodifiable(snapshot.songs),
      index: index,
      repeat: snapshot.repeat,
      shuffle: snapshot.shuffle,
      sourceTitle: snapshot.sourceTitle,
      sourceId: snapshot.sourceId,
    );
    _pendingRestore = snapshot.position;
    _userStarted = false;
    clock.sync(
      snapshot.position,
      running: false,
      duration: snapshot.songs[index].duration,
    );
    position.value = PositionState(
      position: snapshot.position,
      duration: snapshot.songs[index].duration,
    );

    try {
      await _player.setLoopMode(snapshot.repeat);
      await _player.setShuffleModeEnabled(snapshot.shuffle);
      await _player.setAudioSources(
        _buildSources(snapshot.songs),
        initialIndex: index,
        initialPosition: snapshot.position,
        preload: false,
      );
      // The index stream fires during setAudioSources; make sure the restored
      // track is announced even when it did not.
      _onIndexChanged(index);
      if (_settings.value.autoPlay) {
        _userStarted = true;
        await _player.play();
      }
    } on PlayerInterruptedException {
      // A newer request took over.
    } on Object catch (error) {
      debugPrint('restore playback failed: $error');
    } finally {
      ready.value = true;
    }
  }

  List<AudioSource> _buildSources(List<Song> songs) =>
      songs.map(_sourceFor).toList(growable: false);

  AudioSource _sourceFor(Song song) {
    final path = LocalLibraryService.isLocalId(song.id)
        ? _localLibrary.pathFor(song.id)
        : null;
    if (path != null) {
      return AudioSource.file(path, tag: mediaItemFor(song));
    }
    return ResolvingAudioSource(
      song: song,
      httpClient: _httpClient,
      levelProvider: () => _settings.value.audioLevel,
      resolver: _resolveUrl,
      onResolved: _onUrlResolved,
      cache: _cache,
    );
  }

  Future<PlayUrl> _resolveUrl(Song song, AudioLevel level) {
    if (LocalLibraryService.isLocalId(song.id)) {
      throw const SongUnavailableException('本地文件不存在或已被移动');
    }
    return _host.api.songUrlWithFallback(song.id, level: level);
  }

  void _onUrlResolved(Song song, PlayUrl url) {
    if (currentSong?.id != song.id) return;
    final next = playback.value.copyWith(
      isTrial: url.isTrial,
      level: url.level ?? playback.value.level,
      clearError: true,
    );
    if (next.isTrial != playback.value.isTrial ||
        next.level != playback.value.level ||
        playback.value.error != null) {
      playback.value = next;
    }
  }

  // -------------------------------------------------------------- transport

  /// Replaces the queue and starts playing at [index].
  Future<void> playSongs(
    List<Song> songs, {
    int index = 0,
    String? sourceTitle,
    int? sourceId,
    Duration position = Duration.zero,
  }) => _playSongs(
    songs,
    index: index,
    sourceTitle: sourceTitle,
    sourceId: sourceId,
    position: position,
  );

  Future<void> _playSongs(
    List<Song> songs, {
    int index = 0,
    String? sourceTitle,
    int? sourceId,
    Duration position = Duration.zero,
    RadioKind? radio,
  }) async {
    if (songs.isEmpty) return;
    final start = index.clamp(0, songs.length - 1);
    _consecutiveFailures = 0;
    _skipTimer?.cancel();
    _pendingRestore = null;
    _userStarted = true;
    _endSession();
    if (radio != RadioKind.heart) _preHeart = null;
    _setRadio(radio);

    queue.value = PlayQueue(
      songs: List.unmodifiable(songs),
      index: start,
      repeat: queue.value.repeat,
      shuffle: queue.value.shuffle,
      sourceTitle: sourceTitle ?? queue.value.sourceTitle,
      sourceId: sourceId,
    );
    playback.value = const PlaybackState(loading: true);
    clock.sync(position, running: false, duration: songs[start].duration);

    try {
      await _player.setAudioSources(
        _buildSources(songs),
        initialIndex: start,
        initialPosition: position,
        preload: true,
      );
      // Same index as before (e.g. 0 -> 0) does not fire the stream.
      _onIndexChanged(start);
      await _player.play();
    } on PlayerInterruptedException {
      // A newer play request took over; nothing to do.
    } on Object catch (error) {
      _onPlayerError(error);
    }
  }

  Future<void> togglePlayPause() async {
    if (queue.value.isEmpty) return;
    if (_player.playing) {
      await pause();
    } else {
      await play();
    }
  }

  Future<void> play() async {
    if (queue.value.isEmpty) return;
    _userStarted = true;
    try {
      await _player.play();
    } on Object catch (error) {
      _onPlayerError(error);
    }
  }

  Future<void> pause() async {
    await _player.pause();
    _persistNow();
  }

  Future<void> stop() => _player.stop();

  Future<void> next({bool userInitiated = true}) async {
    if (queue.value.isEmpty) return;
    if (userInitiated) {
      _consecutiveFailures = 0;
      _userStarted = true;
    }
    _pendingRestore = null;
    if (!_player.hasNext && radioKind.value != null) {
      await _maybeRefill();
    }
    if (_player.hasNext) {
      await _player.seekToNext();
    } else if (queue.value.repeat != LoopMode.off) {
      // repeat-one / end of a non-looping radio: go to the first track in
      // play order (shuffle aware).
      final order = _player.effectiveIndices;
      if (order.isEmpty) return;
      await _player.seek(Duration.zero, index: order.first);
    } else if (!userInitiated) {
      await _player.pause();
    }
  }

  Future<void> previous() async {
    if (queue.value.isEmpty) return;
    _userStarted = true;
    _pendingRestore = null;
    // Restart the track when it already played for a while, like most players.
    if (_player.position > const Duration(seconds: 4)) {
      await seek(Duration.zero);
      return;
    }
    if (_player.hasPrevious) {
      await _player.seekToPrevious();
    } else {
      final order = _player.effectiveIndices;
      await seek(
        Duration.zero,
        index: order.isEmpty ? _previousIndex(queue.value.index) : order.last,
      );
    }
  }

  int _previousIndex(int current) {
    final length = queue.value.length;
    if (length == 0) return 0;
    return current - 1 < 0 ? length - 1 : current - 1;
  }

  Future<void> seek(Duration position, {int? index}) {
    _pendingRestore = null;
    clock.sync(position, running: _player.playing);
    return _player.seek(position, index: index);
  }

  Future<void> playAt(int index) async {
    if (index < 0 || index >= queue.value.length) return;
    if (index == queue.value.index) {
      await togglePlayPause();
      return;
    }
    _consecutiveFailures = 0;
    _userStarted = true;
    _pendingRestore = null;
    try {
      await _player.seek(Duration.zero, index: index);
      await _player.play();
    } on Object catch (error) {
      _onPlayerError(error);
    }
  }

  // ------------------------------------------------------------------ queue

  /// Inserts [song] right after the current track.
  Future<void> playNext(Song song) async {
    if (queue.value.isEmpty) {
      await playSongs([song], sourceTitle: '接下来播放');
      return;
    }
    final existing = queue.value.songs.indexWhere((s) => s.id == song.id);
    if (existing == queue.value.index) return;
    if (existing >= 0) {
      final target = existing < queue.value.index
          ? queue.value.index
          : queue.value.index + 1;
      await moveInQueue(existing, target);
      return;
    }
    await _insertAt(queue.value.index + 1, song);
  }

  Future<void> addToQueue(Song song) async {
    if (queue.value.isEmpty) {
      await playSongs([song], sourceTitle: '播放队列');
      return;
    }
    if (queue.value.songs.any((s) => s.id == song.id)) return;
    await _insertAt(queue.value.length, song);
  }

  Future<void> _insertAt(int at, Song song) async {
    try {
      await _player.insertAudioSource(at, _sourceFor(song));
    } on Object catch (error) {
      debugPrint('insert audio source failed: $error');
      return;
    }
    final songs = [...queue.value.songs]..insert(at, song);
    queue.value = queue.value.copyWith(
      songs: List.unmodifiable(songs),
      index: at <= queue.value.index
          ? queue.value.index + 1
          : queue.value.index,
    );
    _persistNow();
  }

  /// Moves the song at [from] so it ends up at index [to] (both in the
  /// current list, `to` as after removal: ReorderableListView callers
  /// subtract one when moving down).
  Future<void> moveInQueue(int from, int to) async {
    final songs = [...queue.value.songs];
    if (from < 0 || from >= songs.length) return;
    final target = to.clamp(0, songs.length - 1);
    if (from == target) return;
    final current = queue.value.index;
    final song = songs.removeAt(from);
    songs.insert(target, song);
    var nextIndex = current;
    if (from == current) {
      nextIndex = target;
    } else if (from < current && target >= current) {
      nextIndex = current - 1;
    } else if (from > current && target <= current) {
      nextIndex = current + 1;
    }
    // Published before the engine moves so the index stream finds the same
    // song at the shifted position.
    queue.value = queue.value.copyWith(
      songs: List.unmodifiable(songs),
      index: nextIndex,
    );
    try {
      await _player.moveAudioSource(from, target);
    } on Object catch (error) {
      debugPrint('move audio source failed: $error');
    }
    _persistNow();
  }

  Future<void> removeFromQueue(int index) async {
    final songs = queue.value.songs;
    if (index < 0 || index >= songs.length) return;
    if (songs.length == 1) {
      await clearQueue();
      return;
    }
    final isCurrent = index == queue.value.index;
    final next = [...songs]..removeAt(index);
    var nextIndex = queue.value.index;
    if (index < queue.value.index) {
      nextIndex--;
    } else if (isCurrent) {
      nextIndex = index.clamp(0, next.length - 1);
    }
    if (isCurrent) _endSession();
    queue.value = queue.value.copyWith(
      songs: List.unmodifiable(next),
      index: nextIndex,
    );
    try {
      await _player.removeAudioSourceAt(index);
    } on Object catch (error) {
      debugPrint('remove audio source failed: $error');
    }
    _persistNow();
  }

  Future<void> clearQueue() async {
    _endSession();
    _setRadio(null);
    // Publish first so lists (Dismissible) update in the same frame.
    queue.value = const PlayQueue();
    currentSongId.value = null;
    playback.value = const PlaybackState();
    position.value = const PositionState();
    clock.sync(Duration.zero, running: false, duration: Duration.zero);
    unawaited(_accent.updateFor(null));
    _persistNow();
    await _player.stop();
    try {
      await _player.clearAudioSources();
    } on Object catch (error) {
      debugPrint('clear audio sources failed: $error');
    }
  }

  Future<void> toggleRepeat() async {
    final next = queue.value.repeat.next;
    queue.value = queue.value.copyWith(repeat: next);
    await _player.setLoopMode(next);
    _persistNow();
  }

  Future<void> toggleShuffle() async {
    final next = !queue.value.shuffle;
    queue.value = queue.value.copyWith(shuffle: next);
    // A fresh random order every time shuffle turns on.
    if (next) await _player.shuffle();
    await _player.setShuffleModeEnabled(next);
    _persistNow();
  }

  // ----------------------------------------------------------------- volume

  Future<void> setVolume(double value) async {
    final clamped = value.clamp(0.0, 1.0);
    volume.value = clamped;
    _settings.setVolume(clamped);
    await _player.setVolume(clamped * _fade);
  }

  /// Mutes, or restores the volume from before muting.
  Future<void> toggleMute() async {
    if (volume.value > 0) {
      _volumeBeforeMute = volume.value;
      await setVolume(0);
    } else {
      await setVolume(_volumeBeforeMute > 0 ? _volumeBeforeMute : 1);
    }
  }

  void _applyFade(double factor) {
    _fade = factor;
    unawaited(_player.setVolume(volume.value * factor));
  }

  Future<void> _onSleepExpired() async {
    await pause();
    _fade = 1;
    await _player.setVolume(volume.value);
  }

  Duration? _trackRemaining() {
    final duration = _player.duration;
    if (duration == null || duration <= Duration.zero) return null;
    final left = duration - _player.position;
    final rate = speed.value <= 0 ? 1.0 : speed.value;
    return left * (1 / rate);
  }

  // --------------------------------------------------------------- sessions

  /// The track whose listening time is being measured.
  Song? _sessionSong;
  int? _sessionSourceId;
  final Stopwatch _listened = Stopwatch();
  bool _sessionRecorded = false;

  void _beginSession(Song song) {
    _endSession();
    _sessionSong = song;
    _sessionSourceId = queue.value.sourceId;
    _sessionRecorded = false;
    _listened.reset();
    if (_player.playing) _listened.start();
  }

  /// Closes the measured session: plays of 30 s or more are reported.
  void _endSession() {
    final song = _sessionSong;
    _sessionSong = null;
    _listened.stop();
    if (song == null) return;
    final seconds = _listened.elapsed.inSeconds;
    if (seconds < 30 ||
        LocalLibraryService.isLocalId(song.id) ||
        !_host.isLoggedIn ||
        !_settings.value.reportPlays) {
      return;
    }
    _scrobbles.add(
      ScrobbleEntry(
        songId: song.id,
        sourceId: _sessionSourceId,
        seconds: seconds,
      ),
    );
  }

  void _checkRecent() {
    final song = _sessionSong;
    if (song == null || _sessionRecorded) return;
    if (_listened.elapsed < const Duration(seconds: 5)) return;
    _sessionRecorded = true;
    _recent.record(song);
  }

  // ---------------------------------------------------------------- streams

  void _onPlayerState(PlayerState state) {
    final processing = state.processingState;
    final loading =
        processing == ProcessingState.loading ||
        processing == ProcessingState.buffering;
    final previous = playback.value;
    clock.setRunning(state.playing && processing == ProcessingState.ready);

    if (state.playing && processing == ProcessingState.ready) {
      _listened.start();
    } else {
      _listened.stop();
    }

    // `playerStateStream` fires on every playback event, so only publish (and
    // therefore only rebuild listeners) when something actually changed.
    if (previous.playing != state.playing || previous.loading != loading) {
      playback.value = previous.copyWith(
        playing: state.playing,
        loading: loading,
      );
    }
    if (processing == ProcessingState.ready && state.playing) {
      // Something actually plays: the failure streak is over.
      _consecutiveFailures = 0;
    }
    if (processing == ProcessingState.ready && previous.loading && !loading) {
      final duration = _player.duration;
      if (duration != null) {
        clock.setDuration(duration);
        position.value = position.value.copyWith(duration: duration);
      }
    }
    if (processing == ProcessingState.completed) {
      // The end of a non-looping queue.
      _sleep.trackEnded();
      _endSession();
    }
    if ((previous.playing && !state.playing) ||
        processing == ProcessingState.completed ||
        processing == ProcessingState.idle) {
      _persistNow();
    }
  }

  void _onPosition(Duration value) {
    final pending = _pendingRestore;
    if (pending != null) {
      // Until the lazily prepared source loads the engine reports zero;
      // keep showing (and persisting) the restored position.
      if (value < pending - const Duration(seconds: 1)) return;
      _pendingRestore = null;
    }
    final duration = _player.duration ?? position.value.duration;
    position.value = position.value.copyWith(
      position: value,
      duration: duration,
    );
    clock.sync(
      value,
      running:
          _player.playing && _player.processingState == ProcessingState.ready,
      duration: _player.duration,
    );
    _checkRecent();
    _settings.writePlayback(snapshot());
  }

  void _onDiscontinuity(PositionDiscontinuity event) {
    if (event.reason != PositionDiscontinuityReason.autoAdvance) return;
    // A track finished on its own (not skipped).
    _sleep.trackEnded();
    final previousIndex = event.previousEvent.currentIndex;
    if (previousIndex == event.event.currentIndex) {
      // Repeat one: the index stream stays silent, the play starts over.
      final song = currentSong;
      if (song != null) _beginSession(song);
    }
  }

  void _onIndexChanged(int? index) {
    if (index == null) return;
    final song = queue.value.songAt(index);
    if (song == null) return;
    if (queue.value.index != index) {
      queue.value = queue.value.copyWith(index: index);
    }
    final changed = currentSongId.value != song.id;
    if (!changed) {
      if (_sessionSong?.id != song.id) _beginSession(song);
      return;
    }
    currentSongId.value = song.id;
    _beginSession(song);

    playback.value = playback.value.copyWith(
      clearError: true,
      clearLevel: true,
      isTrial: false,
    );
    if (_pendingRestore == null) {
      clock.sync(Duration.zero, running: false, duration: song.duration);
      position.value = PositionState(duration: song.duration);
    }
    _lyrics.preload(song.id);
    // Warm the next track so skipping is instant.
    _lyrics.preload(queue.value.songAt(index + 1)?.id);
    unawaited(_accent.updateFor(song.album.picUrl));
    unawaited(_maybeRefill());
    _persistNow();
  }

  /// After this many tracks in a row fail, playback pauses instead of skipping
  /// through the whole queue (and around it again when repeat is on).
  static const int _maxConsecutiveFailures = 4;

  void _onPlayerError(Object error) {
    if (error is PlayerInterruptedException) return;
    // play() throwing and the error stream report the same failure.
    final now = DateTime.now();
    final last = _lastFailureAt;
    _lastFailureAt = now;
    if (last != null &&
        now.difference(last) < const Duration(milliseconds: 400)) {
      return;
    }
    final source = _currentSource();
    final cause = source?.lastError ?? error;
    final message = describeError(cause);
    if (cause is SongUnavailableException) {
      // Copyright / VIP restrictions are expected; report compactly.
      _onTrackFailed('${currentSong?.name ?? '当前歌曲'}：${cause.message}');
    } else {
      _onTrackFailed('播放失败：$message');
    }
  }

  ResolvingAudioSource? _currentSource() {
    final index = _player.currentIndex;
    final sources = _player.audioSources;
    if (index == null || index < 0 || index >= sources.length) return null;
    final source = sources[index];
    return source is ResolvingAudioSource ? source : null;
  }

  void _onTrackFailed(String message) {
    _consecutiveFailures++;
    // A restored queue that fails on launch waits for the user.
    if (!_userStarted) {
      _reportError(message);
      return;
    }
    // Never let a broken queue turn into an endless "cannot play" popup: stop
    // after a few tracks and say why once.
    if (_consecutiveFailures >= _maxConsecutiveFailures) {
      _skipTimer?.cancel();
      _consecutiveFailures = 0;
      _reportError('多首歌曲无法播放，已暂停。请确认网络正常，或换一首歌试试。');
      unawaited(pause());
      return;
    }
    _reportError(message);
    _scheduleAutoSkip();
  }

  void _reportError(String message) {
    playback.value = playback.value.copyWith(error: message, loading: false);
    // Errors are transient UI hints; drop them again after a while.
    Timer(const Duration(seconds: 4), () {
      if (playback.value.error == message) {
        playback.value = playback.value.copyWith(clearError: true);
      }
    });
  }

  void _scheduleAutoSkip() {
    _skipTimer?.cancel();
    _skipTimer = Timer(const Duration(milliseconds: 600), () {
      unawaited(next(userInitiated: false));
    });
  }

  // ----------------------------------------------------------- persistence

  PlaybackSnapshot snapshot() {
    final current = queue.value;
    if (current.isEmpty) return const PlaybackSnapshot();
    return PlaybackSnapshot(
      songs: current.songs,
      index: current.index,
      position: _pendingRestore ?? _player.position,
      repeat: current.repeat,
      shuffle: current.shuffle,
      sourceTitle: current.sourceTitle,
      sourceId: current.sourceId,
    );
  }

  void _persistNow() {
    _settings
      ..writePlayback(snapshot())
      ..flushPlayback();
  }

  /// Call from the app lifecycle handler.
  void onAppPaused() {
    _settings.writePlayback(snapshot());
    _settings.flushPlayback();
  }

  void dispose() {
    _endSession();
    _skipTimer?.cancel();
    _sleep.dispose();
    _scrobbles.dispose();
    for (final subscription in _subscriptions) {
      subscription.cancel();
    }
    _httpClient.close(force: true);
    _player.dispose();
  }
}
