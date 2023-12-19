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
  final bool equalizerEnabled;

  const ConfigModel(
      {required this.themeMode,
      this.level = SongLevel.standard,
      this.autoPlay = false,
      this.fullscreen = false,
      this.equalizerEnabled = false});

  ConfigModel copyWith(
      {ThemeMode? themeMode, SongLevel? level, bool? autoPlay, bool? fullscreen, bool? equalizerEnabled}) {
    return ConfigModel(
      themeMode: themeMode ?? this.themeMode,
      level: level ?? this.level,
      autoPlay: autoPlay ?? this.autoPlay,
      fullscreen: fullscreen ?? this.fullscreen,
      equalizerEnabled: equalizerEnabled ?? this.equalizerEnabled,
    );
  }

  factory ConfigModel.fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
