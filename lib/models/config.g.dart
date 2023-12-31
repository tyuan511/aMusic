// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigModel _$ConfigModelFromJson(Map<String, dynamic> json) => ConfigModel(
      themeMode: $enumDecode(_$ThemeModeEnumMap, json['themeMode']),
      level: $enumDecodeNullable(_$SongLevelEnumMap, json['level']) ??
          SongLevel.standard,
      autoPlay: json['autoPlay'] as bool? ?? false,
      fullscreen: json['fullscreen'] as bool? ?? false,
      equalizerEnabled: json['equalizerEnabled'] as bool? ?? false,
    );

Map<String, dynamic> _$ConfigModelToJson(ConfigModel instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'level': _$SongLevelEnumMap[instance.level]!,
      'autoPlay': instance.autoPlay,
      'fullscreen': instance.fullscreen,
      'equalizerEnabled': instance.equalizerEnabled,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};

const _$SongLevelEnumMap = {
  SongLevel.standard: 'standard',
  SongLevel.higher: 'higher',
  SongLevel.exhigh: 'exhigh',
  SongLevel.lossless: 'lossless',
  SongLevel.hires: 'hires',
  SongLevel.jyeffect: 'jyeffect',
  SongLevel.sky: 'sky',
  SongLevel.jymaster: 'jymaster',
};
