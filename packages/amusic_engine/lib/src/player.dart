import 'dart:async';
import 'dart:ffi';

import 'package:ffi/ffi.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_platform_interface/just_audio_platform_interface.dart';

import 'bindings.dart';

/// Equalizer settings the engine applies in its audio callback.
class AmusicEq {
  const AmusicEq({
    this.bands = const [],
    this.gainDb = 0,
    this.limiter = true,
    this.effect = 0,
  });

  /// `(freq, q, gainDb)` per peaking filter.
  final List<(double, double, double)> bands;
  final double gainDb;
  final bool limiter;

  /// A DSP sound effect: 0 none, 1 3D surround, 2 360 rotation, 3 LiveHouse,
  /// 4 harmonic exciter, 5 chorus, 6 flanger, 7 phaser, 8 echo, 9 dream.
  final int effect;

  static const AmusicEq off = AmusicEq();
}

/// Reads a track's ReplayGain in dB from what the engine opens (a local file
/// path or an http url); `null` plays that track at unity gain. The app
/// installs it through `AmusicJustAudio.setReplayGain`.
typedef AmusicReplayGain = double? Function(String uri);

class _Track {
  _Track(this.uri);

  /// What the engine opens: a file path or an http url.
  final String uri;

  static _Track from(AudioSourceMessage message) {
    if (message is UriAudioSourceMessage) {
      final parsed = Uri.tryParse(message.uri);
      if (parsed != null && parsed.scheme == 'file') {
        return _Track(parsed.toFilePath());
      }
      return _Track(message.uri);
    }
    throw UnsupportedError('${message.runtimeType} is not supported');
  }
}

/// A `just_audio` player backed by the Rust engine.
///
/// The engine plays one track at a time and can be told which track follows so
/// it rolls over without a gap; everything about the queue (order, shuffle,
/// loop mode, inserts and removals) lives here.
class AmusicPlayer extends AudioPlayerPlatform {
  AmusicPlayer(super.id, this._native, AmusicEq eq) {
    _handle = _native.create();
    if (_handle == nullptr) {
      throw PlatformException(
        code: 'engine',
        message: 'could not open the audio output',
      );
    }
    applyEq(eq);
    _kick();
  }

  final AmusicNative _native;
  late final Pointer<Void> _handle;
  Timer? _timer;

  /// When the last position event went out, so playing does not flood the
  /// event stream: just_audio extrapolates the position between events.
  DateTime _lastEvent = DateTime.fromMillisecondsSinceEpoch(0);

  final _events = StreamController<PlaybackEventMessage>.broadcast();
  final _data = StreamController<PlayerDataMessage>.broadcast();

  final List<_Track> _tracks = [];
  List<int> _shuffleOrder = const [];
  bool _shuffle = false;
  LoopModeMessage _loop = LoopModeMessage.off;

  int _index = 0;

  /// The track the engine was told follows the current one.
  int? _queuedNext;
  bool _playing = false;
  ProcessingStateMessage _state = ProcessingStateMessage.idle;
  Duration? _duration;
  int? _errorCode;
  String? _errorMessage;

  /// Completes when the engine finished the `load` we are waiting for.
  Completer<void>? _loadDone;
  int _loadSeqWanted = 0;
  int _lastAdvanceSeq = 0;
  bool _disposed = false;

  @override
  Stream<PlaybackEventMessage> get playbackEventMessageStream => _events.stream;

  @override
  Stream<PlayerDataMessage> get playerDataMessageStream => _data.stream;

  // ------------------------------------------------------------- equalizer

  void applyEq(AmusicEq eq) {
    if (_disposed) return;
    final count = eq.bands.length;
    final bands = calloc<AmusicBand>(count == 0 ? 1 : count);
    try {
      for (var i = 0; i < count; i++) {
        final (f, q, g) = eq.bands[i];
        bands[i]
          ..freq = f
          ..q = q
          ..gainDb = g;
      }
      _native.setEq(_handle, bands, count, eq.gainDb, eq.limiter, eq.effect);
    } finally {
      calloc.free(bands);
    }
  }

  // ----------------------------------------------------------------- queue

  List<int> get _order => _shuffle && _shuffleOrder.length == _tracks.length
      ? _shuffleOrder
      : List.generate(_tracks.length, (i) => i);

