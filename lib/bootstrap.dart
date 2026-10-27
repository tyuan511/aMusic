import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:just_audio_media_kit/just_audio_media_kit.dart';
import 'package:window_manager/window_manager.dart';

import 'core/config.dart';

/// Registers the right audio backend and prepares the desktop window.
///
/// Must run before any `AudioPlayer` is created.
Future<void> initPlatform() async {
  if (Platforms.isWindows || Platforms.isLinux) {
    JustAudioMediaKit.ensureInitialized(windows: true, linux: true);
  }

  // Android / iOS: notification + lock screen. macOS: Now Playing widget
  // and media keys through MPNowPlayingInfoCenter. Windows / Linux go
  // through media_kit, which has no just_audio_background backend; media
  // keys there are handled by the in-app shortcuts only.
  if (Platforms.supportsAudioService) {
    await _initBackground();
  }

  if (Platforms.isDesktop) {
    await windowManager.ensureInitialized();
    const options = WindowOptions(
      size: Size(1240, 820),
      minimumSize: Size(420, 620),
      center: true,
      title: AppConfig.appName,
      titleBarStyle: TitleBarStyle.normal,
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
      notificationColor: const Color(0xFFC8F04A),
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
