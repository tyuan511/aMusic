import 'dart:io';

/// Compile time / runtime constants shared by the whole app.
class AppConfig {
  AppConfig._();

  static const String appName = 'aMusic';

  /// Base URL of the NeteaseCloudMusicApiEnhanced server.
  ///
  /// Can be baked in at build time with
  /// `flutter run --dart-define=NCM_SERVER_URL=https://api.example.com`
  /// and changed later from the settings screen.
  static const String defaultServerUrl = String.fromEnvironment(
    'NCM_SERVER_URL',
    defaultValue: 'http://127.0.0.1:3008',
  );

  /// Some endpoints reject requests that do not look like a browser.
  static const String userAgent =
      'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 '
      '(KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36';
}

/// Platform helpers. The app never targets the web, so `dart:io` is safe here.
class Platforms {
  Platforms._();

  static bool get isAndroid => Platform.isAndroid;
  static bool get isIOS => Platform.isIOS;
  static bool get isMacOS => Platform.isMacOS;
  static bool get isWindows => Platform.isWindows;
  static bool get isLinux => Platform.isLinux;

  static bool get isDesktop => isMacOS || isWindows || isLinux;
  static bool get isMobile => isAndroid || isIOS;

  /// Platforms where `just_audio_background` (media notification / lock screen /
  /// media keys) is available.
  static bool get supportsAudioService => isAndroid || isIOS || isMacOS;

  /// Immersive fullscreen only makes sense on phones and tablets.
  static bool get supportsImmersive => isAndroid || isIOS;
}

/// Layout breakpoints.
class Breakpoints {
  Breakpoints._();

  /// Below this width the app renders the compact (phone) layout.
  static const double compact = 720;

  /// Below this width the sidebar collapses to icons only.
  static const double medium = 1080;

  /// Above this width extra columns (album name, ...) are shown in song rows.
  static const double expanded = 1400;
}
