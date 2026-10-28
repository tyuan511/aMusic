import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:amusic_engine/amusic_engine.dart';

import '../audio/eq/eq_dsp.dart';
import '../audio/eq/eq_service.dart';
import '../core/prefs.dart';
import 'accent_service.dart';
import 'api_host.dart';
import 'library_service.dart';
import 'local_library_service.dart';
import 'lyric_service.dart';
import 'player_service.dart';
import 'recent_service.dart';
import 'session_service.dart';
import 'settings_service.dart';
import 'update_service.dart';

/// Hands the equalizer to the Rust engine, which runs the biquads itself and
/// has a real limiter, so it takes the bands and the bare preamp.
Future<void> _applyEq(EqEngineConfig config) async {
  final active =
      config.bands.isNotEmpty || config.preampDb != 0 || config.effect != 0;
  AmusicJustAudio.setEq(
    AmusicEq(
      bands: [for (final b in config.bands) (b.freq, b.q, b.gain)],
      gainDb: config.preampDb,
      // Stay bit-transparent while the equalizer is off.
      limiter: active,
      effect: config.effect,
    ),
  );
}

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
    required this.eq,
    required this.apiHost,
    required this.session,
    required this.library,
    required this.lyrics,
    required this.accent,
    required this.player,
    required this.localLibrary,
    required this.recent,
    required this.updates,
  });

  static Future<AppServices> bootstrap() async {
    final prefs = await SharedPreferences.getInstance();
    final settings = SettingsService(prefs, readSettings(prefs));
    // Built before the player so the first engine instance already has the chain.
    final eq = EqService(prefs: prefs, sink: _applyEq);
    final apiHost = ApiHost(prefs: prefs);
    final session = SessionService(apiHost);
    final library = LibraryService(apiHost, session);
    final lyrics = LyricService(apiHost);
    final accent = AccentService();
    final localLibrary = LocalLibraryService(prefs: prefs);
    final recent = RecentService(prefs: prefs);
    final updates = UpdateService(prefs: prefs);
    final player = PlayerService(
      host: apiHost,
      settings: settings,
      lyrics: lyrics,
      accent: accent,
      localLibrary: localLibrary,
      recent: recent,
    );
    return AppServices._(
      prefs: prefs,
      settings: settings,
      eq: eq,
      apiHost: apiHost,
      session: session,
      library: library,
      lyrics: lyrics,
      accent: accent,
      player: player,
      localLibrary: localLibrary,
      recent: recent,
      updates: updates,
    );
  }

  final SharedPreferences prefs;
  final SettingsService settings;
  final EqService eq;
  final ApiHost apiHost;
  final SessionService session;
  final LibraryService library;
  final LyricService lyrics;
  final AccentService accent;
  final PlayerService player;
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
      // Local stores first: restoring the queue may point at local
      // files.
      await Future.wait([localLibrary.init(), recent.init()]);
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
    eq.dispose();
    localLibrary.dispose();
    library.dispose();
    session.dispose();
    apiHost.dispose();
    settings.dispose();
  }
}

/// Process wide handle, assigned in `main()`.
late AppServices app;
