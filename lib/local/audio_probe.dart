import 'package:amusic_engine/amusic_engine.dart';

import 'file_names.dart';
import 'tag_picture.dart';

/// Container of a probed file, as reported by the engine (content based, not
/// the extension: NetEase sometimes serves a FLAC with an ID3 prefix, or an
/// mp3 named .flac). Mirrors `ProbedContainer` index for index.
enum AudioContainer { mp3, flac, m4a, ogg, wav, aac, unknown }

/// Metadata read from an audio file. Empty strings mean "not tagged".
class AudioMetadata {
  const AudioMetadata({
    this.title = '',
    this.artist = '',
    this.album = '',
    this.duration = Duration.zero,
    this.trackNumber,
    this.cover,
    this.container = AudioContainer.unknown,
    this.replayGainDb,
  });

  final String title;
  final String artist;
  final String album;
  final Duration duration;
  final int? trackNumber;
  final TagPicture? cover;
  final AudioContainer container;

  /// `REPLAYGAIN_TRACK_GAIN` in dB, `null` when the file carries no such tag.
  final double? replayGainDb;

  AudioMetadata copyWith({
    String? title,
    String? artist,
    String? album,
    Duration? duration,
    int? trackNumber,
    TagPicture? cover,
    AudioContainer? container,
    double? replayGainDb,
  }) => AudioMetadata(
    title: title ?? this.title,
    artist: artist ?? this.artist,
    album: album ?? this.album,
    duration: duration ?? this.duration,
    trackNumber: trackNumber ?? this.trackNumber,
    cover: cover ?? this.cover,
    container: container ?? this.container,
    replayGainDb: replayGainDb ?? this.replayGainDb,
  );
}

/// Tag / duration reader for mp3 (ID3v1-2.4), FLAC, M4A, WAV, Ogg and ADTS AAC.
///
/// The parsing happens in the Rust engine; files are probed in a helper
/// isolate so scanning a library never blocks a frame.
class AudioProbe {
  const AudioProbe();

  /// Probes the file at [path]. Never throws: unreadable files yield empty
  /// metadata (the file name fallback still applies).
  Future<AudioMetadata> probeFile(String path) async {
    try {
      return _convert(await AmusicTools.probeFileAsync(path));
    } on Object {
      return const AudioMetadata();
    }
  }

  static AudioMetadata _convert(ProbedAudio probed) {
    final bytes = probed.cover;
    return AudioMetadata(
      title: probed.title,
      artist: probed.artist,
      album: probed.album,
      duration: probed.duration,
      trackNumber: probed.trackNumber,
      cover: bytes == null ? null : TagPicture.sniff(bytes),
      container: AudioContainer.values[probed.container.index],
      replayGainDb: probed.replayGainDb,
    );
  }

  // ------------------------------------------------------------- fallback

  /// `Artist - Title.mp3` -> (artist, title); a name without ` - ` is the
  /// title alone.
  static ({String artist, String title}) fromFileName(String path) {
    final stem = stemOf(path).trim();
    final split = stem.indexOf(' - ');
    if (split > 0) {
      return (
        artist: stem.substring(0, split).trim(),
        title: stem.substring(split + 3).trim(),
      );
    }
    return (artist: '', title: stem);
  }
}
