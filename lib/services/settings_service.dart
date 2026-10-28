import 'dart:async';

import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import '../models/song.dart';

/// User configurable settings.
///
/// A single [ValueNotifier] is enough here: settings change rarely, so one
/// notifier per field would only cost readability. Widgets that care about a
/// single value (volume, theme mode) rebuild on their own.
class SettingsService extends ValueNotifier<SettingsState> {
  SettingsService(this._prefs, SettingsState initial) : super(initial);

  final SharedPreferences _prefs;

  SharedPreferences get prefs => _prefs;

  /// Publishes [next] and persists only the fields that changed. Sliders
  /// (volume, lyric size) call this on every drag frame, and SharedPreferences
  /// rewrites its whole backing file per call on Android.
  void _save(SettingsState next) {
    final prev = value;
    value = next;
    void put<T>(T Function(SettingsState s) field, void Function(T v) write) {
      final v = field(next);
      if (v != field(prev)) write(v);
    }

    put(
      (s) => s.themeMode.name,
      (v) => _prefs.setString(PrefsKeys.themeMode, v),
    );
    put(
      (s) => s.audioLevel.value,
      (v) => _prefs.setString(PrefsKeys.audioLevel, v),
    );
    put((s) => s.autoPlay, (v) => _prefs.setBool(PrefsKeys.autoPlay, v));
    put((s) => s.replayGain, (v) => _prefs.setBool(PrefsKeys.replayGain, v));
    put((s) => s.immersive, (v) => _prefs.setBool(PrefsKeys.immersive, v));
    put(
      (s) => s.playbackSpeed,
      (v) => _prefs.setDouble(PrefsKeys.playbackSpeed, v),
    );
    put(
      (s) => s.showTranslation,
      (v) => _prefs.setBool(PrefsKeys.showTranslation, v),
    );
    put((s) => s.showRomaji, (v) => _prefs.setBool(PrefsKeys.showRomaji, v));
    put(
      (s) => s.lyricFontSize,
      (v) => _prefs.setDouble(PrefsKeys.lyricFontSize, v),
    );
    put(
      (s) => s.lyricFontWeight,
      (v) => _prefs.setInt(PrefsKeys.lyricFontWeight, v),
    );
    put((s) => s.lyricBlur, (v) => _prefs.setBool(PrefsKeys.lyricBlur, v));
    put(
      (s) => s.lyricResumeSeconds,
      (v) => _prefs.setDouble(PrefsKeys.lyricResumeSeconds, v),
    );
    put(
      (s) => s.dynamicBackground,
      (v) => _prefs.setBool(PrefsKeys.dynamicBackground, v),
    );
    put(
      (s) => s.layoutMode.name,
      (v) => _prefs.setString(PrefsKeys.layoutMode, v),
    );
    put((s) => s.uiScale, (v) => _prefs.setDouble(PrefsKeys.uiScale, v));
    put((s) => s.autoUiScale, (v) => _prefs.setBool(PrefsKeys.autoUiScale, v));
    put((s) => s.reportPlays, (v) => _prefs.setBool(PrefsKeys.reportPlays, v));
    put((s) => s.audioCacheMb, (v) => _prefs.setInt(PrefsKeys.audioCacheMb, v));
    put(
      (s) => s.checkUpdates,
      (v) => _prefs.setBool(PrefsKeys.checkUpdates, v),
    );
    if (next.volume != prev.volume) _scheduleVolumeWrite();
  }

  Timer? _volumeDebounce;

  /// Volume changes arrive per drag frame / key repeat; persist the settled
  /// value only.
  void _scheduleVolumeWrite() {
    _volumeDebounce?.cancel();
    _volumeDebounce = Timer(const Duration(milliseconds: 400), _writeVolume);
  }

  void _writeVolume() {
    _volumeDebounce = null;
    _prefs.setDouble(PrefsKeys.volume, value.volume);
  }

  /// Generic setter for any field: `settings.update((s) => s.copyWith(...))`.
  void update(SettingsState Function(SettingsState current) change) =>
      _save(change(value));

  void setThemeMode(ThemeMode mode) => _save(value.copyWith(themeMode: mode));
  void setAudioLevel(AudioLevel level) =>
      _save(value.copyWith(audioLevel: level));
  void setAutoPlay(bool autoPlay) => _save(value.copyWith(autoPlay: autoPlay));
  void setReplayGain(bool replayGain) =>
      _save(value.copyWith(replayGain: replayGain));
  void setImmersive(bool immersive) =>
      _save(value.copyWith(immersive: immersive));
  void setVolume(double volume) =>
      _save(value.copyWith(volume: volume.clamp(0.0, 1.0)));
  void setShowTranslation(bool show) =>
      _save(value.copyWith(showTranslation: show));
  void setShowRomaji(bool show) => _save(value.copyWith(showRomaji: show));

  // ------------------------------------------------------- playback snapshot

  PlaybackSnapshot? readPlayback() =>
      PlaybackSnapshot.decode(_prefs.getString(PrefsKeys.playback));

  Timer? _playbackDebounce;
  PlaybackSnapshot? _pending;
  String? _lastPlayback;

  /// Debounced: the queue position changes several times a second and writing
  /// a 400 song queue to disk every tick would burn CPU for nothing.
  void writePlayback(PlaybackSnapshot snapshot) {
    _pending = snapshot;
    _playbackDebounce ??= Timer.periodic(
      const Duration(seconds: 3),
      (_) => flushPlayback(),
    );
  }

  /// Persists whatever is pending. Called on pause, track change and app pause.
  void flushPlayback() {
    final snapshot = _pending;
    if (snapshot == null) return;
    _pending = null;
    final encoded = snapshot.encode();
    if (encoded == _lastPlayback) return;
    _lastPlayback = encoded;
    _prefs.setString(PrefsKeys.playback, encoded);
  }

  // --------------------------------------------------------- search history

  List<String> get searchHistory =>
      _prefs.getStringList(PrefsKeys.searchHistory) ?? const [];

  void pushSearchHistory(String keyword) {
    final trimmed = keyword.trim();
    if (trimmed.isEmpty) return;
    final next = [
      trimmed,
      ...searchHistory.where((item) => item != trimmed),
    ].take(12).toList();
    _prefs.setStringList(PrefsKeys.searchHistory, next);
  }

  void removeSearchHistory(String keyword) => _prefs.setStringList(
    PrefsKeys.searchHistory,
    searchHistory.where((i) => i != keyword).toList(),
  );

  void clearSearchHistory() => _prefs.remove(PrefsKeys.searchHistory);

  @override
  void dispose() {
    if (_volumeDebounce != null) {
      _volumeDebounce!.cancel();
      _writeVolume();
    }
    flushPlayback();
    _playbackDebounce?.cancel();
    super.dispose();
  }
}
