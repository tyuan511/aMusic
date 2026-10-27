import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/song.dart';

/// Locally remembered recently played tracks (newest first, deduplicated,
/// at most [maxTracks]). The player records a track once it played 5 s.
class RecentService {
  RecentService({required this._prefs});

  static const String prefsKey = 'recent.tracks';
  static const int maxTracks = 100;

  final SharedPreferences _prefs;

  final ValueNotifier<List<Song>> tracks = ValueNotifier(const []);

  Future<void> init() async {
    final raw = _prefs.getString(prefsKey);
    if (raw == null || raw.isEmpty) return;
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! List) return;
      tracks.value = List.unmodifiable(
        [
          for (final item in decoded)
            if (item is Map<String, dynamic>) Song.fromJson(item),
        ].where((song) => song.id != 0).take(maxTracks),
      );
    } on FormatException {
      // Corrupt entry: start over rather than crash on launch.
      await _prefs.remove(prefsKey);
    }
  }

  void record(Song song) {
    final next = [
      song,
      ...tracks.value.where((item) => item.id != song.id),
    ].take(maxTracks).toList(growable: false);
    tracks.value = List.unmodifiable(next);
    _prefs.setString(
      prefsKey,
      jsonEncode([for (final item in next) item.toJson()]),
    );
  }

  void clear() {
    tracks.value = const [];
    _prefs.remove(prefsKey);
  }
}
