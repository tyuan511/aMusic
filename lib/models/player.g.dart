// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'player.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

PlayerModel _$PlayerModelFromJson(Map<String, dynamic> json) => PlayerModel(
      isPlaying: json['isPlaying'] as bool,
      position: Duration(microseconds: json['position'] as int),
      currentSongIdx: json['currentSongIdx'] as int?,
      songList: (json['songList'] as List<dynamic>?)
          ?.map((e) => Song.fromJson(e as Map<String, dynamic>))
          .toList(),
      lyric: (json['lyric'] as List<dynamic>?)
          ?.map((e) => LyricRow.fromJson(e as Map<String, dynamic>))
          .toList(),
      currentLyricIdx: json['currentLyricIdx'] as int?,
      songLoading: json['songLoading'] as bool? ?? false,
      loopMode: $enumDecodeNullable(_$LoopModeEnumMap, json['loopMode']) ??
          LoopMode.all,
      shuffle: json['shuffle'] as bool? ?? false,
    );

Map<String, dynamic> _$PlayerModelToJson(PlayerModel instance) =>
    <String, dynamic>{
      'isPlaying': instance.isPlaying,
      'position': instance.position.inMicroseconds,
      'currentSongIdx': instance.currentSongIdx,
      'songList': instance.songList,
      'lyric': instance.lyric,
      'currentLyricIdx': instance.currentLyricIdx,
      'songLoading': instance.songLoading,
      'loopMode': _$LoopModeEnumMap[instance.loopMode]!,
      'shuffle': instance.shuffle,
    };

const _$LoopModeEnumMap = {
  LoopMode.off: 'off',
  LoopMode.one: 'one',
  LoopMode.all: 'all',
};
