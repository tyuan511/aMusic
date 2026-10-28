import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/loop_mode.dart';
import '../models/song.dart';

class PrefsKeys {
  PrefsKeys._();

  static const themeMode = 'settings.theme_mode';
  static const audioLevel = 'settings.audio_level';
  static const autoPlay = 'settings.auto_play';
  static const immersive = 'settings.immersive';
  static const volume = 'settings.volume';
  static const playbackSpeed = 'settings.playback_speed';
  static const showTranslation = 'settings.show_translation';
  static const showRomaji = 'settings.show_romaji';
  static const lyricFontSize = 'settings.lyric_font_size';
  static const lyricFontWeight = 'settings.lyric_font_weight';
  static const lyricBlur = 'settings.lyric_blur';
  static const lyricResumeSeconds = 'settings.lyric_resume_seconds';
  static const dynamicBackground = 'settings.dynamic_background';
  static const layoutMode = 'settings.layout_mode';
  static const uiScale = 'settings.ui_scale';
  static const autoUiScale = 'settings.auto_ui_scale';
  static const reportPlays = 'settings.report_plays';
  static const audioCacheMb = 'settings.audio_cache_mb';
  static const checkUpdates = 'settings.check_updates';
  static const eq = 'settings.eq';
  static const eqPresets = 'settings.eq_presets';
  static const cookie = 'auth.cookie';
  static const deviceProfile = 'auth.device';
  static const playback = 'playback.snapshot';
  static const searchHistory = 'search.history';
}

/// Forced layout, overriding the width based choice.
enum LayoutMode {
  auto('自动'),
  desktop('桌面'),
  mobile('手机');

  const LayoutMode(this.label);

  final String label;

  static LayoutMode fromName(String? name) => LayoutMode.values.firstWhere(
    (mode) => mode.name == name,
    orElse: () => LayoutMode.auto,
  );
}

/// Everything the user can change in the settings screen.
///
/// Services that persist their own data (local library, play
/// reports, recent tracks, update checks) do NOT add fields here: they use
/// `app.prefs` directly with their own key prefix (`local.`, `scrobble.`,
/// `recent.`, `update.`).
@immutable
class SettingsState {
  const SettingsState({
    this.themeMode = ThemeMode.dark,
    this.audioLevel = AudioLevel.exhigh,
    this.autoPlay = false,
    this.immersive = false,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.showTranslation = true,
    this.showRomaji = false,
    this.lyricFontSize = 26,
    this.lyricFontWeight = 600,
    this.lyricBlur = true,
    this.lyricResumeSeconds = 2.5,
    this.dynamicBackground = true,
    this.layoutMode = LayoutMode.auto,
    this.uiScale = 1.0,
    this.autoUiScale = true,
    this.reportPlays = true,
    this.audioCacheMb = 512,
    this.checkUpdates = true,
  });

  /// Dark by default: the design is built dark-first.
  final ThemeMode themeMode;
  final AudioLevel audioLevel;
  final bool autoPlay;

  /// Hide the system UI (phone / tablet only).
  final bool immersive;
  final double volume;

  /// 0.5 - 2.0.
  final double playbackSpeed;
  final bool showTranslation;
  final bool showRomaji;

  /// Lyric line size in logical pixels, 16 - 44.
  final double lyricFontSize;

  /// 400 / 500 / 600 / 700.
  final int lyricFontWeight;

  /// Blur lyric lines by their distance from the focus line.
  final bool lyricBlur;

  /// Seconds after a manual lyric scroll before the view follows again, 1 - 10.
  final double lyricResumeSeconds;

  /// Flowing album colour backdrop on the now playing screen.
  final bool dynamicBackground;
  final LayoutMode layoutMode;

  /// Global UI scale, 0.8 - 1.75. Ignored while [autoUiScale] is on.
  final double uiScale;

  /// Derive the UI scale from the screen (car head units get 1.35).
  final bool autoUiScale;

