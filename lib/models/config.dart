import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';
import 'package:laji_music/models/song.dart';

part 'config.g.dart';

@JsonSerializable()
class ConfigModel {
  final ThemeMode themeMode;
  final SongLevel level;
  final bool autoPlay;
  final bool fullscreen;
  final double loudness;

  const ConfigModel(
      {required this.themeMode,
      this.level = SongLevel.standard,
      this.autoPlay = false,
      this.fullscreen = false,
      this.loudness = 0});

  ConfigModel copyWith({ThemeMode? themeMode, SongLevel? level, bool? autoPlay, bool? fullscreen, double? loudness}) {
    return ConfigModel(
      themeMode: themeMode ?? this.themeMode,
      level: level ?? this.level,
      autoPlay: autoPlay ?? this.autoPlay,
      fullscreen: fullscreen ?? this.fullscreen,
      loudness: loudness ?? this.loudness,
    );
  }

  factory ConfigModel.fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