  /// The index that follows [_index], or `null` at the end of the queue.
  int? _nextIndex() {
    if (_tracks.isEmpty) return null;
    if (_loop == LoopModeMessage.one) return _index;
    final order = _order;
    final at = order.indexOf(_index);
    if (at >= 0 && at + 1 < order.length) return order[at + 1];
    if (_loop == LoopModeMessage.all) return order.first;
    return null;
  }

  /// Tells the engine which track to roll into after the current one.
  void _queueNext() {
    if (_disposed) return;
    final next = _nextIndex();
    _queuedNext = next;
    if (next == null) {
      _native.setNext(_handle, nullptr);
      _native.setNextGain(_handle, double.nan);
      return;
    }
    final url = _tracks[next].uri.toNativeUtf8();
    try {
      _native.setNext(_handle, url);
    } finally {
      malloc.free(url);
    }
    // The gain switches exactly where the queued track starts.
    _native.setNextGain(_handle, _gainDbOf(next));
  }

  // ---------------------------------------------------------- replay gain

  /// Where the per track ReplayGain comes from; `null` keeps every track at
  /// unity gain. Set through [AmusicJustAudio.setReplayGain].
  static AmusicReplayGain? replayGain;

  /// A tag is a hint, not a licence to clip: cut freely, boost a little.
  static const double _maxBoostDb = 6;
  static const double _maxCutDb = -12;

  double _gainDbOf(int index) {
    if (index < 0 || index >= _tracks.length) return 0;
    final db = replayGain?.call(_tracks[index].uri);
    if (db == null || !db.isFinite) return 0;
    return db.clamp(_maxCutDb, _maxBoostDb).toDouble();
  }

  /// Pushes the gain of the current and of the queued track. Runs after every
  /// load and whenever [replayGain] changed, so flipping the setting takes
  /// effect without a reload.
  void applyReplayGain() {
    if (_disposed || _tracks.isEmpty) return;
    _native.setGain(_handle, _gainDbOf(_index));
    final next = _queuedNext;
    _native.setNextGain(_handle, next == null ? double.nan : _gainDbOf(next));
  }

  /// Opens track [index] and waits for the engine to be ready (or fail).
  Future<void> _start(int index, {Duration position = Duration.zero}) async {
    _index = index;
    _queuedNext = null;
    _state = ProcessingStateMessage.loading;
    _duration = null;
    _errorCode = null;
    _errorMessage = null;
    _emit();

    final status = calloc<AmusicStatus>();
    final url = _tracks[index].uri.toNativeUtf8();
    try {
      _native.status(_handle, status);
      _loadSeqWanted = status.ref.loadSeq + 1;
      _loadDone = Completer<void>();
      _native.load(_handle, url, position.inMicroseconds / 1e6);
      _kick();
    } finally {
      malloc.free(url);
      calloc.free(status);
    }
    await _loadDone!.future;
  }

  void _finishLoad(AmusicStatus st) {
    final done = _loadDone;
    if (done == null || done.isCompleted) return;
    _loadDone = null;
    if (st.state == EngineState.error) {
      final message = _native.errorOf(_handle);
      _state = ProcessingStateMessage.idle;
      _errorCode = 1;
      _errorMessage = message.isEmpty ? 'could not load the track' : message;
      _emit();
      done.completeError(PlatformException(code: '1', message: _errorMessage));
      return;
    }
    _state = ProcessingStateMessage.ready;
    _duration = st.duration < 0
        ? null
        : Duration(microseconds: (st.duration * 1e6).round());
    _native.setGain(_handle, _gainDbOf(_index));
    if (_playing) _native.play(_handle);
    _queueNext();
    _emit();
    done.complete();
  }

  // ------------------------------------------------------------- polling

  /// How long to wait before the next look at the engine: quickly while
  /// something is loading, every 250 ms while playing (gapless advances and
  /// the end of the queue are noticed within that), and rarely when paused.
  Duration get _pollInterval {
    if (_loadDone != null) return const Duration(milliseconds: 50);
    return _playing
        ? const Duration(milliseconds: 250)
        : const Duration(milliseconds: 1000);
  }

  /// Polls soon and then keeps the adaptive schedule going. Called whenever
  /// the engine just got a command whose result we want to see quickly.
  void _kick() {
    if (_disposed) return;
    _timer?.cancel();
    _timer = Timer(Duration.zero, _tick);
  }

  void _tick() {
    if (_disposed) return;
    _poll();
    _timer = Timer(_pollInterval, _tick);
  }

