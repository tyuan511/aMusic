// ignore_for_file: prefer_initializing_formals
// Named parameters cannot start with an underscore, so the private field has to
// be assigned in the initializer list.

import 'dart:async';
import 'dart:io';

import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

import '../core/config.dart';
import '../core/errors.dart';
import '../data/ncm_api.dart';
import '../models/song.dart';
import 'audio_cache.dart';

/// Called with the quality that was actually granted for [song].
typedef PlayUrlResolved = void Function(Song song, PlayUrl url);

/// Resolves a stream url for [song] at the requested [level].
typedef PlayUrlResolver = Future<PlayUrl> Function(Song song, AudioLevel level);

/// An [AudioSource] that resolves the (short lived) NetEase stream url only
/// when the player actually asks for bytes.
///
/// This keeps large playlists cheap: `/song/url/v1` is called once per track
/// instead of once per queue, and urls that expire mid-session are refreshed on
/// the next request.
class ResolvingAudioSource extends StreamAudioSource {
  ResolvingAudioSource({
    required this.song,
    required this.resolver,
    required this.levelProvider,
    required this._httpClient,
    this.onResolved,
    this.cache,
  }) : super(tag: mediaItemFor(song));

  static const Duration _urlTtl = Duration(minutes: 10);

  final Song song;
  final PlayUrlResolver resolver;

  /// Read on every request so that changing the quality in settings takes
  /// effect on the next track (or the next re-resolve) without a reload.
  final AudioLevel Function() levelProvider;
  final PlayUrlResolved? onResolved;
  final HttpClient _httpClient;

  /// Optional whole-file cache; `null` streams straight from the network.
  final AudioCache? cache;

  PlayUrl? _resolved;
  AudioLevel? _resolvedLevel;
  DateTime? _resolvedAt;

  /// Level of the whole-file cache entry this source served. A cache hit never
  /// runs [_resolve], so without this the granted quality of an already
  /// downloaded track would be unknown.
  String? _cachedLevel;
  Future<PlayUrl>? _resolving;

  /// The quality level granted by the server for the current url.
  String? get grantedLevel => _resolved?.level ?? _cachedLevel;

  /// The last URL opened for this source, when one has been resolved.
  /// Used by the background spectrum analyser so it can read the same audio
  /// location as the player without resolving the short-lived URL twice.
  String? get resolvedUri => _resolved?.url;

  /// Resolves the source for an auxiliary background analysis.
  Future<PlayUrl> resolveForAnalysis() => _resolve();

  Future<PlayUrl> _resolve({bool force = false}) {
    final level = levelProvider();
    final cached = _resolved;
    final resolvedAt = _resolvedAt;
    if (!force &&
        cached != null &&
        _resolvedLevel == level &&
        resolvedAt != null &&
        DateTime.now().difference(resolvedAt) < _urlTtl) {
      return Future.value(cached);
    }
    return _resolving ??= resolver(song, level)
        .then((url) {
          _resolved = url;
          _resolvedLevel = level;
          _resolvedAt = DateTime.now();
          _resolving = null;
          onResolved?.call(song, url);
          return url;
        })
        .catchError((Object error) {
          _resolving = null;
          throw error;
        });
  }

  /// Byte length of the whole file, learned from the first response.
  int? _sourceLength;

  /// [start] is inclusive and [end] is exclusive, as just_audio's proxy passes
  /// them (it converts the inclusive `Range` header end with `+ 1`).
  /// The last failure of [request], kept so the player can show the real
  /// reason instead of the platform's generic error code.
  Object? lastError;

  @override
  Future<StreamAudioResponse> request([int? start, int? end]) async {
    try {
      final response = await _request(start, end);
      lastError = null;
      return response;
    } on Object catch (error) {
      lastError = error;
      rethrow;
    }
  }

  Future<StreamAudioResponse> _request(int? start, int? end) async {
    final cache = this.cache;
    if (cache != null) {
      final hit = await cache.lookup(_cacheKey);
      if (hit != null) return _serveCached(hit, start, end);
    }
    try {
      final url = await _resolve();
      return await _fetch(url, start, end);
    } on AppException {
      rethrow;
    } on Object {
      // Expired url or a transient network error: resolve again, once.
      final url = await _resolve(force: true);
      return _fetch(url, start, end);
    }
  }

  String get _cacheKey => '${song.id}_${levelProvider().value}';

  bool _reportedCacheHit = false;

  StreamAudioResponse _serveCached(CachedAudio hit, int? start, int? end) {
    if (!_reportedCacheHit) {
      _reportedCacheHit = true;
      _cachedLevel ??= hit.level;
      onResolved?.call(
        song,
        PlayUrl(url: hit.file.uri.toString(), level: hit.level),
      );
    }
    final from = (start ?? 0).clamp(0, hit.length);
    final to = (end ?? hit.length).clamp(from, hit.length);
    return StreamAudioResponse(
      rangeRequestsSupported: true,
      sourceLength: hit.length,
      contentLength: to - from,
      offset: start == null && end == null ? null : from,
      stream: hit.file.openRead(from, to),
      contentType: hit.contentType ?? 'audio/mpeg',
    );
  }

