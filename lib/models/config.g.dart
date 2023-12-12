// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'config.dart';

// **************************************************************************
// JsonSerializableGenerator
// **************************************************************************

ConfigModel _$ConfigModelFromJson(Map<String, dynamic> json) => ConfigModel(
      themeMode: $enumDecode(_$ThemeModeEnumMap, json['themeMode']),
      autoPlay: json['autoPlay'] as bool? ?? true,
    );

Map<String, dynamic> _$ConfigModelToJson(ConfigModel instance) =>
    <String, dynamic>{
      'themeMode': _$ThemeModeEnumMap[instance.themeMode]!,
      'autoPlay': instance.autoPlay,
    };

const _$ThemeModeEnumMap = {
  ThemeMode.system: 'system',
  ThemeMode.light: 'light',
  ThemeMode.dark: 'dark',
};
