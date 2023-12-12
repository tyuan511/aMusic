import 'package:json_annotation/json_annotation.dart';
import 'package:laji_music/models/lyric.dart';
import 'package:laji_music/models/song.dart';

part 'player.g.dart';

@JsonSerializable()
class PlayerModel {
  final bool isPlaying;
  final Duration position;
  final int? currentSongIdx;
  final List<Song>? songList;
  final List<LyricRow>? lyric;
  final int? currentLyricIdx;

  const PlayerModel({
    required this.isPlaying,
    required this.position,
    required this.currentSongIdx,
    required this.songList,
    this.lyric,
    this.currentLyricIdx,
  });

  Song? get currSong => (songList?.isEmpty ?? true) ? null : songList![currentSongIdx ?? 0];

  PlayerModel copyWith({
    bool? isPlaying,
    Duration? position,
    int? currentSongIdx,
    List<Song>? songList,
    List<LyricRow>? lyric,
    int? currentLyricIdx,
  }) {
    return PlayerModel(
      isPlaying: isPlaying ?? this.isPlaying,
      position: position ?? this.position,
      currentSongIdx: currentSongIdx ?? this.currentSongIdx,
      songList: songList ?? this.songList,
      lyric: lyric ?? this.lyric,
      currentLyricIdx: currentLyricIdx ?? this.currentLyricIdx,
    );
  }

  factory PlayerModel.fromJson(Map<String, dynamic> json) => _$PlayerModelFromJson(json);

  Map<String, dynamic> toJson() => _$PlayerModelToJson(this);
}
