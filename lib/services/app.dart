import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/prefs.dart';
import 'accent_service.dart';
import 'api_host.dart';
import 'download_service.dart';
import 'library_service.dart';
import 'local_library_service.dart';
import 'lyric_service.dart';
import 'player_service.dart';
import 'recent_service.dart';
import 'session_service.dart';
import 'settings_service.dart';
import 'update_service.dart';

/// Composition root.
///
/// Services are plain objects owned for the lifetime of the process. The UI
/// reaches them through [app] and binds to the fine grained `ValueNotifier`s
/// they expose, so a rebuild is always scoped to the widget that actually needs
/// the new value.
class AppServices {
  AppServices._({
    required this.prefs,
    required this.settings,
    required this.apiHost,
    required this.session,
    required this.library,
    required this.lyrics,
    required this.accent,
    required this.player,
    required this.downloads,
    required this.localLibrary,
    required this.recent,
    required this.updates,
  });

  static Future<AppServices> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs, readSettings(prefs));
    final apiHost = ApiHost(prefs: prefs);
    final session = SessionService(apiHost);
    final library = LibraryService(apiHost, session);
    final lyrics = LyricService(apiHost);
    final accent = AccentService();
    final downloads = DownloadService(
      host: apiHost,
      settings: settings,
      prefs: prefs,
    );
    final localLibrary = LocalLibraryService(prefs: prefs);
    final recent = RecentService(prefs: prefs);
    final updates = UpdateService(prefs: prefs);
    final player = PlayerService(
      host: apiHost,
      settings: settings,
      lyrics: lyrics,
      accent: accent,
      downloads: downloads,
      localLibrary: localLibrary,
      recent: recent,
    );
    return AppServices._(
      prefs: prefs,
      settings: settings,
      apiHost: apiHost,
      session: session,
      library: library,
      lyrics: lyrics,
      accent: accent,
      player: player,
      downloads: downloads,
      localLibrary: localLibrary,
      recent: recent,
      updates: updates,
    );
  }

  final SharedPreferences prefs;
  final SettingsService settings;
  final ApiHost apiHost;
  final SessionService session;
  final LibraryService library;
  final LyricService lyrics;
  final AccentService accent;
  final PlayerService player;
  final DownloadService downloads;
  final LocalLibraryService localLibrary;
  final RecentService recent;
  final UpdateService updates;

  /// Flipped once [warmUp] finished; the router shows the splash until then.
  final ValueNotifier<bool> bootstrapped = ValueNotifier(false);

  /// Restores the persisted session and playback queue. Runs off the first
  /// frame so the splash screen is not blocked by the network.
  Future<void> warmUp() async {
    final snapshot = settings.readPlayback();
    try {
      // Local stores first: restoring the queue may point at downloaded or
      // local files.
      await Future.wait([downloads.init(), localLibrary.init(), recent.init()]);
      await Future.wait([session.restore(), player.init(snapshot: snapshot)]);
      await library.refreshLikedIds();
    } finally {
      bootstrapped.value = true;
    }
    unawaited(updates.checkInBackground());
  }

  void onAppPaused() => player.onAppPaused();

  void dispose() {
    player.dispose();
    downloads.dispose();
    localLibrary.dispose();
    library.dispose();
    session.dispose();
    apiHost.dispose();
    settings.dispose();
  }
}

/// Process wide handle, assigned in `main()`.
late AppServices app;