  /// Report finished plays to NetEase (listening history / recommendations).
  final bool reportPlays;

  /// Disk budget for cached audio, 0 disables caching.
  final int audioCacheMb;

  final bool checkUpdates;

  SettingsState copyWith({
    ThemeMode? themeMode,
    AudioLevel? audioLevel,
    bool? autoPlay,
    bool? immersive,
    double? volume,
    double? playbackSpeed,
    bool? showTranslation,
    bool? showRomaji,
    double? lyricFontSize,
    int? lyricFontWeight,
    bool? lyricBlur,
    double? lyricResumeSeconds,
    bool? dynamicBackground,
    LayoutMode? layoutMode,
    double? uiScale,
    bool? autoUiScale,
    bool? reportPlays,
    int? audioCacheMb,
    bool? checkUpdates,
  }) => SettingsState(
    themeMode: themeMode ?? this.themeMode,
    audioLevel: audioLevel ?? this.audioLevel,
    autoPlay: autoPlay ?? this.autoPlay,
    immersive: immersive ?? this.immersive,
    volume: volume ?? this.volume,
    playbackSpeed: playbackSpeed ?? this.playbackSpeed,
    showTranslation: showTranslation ?? this.showTranslation,
    showRomaji: showRomaji ?? this.showRomaji,
    lyricFontSize: lyricFontSize ?? this.lyricFontSize,
    lyricFontWeight: lyricFontWeight ?? this.lyricFontWeight,
    lyricBlur: lyricBlur ?? this.lyricBlur,
    lyricResumeSeconds: lyricResumeSeconds ?? this.lyricResumeSeconds,
    dynamicBackground: dynamicBackground ?? this.dynamicBackground,
    layoutMode: layoutMode ?? this.layoutMode,
    uiScale: uiScale ?? this.uiScale,
    autoUiScale: autoUiScale ?? this.autoUiScale,
    reportPlays: reportPlays ?? this.reportPlays,
    audioCacheMb: audioCacheMb ?? this.audioCacheMb,
    checkUpdates: checkUpdates ?? this.checkUpdates,
  );
}

SettingsState readSettings(SharedPreferences prefs) {
  const defaults = SettingsState();
  double clampDouble(String key, double fallback, double min, double max) =>
      (prefs.getDouble(key) ?? fallback).clamp(min, max).toDouble();
  final weight =
      prefs.getInt(PrefsKeys.lyricFontWeight) ?? defaults.lyricFontWeight;
  return SettingsState(
    themeMode: switch (prefs.getString(PrefsKeys.themeMode)) {
      'light' => ThemeMode.light,
      'system' => ThemeMode.system,
      _ => ThemeMode.dark,
    },
    audioLevel: AudioLevel.fromValue(prefs.getString(PrefsKeys.audioLevel)),
    autoPlay: prefs.getBool(PrefsKeys.autoPlay) ?? defaults.autoPlay,
    immersive: prefs.getBool(PrefsKeys.immersive) ?? defaults.immersive,
    volume: clampDouble(PrefsKeys.volume, 1.0, 0, 1),
    playbackSpeed: clampDouble(PrefsKeys.playbackSpeed, 1.0, 0.5, 2.0),
    showTranslation:
        prefs.getBool(PrefsKeys.showTranslation) ?? defaults.showTranslation,
    showRomaji: prefs.getBool(PrefsKeys.showRomaji) ?? defaults.showRomaji,
    lyricFontSize: clampDouble(
      PrefsKeys.lyricFontSize,
      defaults.lyricFontSize,
      16,
      44,
    ),
    lyricFontWeight: const [400, 500, 600, 700].contains(weight)
        ? weight
        : defaults.lyricFontWeight,
    lyricBlur: prefs.getBool(PrefsKeys.lyricBlur) ?? defaults.lyricBlur,
    lyricResumeSeconds: clampDouble(
      PrefsKeys.lyricResumeSeconds,
      defaults.lyricResumeSeconds,
      1,
      10,
    ),
    dynamicBackground:
        prefs.getBool(PrefsKeys.dynamicBackground) ??
        defaults.dynamicBackground,
    layoutMode: LayoutMode.fromName(prefs.getString(PrefsKeys.layoutMode)),
    uiScale: clampDouble(PrefsKeys.uiScale, 1.0, 0.8, 1.75),
    autoUiScale: prefs.getBool(PrefsKeys.autoUiScale) ?? defaults.autoUiScale,
    reportPlays: prefs.getBool(PrefsKeys.reportPlays) ?? defaults.reportPlays,
    audioCacheMb:
        (prefs.getInt(PrefsKeys.audioCacheMb) ?? defaults.audioCacheMb).clamp(
          0,
          8192,
        ),
    checkUpdates:
        prefs.getBool(PrefsKeys.checkUpdates) ?? defaults.checkUpdates,
  );
}

