import 'dart:async';

import 'package:flutter/material.dart';

import 'app.dart';
import 'bootstrap.dart';
import 'services/app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initPlatform();
  } on Object catch (error) {
    // A broken window/audio setup must not stop the app from starting.
    debugPrint('platform init failed: $error');
  }

  app = await AppServices.bootstrap();
  // Initialising cpal can synchronously query the macOS audio device. Do it
  // before the window is interactive so the first play tap stays responsive.
  try {
    app.player.prepare();
  } on Object catch (error) {
    debugPrint('audio player prepare failed: $error');
  }
  runApp(const AmusicApp());

  // Restoring the session and the playback queue touches the network, so it
  // happens after the first frame instead of delaying startup.
  unawaited(app.warmUp());
}