  void _poll() {
    if (_disposed) return;
    final st = calloc<AmusicStatus>();
    try {
      _native.status(_handle, st);
      final s = st.ref;

      if (_loadDone != null && s.loadSeq >= _loadSeqWanted) {
        _finishLoad(s);
        return;
      }
      if (_state == ProcessingStateMessage.loading) return;

      // The engine rolled into the queued track without a gap.
      if (s.advanceSeq != _lastAdvanceSeq) {
        _lastAdvanceSeq = s.advanceSeq;
        final next = _queuedNext;
        if (next != null) {
          _index = next;
          _duration = s.duration < 0
              ? null
              : Duration(microseconds: (s.duration * 1e6).round());
          _queueNext();
          _emit(position: s.position);
        }
      }

      if (s.state == EngineState.ended &&
          _state != ProcessingStateMessage.completed) {
        final next = _queuedNext;
        if (next != null) {
          // The prefetch failed; open the next track the slow way.
          unawaited(_startQuietly(next));
        } else {
          _state = ProcessingStateMessage.completed;
          _emit(position: s.position);
        }
        return;
      }

      if (_playing &&
          s.state == EngineState.ready &&
          DateTime.now().difference(_lastEvent) >=
              const Duration(milliseconds: 1000)) {
        _emit(position: s.position);
      }
    } finally {
      calloc.free(st);
    }
  }

  Future<void> _startQuietly(int index) async {
    try {
      await _start(index);
    } on PlatformException {
      // _start already emitted the error event.
    }
  }

  void _emit({double? position}) {
    if (_events.isClosed) return;
    _lastEvent = DateTime.now();
    final pos = position ?? _readPosition();
    _events.add(
      PlaybackEventMessage(
        processingState: _state,
        updateTime: DateTime.now(),
        updatePosition: Duration(microseconds: (pos * 1e6).round()),
        bufferedPosition: _duration ?? Duration.zero,
        duration: _duration,
        icyMetadata: null,
        currentIndex: _tracks.isEmpty ? null : _index,
        androidAudioSessionId: null,
        errorCode: _errorCode,
        errorMessage: _errorMessage,
      ),
    );
  }

  double _readPosition() {
    final st = calloc<AmusicStatus>();
    try {
      _native.status(_handle, st);
      return st.ref.position;
    } finally {
      calloc.free(st);
    }
  }

  // --------------------------------------------------------------- loading

  @override
  Future<LoadResponse> load(LoadRequest request) async {
    final message = request.audioSourceMessage;
    _tracks.clear();
    if (message is ConcatenatingAudioSourceMessage) {
      _tracks.addAll(message.children.map(_Track.from));
      _shuffleOrder = message.shuffleOrder;
    } else {
      _tracks.add(_Track.from(message));
      _shuffleOrder = const [0];
    }
    if (_tracks.isEmpty) {
      _state = ProcessingStateMessage.idle;
      _emit(position: 0);
      return LoadResponse(duration: null);
    }
    final first = request.initialIndex ?? (_shuffle ? _order.first : 0);
    await _start(
      first.clamp(0, _tracks.length - 1),
      position: request.initialPosition ?? Duration.zero,
    );
    return LoadResponse(duration: _duration);
  }

  // -------------------------------------------------------------- transport

  @override
  Future<PlayResponse> play(PlayRequest request) async {
    _playing = true;
    _native.play(_handle);
    _kick();
    return PlayResponse();
  }

  @override
  Future<PauseResponse> pause(PauseRequest request) async {
    _playing = false;
    _native.pause(_handle);
    _emit();
    return PauseResponse();
  }

  @override
  Future<SetVolumeResponse> setVolume(SetVolumeRequest request) async {
    _native.setVolume(_handle, request.volume);
    return SetVolumeResponse();
  }

  @override
  Future<SetSpeedResponse> setSpeed(SetSpeedRequest request) async {
    _native.setSpeed(_handle, request.speed);
    return SetSpeedResponse();
  }

  @override
  Future<SetPitchResponse> setPitch(SetPitchRequest request) async =>
      SetPitchResponse();

  @override
  Future<SetSkipSilenceResponse> setSkipSilence(
    SetSkipSilenceRequest request,
  ) async => SetSkipSilenceResponse();

  @override
  Future<SetLoopModeResponse> setLoopMode(SetLoopModeRequest request) async {
    _loop = request.loopMode;
    _queueNext();
    return SetLoopModeResponse();
  }

