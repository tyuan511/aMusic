import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:laji_music/consts/key.dart';
import 'package:laji_music/models/config.dart';
import 'package:laji_music/utils/storage.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'config.g.dart';

@riverpod
class Config extends _$Config {
  @override
  ConfigModel build() {
    final json = storage.read(configStorageKey);
    if (json == null) {
      return const ConfigModel(themeMode: ThemeMode.system);
    } else {
      return ConfigModel.fromJson(jsonDecode(json));
    }
  }

  _saveState() {
    storage.write(configStorageKey, jsonEncode(state.toJson()));
  }

  changeThemeMode(ThemeMode mode) {
    state = state.copyWith(themeMode: mode);
    _saveState();
  }

  changeAutoPlay(bool autoPlay) {
    state = state.copyWith(autoPlay: autoPlay);
    _saveState();
  }
}
