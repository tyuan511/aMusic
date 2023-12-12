import 'package:flutter/material.dart';

extension ThemeModeNameExtension on ThemeMode {
  String get label {
    switch (this) {
      case ThemeMode.system:
        return '跟随系统';
      case ThemeMode.light:
        return '浅色';
      case ThemeMode.dark:
        return '深色';
    }
  }
}
