import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';

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
}
