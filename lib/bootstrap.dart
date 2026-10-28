import 'dart:async';

import 'package:amusic_engine/amusic_engine.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';

/// Registers the right audio backend and prepares the desktop window.
///
/// Must run before any `AudioPlayer` is created.
Future<void> initPlatform() async {
  // Every platform plays through aMusic's own Rust engine, so decoding, the
  // equalizer and the limiter behave identically everywhere.
  AmusicJustAudio.ensureInitialized();

  // Android / iOS: notification + lock screen. macOS: Now Playing widget
  // and media keys through MPNowPlayingInfoCenter. Windows / Linux have
  // no just_audio_background backend; media keys there are handled by the
  // in-app shortcuts only.
  if (Platforms.supportsAudioService) {
    await _initBackground();
  }

  if (Platforms.isDesktop) {
    await windowManager.ensureInitialized();
    final options = WindowOptions(
      size: const Size(1240, 820),
      minimumSize: const Size(420, 620),
      center: true,
      title: AppConfig.appName,
      // macOS: no title bar; the traffic lights float over the sidebar.
      titleBarStyle: Platforms.isMacOS
          ? TitleBarStyle.hidden
          : TitleBarStyle.normal,
      windowButtonVisibility: true,
    );
    // Not awaited: the callback fires when the native window is ready, and
    // awaiting it here would delay (or block) the first Flutter frame.
    unawaited(
      windowManager.waitUntilReadyToShow(options, () async {
        await windowManager.setMinimumSize(options.minimumSize!);
        await windowManager.center();
        await windowManager.show();
        await windowManager.focus();
      }),
    );
  }

  if (Platforms.isMobile) {
    await SystemChrome.setPreferredOrientations([
      DeviceOrientation.portraitUp,
      DeviceOrientation.portraitDown,
      DeviceOrientation.landscapeLeft,
      DeviceOrientation.landscapeRight,
    ]);
  }
}

/// Whether [JustAudioBackground] is active; sources must then carry a
/// `MediaItem` tag (they always do, see `mediaItemFor`).
bool backgroundAudioEnabled = false;

Future<void> _initBackground() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.tangge.amusic.playback',
      androidNotificationChannelName: '音频播放',
      androidNotificationChannelDescription: '正在播放的歌曲',
      androidNotificationOngoing: true,
      androidStopForegroundOnPause: true,
      androidResumeOnClick: true,
      androidNotificationIcon: 'mipmap/ic_launcher',
      notificationColor: const Color(0xFFFF4B45),
    );
    backgroundAudioEnabled = true;
  } on Object catch (error) {
    // Plain just_audio keeps working without the system media session.
    debugPrint('just_audio_background unavailable: $error');
  }
}

/// Applies the "immersive" setting on phones/tablets.
void applySystemUiMode(bool immersive) {
  if (!Platforms.supportsImmersive) return;
  if (immersive) {
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
  } else {
    SystemChrome.setEnabledSystemUIMode(
      SystemUiMode.manual,
      overlays: SystemUiOverlay.values,
    );
  }
}
