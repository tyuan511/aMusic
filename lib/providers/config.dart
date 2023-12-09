import 'package:flutter/material.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config.g.dart';

@immutable
class ConfigData {
  final ThemeMode themeMode;

  const ConfigData({required this.themeMode});

  ConfigData copyWith({ThemeMode? themeMode}) {
    return ConfigData(
      themeMode: themeMode ?? this.themeMode,
    );
  }
}

@riverpod
class Config extends _$Config {
  @override
  ConfigData build() => const ConfigData(themeMode: ThemeMode.system);

  changeThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
  }
}
