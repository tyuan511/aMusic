import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import 'bootstrap.dart';
import 'core/config.dart';
import 'router.dart';
import 'services/app.dart';
import 'theme/app_theme.dart';
import 'ui/settings/update_dialog.dart';
import 'ui/ui_scale.dart';

final GlobalKey<ScaffoldMessengerState> messengerKey =
    GlobalKey<ScaffoldMessengerState>();

class AmusicApp extends StatefulWidget {
  const AmusicApp({super.key});

  @override
  State<AmusicApp> createState() => _AmusicAppState();
}

class _AmusicAppState extends State<AmusicApp> with WidgetsBindingObserver {
  late final GoRouter _router = createRouter();
  late final ThemeData _light = AppTheme.build(Brightness.light);
  late final ThemeData _dark = AppTheme.build(Brightness.dark);

  String? _lastError;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    applySystemUiMode(app.settings.value.immersive);
    app.settings.addListener(_onSettingsChanged);
    app.player.playback.addListener(_onPlaybackChanged);
    app.updates.available.addListener(_onUpdateAvailable);
  }

  /// A background check found a newer release: offer it once via a snackbar
  /// action instead of interrupting with a dialog.
  void _onUpdateAvailable() {
    final release = app.updates.available.value;
    if (release == null) return;
    messengerKey.currentState?.showSnackBar(
      SnackBar(
        content: Text('发现新版本 ${release.version}'),
        duration: const Duration(seconds: 8),
        width: Platforms.isDesktop ? 420 : null,
        action: SnackBarAction(
          label: '查看',
          onPressed: () {
            final context = rootNavigatorKey.currentContext;
            if (context != null) showUpdateDialog(context, release);
          },
        ),
      ),
    );
  }

  void _onSettingsChanged() => applySystemUiMode(app.settings.value.immersive);

  /// Player failures are transient and have no owning screen, so they surface as
  /// a global snackbar.
  void _onPlaybackChanged() {
    final error = app.player.playback.value.error;
    if (error == null || error == _lastError) return;
    _lastError = error;
    messengerKey.currentState
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(error),
          duration: const Duration(seconds: 3),
          width: Platforms.isDesktop ? 420 : null,
        ),
      );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.hidden) {
      app.onAppPaused();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    app.settings.removeListener(_onSettingsChanged);
    app.player.playback.removeListener(_onPlaybackChanged);
    app.updates.available.removeListener(_onUpdateAvailable);
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder(
      valueListenable: app.settings,
      builder: (context, settings, _) {
        return MaterialApp.router(
          title: AppConfig.appName,
          debugShowCheckedModeBanner: false,
          scaffoldMessengerKey: messengerKey,
          theme: _light,
          darkTheme: _dark,
          themeMode: settings.themeMode,
          routerConfig: _router,
          builder: (context, child) => UiScale(
            settings: settings,
            child: child ?? const SizedBox.shrink(),
          ),
        );
      },
    );
  }
}
