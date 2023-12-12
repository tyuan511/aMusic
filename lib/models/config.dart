import 'package:flutter/material.dart';
import 'package:json_annotation/json_annotation.dart';

part 'config.g.dart';

@JsonSerializable()
class ConfigModel {
  final ThemeMode themeMode;
  final bool autoPlay;

  const ConfigModel({required this.themeMode, this.autoPlay = true});

  ConfigModel copyWith({ThemeMode? themeMode, bool? autoPlay}) {
    return ConfigModel(
      themeMode: themeMode ?? this.themeMode,
      autoPlay: autoPlay ?? this.autoPlay,
    );
  }

  factory ConfigModel.fromJson(Map<String, dynamic> json) => _$ConfigModelFromJson(json);

  Map<String, dynamic> toJson() => _$ConfigModelToJson(this);
}
