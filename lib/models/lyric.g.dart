// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'lyric.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

LyricRow _$LyricRowFromJson(Map<String, dynamic> json) => LyricRow(
      time: Duration(microseconds: json['time'] as int),
      text: json['text'] as String,
    );

Map<String, dynamic> _$LyricRowToJson(LyricRow instance) => <String, dynamic>{
      'time': instance.time.inMicroseconds,
      'text': instance.text,
    };
