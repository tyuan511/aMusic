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

  const ConfigModel(
      {required this.themeMode, this.level = SongLevel.standard, this.autoPlay = false, this.fullscreen = false});

  ConfigModel copyWith({ThemeMode? themeMode, SongLevel? level, bool? autoPlay, bool? fullscreen}) {
    return ConfigModel(
      themeMode: themeMode ?? this.themeMode,
      level: level ?? this.level,
      autoPlay: autoPlay ?? this.autoPlay,
      fullscreen: fullscreen ?? this.fullscreen,
    );
  }

  factory ConfigModel.fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