  @override
  Future<SetShuffleModeResponse> setShuffleMode(
    SetShuffleModeRequest request,
  ) async {
    _shuffle = request.shuffleMode != ShuffleModeMessage.none;
    _queueNext();
    return SetShuffleModeResponse();
  }

  @override
  Future<SetShuffleOrderResponse> setShuffleOrder(
    SetShuffleOrderRequest request,
  ) async {
    final message = request.audioSourceMessage;
    if (message is ConcatenatingAudioSourceMessage) {
      _shuffleOrder = message.shuffleOrder;
    }
    _queueNext();
    return SetShuffleOrderResponse();
  }

  @override
  Future<SetAutomaticallyWaitsToMinimizeStallingResponse>
  setAutomaticallyWaitsToMinimizeStalling(
    SetAutomaticallyWaitsToMinimizeStallingRequest request,
  ) async => SetAutomaticallyWaitsToMinimizeStallingResponse();

  @override
  Future<SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse>
  setCanUseNetworkResourcesForLiveStreamingWhilePaused(
    SetCanUseNetworkResourcesForLiveStreamingWhilePausedRequest request,
  ) async => SetCanUseNetworkResourcesForLiveStreamingWhilePausedResponse();

  @override
  Future<SetPreferredPeakBitRateResponse> setPreferredPeakBitRate(
    SetPreferredPeakBitRateRequest request,
  ) async => SetPreferredPeakBitRateResponse();

  @override
  Future<SeekResponse> seek(SeekRequest request) async {
    final index = request.index;
    final position = request.position ?? Duration.zero;
    if (index != null && index != _index && index < _tracks.length) {
      await _start(index, position: position);
    } else if (_tracks.isNotEmpty) {
      _native.seek(_handle, position.inMicroseconds / 1e6);
      if (_state == ProcessingStateMessage.completed) {
        _state = ProcessingStateMessage.ready;
      }
      if (_playing) _native.play(_handle);
      _emit(position: position.inMicroseconds / 1e6);
      _kick();
    }
    return SeekResponse();
  }

  // ------------------------------------------------------- queue mutations

  @override
  Future<ConcatenatingInsertAllResponse> concatenatingInsertAll(
    ConcatenatingInsertAllRequest request,
  ) async {
    final at = request.index.clamp(0, _tracks.length);
    _tracks.insertAll(at, request.children.map(_Track.from));
    if (_tracks.length > request.children.length && at <= _index) {
      _index += request.children.length;
    }
    _shuffleOrder = request.shuffleOrder;
    _queueNext();
    _emit();
    return ConcatenatingInsertAllResponse();
  }

  @override
  Future<ConcatenatingRemoveRangeResponse> concatenatingRemoveRange(
    ConcatenatingRemoveRangeRequest request,
  ) async {
    final start = request.startIndex;
    final end = request.endIndex.clamp(start, _tracks.length);
    final removedCurrent = _index >= start && _index < end;
    _tracks.removeRange(start, end);
    _shuffleOrder = request.shuffleOrder;
    if (_tracks.isEmpty) {
      _native.stop(_handle);
      _state = ProcessingStateMessage.idle;
      _index = 0;
      _queuedNext = null;
      _emit(position: 0);
    } else if (removedCurrent) {
      // Like ExoPlayer: the item that slid into the gap takes over.
      await _startQuietly(start.clamp(0, _tracks.length - 1));
    } else {
      if (_index >= end) _index -= end - start;
      _queueNext();
      _emit();
    }
    return ConcatenatingRemoveRangeResponse();
  }

  @override
  Future<ConcatenatingMoveResponse> concatenatingMove(
    ConcatenatingMoveRequest request,
  ) async {
    final from = request.currentIndex;
    final to = request.newIndex;
    final moved = _tracks.removeAt(from);
    _tracks.insert(to, moved);
    if (_index == from) {
      _index = to;
    } else if (from < _index && to >= _index) {
      _index -= 1;
    } else if (from > _index && to <= _index) {
      _index += 1;
    }
    _shuffleOrder = request.shuffleOrder;
    _queueNext();
    _emit();
    return ConcatenatingMoveResponse();
  }

  // --------------------------------------------------------------- teardown

  @override
  Future<DisposeResponse> dispose(DisposeRequest request) async {
    release();
    return DisposeResponse();
  }

  void release() {
    if (_disposed) return;
    _disposed = true;
    _timer?.cancel();
    _native.free(_handle);
    unawaited(_events.close());
    unawaited(_data.close());
  }
}
