import 'package:json_annotation/json_annotation.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

part 'song.g.dart';

enum SongLevel {
  standard('standard'),
  higher('higher'),
  exhigh('exhigh'),
  lossless('lossless'),
  hires('hires'),
  jyeffect('jyeffect'),
  sky('sky'),
  jymaster('jymaster');

  final String value;

  const SongLevel(this.value);

  String get name {
    switch (this) {
      case SongLevel.standard:
        return '标准';
      case SongLevel.higher:
        return '较高';
      case SongLevel.exhigh:
        return '极高';
      case SongLevel.lossless:
        return '无损';
      case SongLevel.hires:
        return 'Hi-Res';
      case SongLevel.jyeffect:
        return '高清环绕声';
      case SongLevel.sky:
        return '沉浸环绕声';
      case SongLevel.jymaster:
        return '超清母带';
    }
  }
}

@JsonSerializable()
class Song {
  final int id;
  final String name;
  final Duration duration;
  final String author;
  final String album;
  final String picUrl;
  final bool isLike;
  String? url;

  Song({
    required this.id,
    required this.name,
    required this.duration,
    required this.author,
    required this.album,
    required this.picUrl,
    this.url,
    this.isLike = false,
  });

  AudioSource toAudioSource() {
    return AudioSource.uri(
      Uri.parse(url!),
      tag: MediaItem(
        id: id.toString(),
        title: name,
        album: album,
        artUri: Uri.parse(picUrl),
      ),
    );
  }

  factory Song.fromJson(Map<String, dynamic> json) => _$SongFromJson(json);

  Map<String, dynamic> toJson() => _$SongToJson(this);
}