/// Persisted playback session, restored on the next launch.
class PlaybackSnapshot {
  const PlaybackSnapshot({
    this.songs = const [],
    this.index = 0,
    this.position = Duration.zero,
    this.repeat = LoopMode.all,
    this.shuffle = false,
    this.sourceTitle,
    this.sourceId,
  });

  final List<Song> songs;
  final int index;
  final Duration position;
  final LoopMode repeat;
  final bool shuffle;
  final String? sourceTitle;
  final int? sourceId;

  bool get isEmpty => songs.isEmpty;

  static const int _maxPersistedSongs = 400;

  /// The last encoded queue, keyed by list identity. The player persists a
  /// snapshot every few seconds while only the position moves, so the (up to
  /// 400 song) queue is serialised once per queue change instead of per write.
  static List<Song>? _encodedSongsFor;
  static String _encodedSongs = '[]';

  static String _songsJson(List<Song> songs) {
    if (!identical(songs, _encodedSongsFor)) {
      _encodedSongs = jsonEncode(
        songs.take(_maxPersistedSongs).map((song) => song.toJson()).toList(),
      );
      _encodedSongsFor = songs;
    }
    return _encodedSongs;
  }

  String encode() {
    final rest = jsonEncode({
      'index': index,
      'position': position.inMilliseconds,
      'repeat': repeat.name,
      'shuffle': shuffle,
      'sourceTitle': sourceTitle,
      'sourceId': sourceId,
    });
    // Splice the cached queue in front of the small scalar fields.
    return '{"songs":${_songsJson(songs)},${rest.substring(1)}';
  }

  static PlaybackSnapshot? decode(String? raw) {
    if (raw == null || raw.isEmpty) return null;
    try {
      final map = jsonDecode(raw) as Map<String, dynamic>;
      // Whether a track can be streamed is only known once its url is
      // requested. Older builds persisted a `st: -1` flag for every track,
      // which made the whole restored queue look taken down and skip forever,
      // so the stored hint is dropped here and the server decides on play.
      final rawSongs = map['songs'];
      final songs = Song.listFrom(
        rawSongs is List
            ? [
                for (final item in rawSongs)
                  if (item is Map<String, dynamic>) {...item}..remove('st'),
              ]
            : null,
      );
      if (songs.isEmpty) return null;
      final index = (map['index'] as num?)?.toInt() ?? 0;
      return PlaybackSnapshot(
        songs: songs,
        index: index.clamp(0, songs.length - 1),
        position: Duration(
          milliseconds: (map['position'] as num?)?.toInt() ?? 0,
        ),
        repeat: LoopModeX.fromName(map['repeat'] as String?),
        shuffle: map['shuffle'] as bool? ?? false,
        sourceTitle: map['sourceTitle'] as String?,
        sourceId: (map['sourceId'] as num?)?.toInt(),
      );
    } on Object {
      return null;
    }
  }
}
