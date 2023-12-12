// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'song.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

Song _$SongFromJson(Map<String, dynamic> json) => Song(
      id: json['id'] as int,
      name: json['name'] as String,
      duration: Duration(microseconds: json['duration'] as int),
      author: json['author'] as String,
      album: json['album'] as String,
      picUrl: json['picUrl'] as String,
      url: json['url'] as String?,
      isLike: json['isLike'] as bool? ?? false,
    );

Map<String, dynamic> _$SongToJson(Song instance) => <String, dynamic>{
      'id': instance.id,
      'name': instance.name,
      'duration': instance.duration.inMicroseconds,
      'author': instance.author,
      'album': instance.album,
      'picUrl': instance.picUrl,
      'isLike': instance.isLike,
      'url': instance.url,
    };
