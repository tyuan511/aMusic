// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigModel _$ConfigModelFromJson(Map<String, dynamic> json) => ConfigModel(
      themeMode: $enumDecode(_$ThemeModeEnumMap, json['themeMode']),
      autoPlay: json['autoPlay'] as bool? ?? true,
      level: $enumDecodeNullable(_$SongLevelEnumMap, json['level']) ??
          SongLevel.standard,
    );

Map<String, dynamic> _$ConfigModelToJson(ConfigModel instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'autoPlay': instance.autoPlay,
      'level': _$SongLevelEnumMap[instance.level]!,
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
