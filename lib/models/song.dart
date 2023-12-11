class Song {
  final int id;
  final String name;
  final Duration duration;
  final String author;
  final String album;
  final String picUrl;
  String? url;

  Song({
    required this.id,
    required this.name,
    required this.duration,
    required this.author,
    required this.album,
    required this.picUrl,
    this.url,
  });
}