  Future<StreamAudioResponse> _fetch(
    PlayUrl playUrl,
    int? start,
    int? end,
  ) async {
    final request = await _httpClient.getUrl(Uri.parse(playUrl.url));
    request
      ..followRedirects = true
      ..maxRedirects = 5
      ..headers.set(HttpHeaders.userAgentHeader, AppConfig.userAgent)
      ..headers.set(HttpHeaders.refererHeader, 'https://music.163.com/');
    final ranged = start != null || end != null;
    if (ranged) {
      // HTTP ranges are inclusive on both ends.
      final last = end == null ? '' : '${end - 1}';
      request.headers.set(HttpHeaders.rangeHeader, 'bytes=${start ?? 0}-$last');
    }
    final response = await request.close();

    if (response.statusCode == HttpStatus.forbidden ||
        response.statusCode == HttpStatus.notFound ||
        response.statusCode == HttpStatus.internalServerError) {
      await response.drain<void>();
      throw SongUnavailableException('音频源返回 ${response.statusCode}，链接可能已过期');
    }
    if (response.statusCode != HttpStatus.ok &&
        response.statusCode != HttpStatus.partialContent) {
      await response.drain<void>();
      throw SongUnavailableException('音频源返回 ${response.statusCode}');
    }

    final partial = response.statusCode == HttpStatus.partialContent;
    final range = partial
        ? parseContentRange(
            response.headers.value(HttpHeaders.contentRangeHeader),
          )
        : null;
    final contentLength = response.contentLength >= 0
        ? response.contentLength
        : null;

    // AVPlayer (iOS/macOS) refuses a stream whose total size it cannot learn,
    // so the full length must come back as `Content-Range: bytes a-b/<total>`.
    final total = range?.total ?? (partial ? null : contentLength);
    if (total != null) _sourceLength = total;

    final offset = partial ? (range?.start ?? start ?? 0) : 0;
    final length =
        contentLength ??
        (range != null ? range.end - range.start + 1 : null) ??
        (_sourceLength != null ? _sourceLength! - offset : null);

    final contentType = response.headers.contentType?.mimeType ?? 'audio/mpeg';
    // Only a response that carries the complete file is worth keeping.
    final whole =
        _sourceLength != null &&
        length == _sourceLength &&
        offset == 0 &&
        !playUrl.isTrial;
    final writer = whole && cache != null
        ? await cache!.openWriter(
            _cacheKey,
            expectedLength: _sourceLength!,
            level: playUrl.level,
            contentType: contentType,
          )
        : null;

    return StreamAudioResponse(
      rangeRequestsSupported:
          partial ||
          (response.headers.value(HttpHeaders.acceptRangesHeader) ?? 'none') !=
              'none',
      sourceLength: _sourceLength,
      contentLength: length,
      // A plain 200 is the whole file even when a range was asked for.
      offset: ranged || partial ? offset : null,
      stream: writer == null ? response : _tee(response, writer),
      // The CDN sends `audio/mpeg; charset=UTF-8`; players want the bare type.
      contentType: contentType,
    );
  }
}

/// Forwards [source] and copies every chunk into [writer]. The entry is
/// committed when the stream completes and discarded when the player
/// cancels early or the network fails.
Stream<List<int>> _tee(Stream<List<int>> source, AudioCacheWriter writer) {
  late final StreamController<List<int>> controller;
  StreamSubscription<List<int>>? subscription;
  controller = StreamController<List<int>>(
    onListen: () {
      subscription = source.listen(
        (chunk) {
          writer.add(chunk);
          controller.add(chunk);
        },
        onError: (Object error, StackTrace stack) {
          unawaited(writer.abort());
          controller.addError(error, stack);
        },
        onDone: () {
          unawaited(writer.commit());
          controller.close();
        },
        cancelOnError: true,
      );
    },
    onPause: () => subscription?.pause(),
    onResume: () => subscription?.resume(),
    onCancel: () async {
      await subscription?.cancel();
      await writer.abort();
    },
  );
  return controller.stream;
}

/// Lock screen / notification metadata of [song].
MediaItem mediaItemFor(Song song) {
  final pic = song.album.picUrl;
  Uri? art;
  if (pic != null && pic.isNotEmpty) {
    art = pic.startsWith('/') ? Uri.file(pic) : Uri.tryParse(pic);
  }
  return MediaItem(
    id: '${song.id}',
    title: song.name,
    album: song.album.name,
    artist: song.artistText,
    artUri: art,
    duration: song.duration,
  );
}

/// A parsed `Content-Range: bytes <start>-<end>/<total>` header value.
typedef ContentRange = ({int start, int end, int? total});

/// Parses a `Content-Range` value; `total` is null for the `*` form.
ContentRange? parseContentRange(String? header) {
  if (header == null) return null;
  final match = RegExp(r'^bytes\s+(\d+)-(\d+)/(\d+|\*)$')
      .firstMatch(header.trim());
  if (match == null) return null;
  return (
    start: int.parse(match[1]!),
    end: int.parse(match[2]!),
    total: int.tryParse(match[3]!),
  );
}
