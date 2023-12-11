import 'dart:io';

import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'package:ncm_api/ncm_api.dart' as api;
import 'package:path_provider/path_provider.dart';

Future<void> initApi() async {
  final Directory appDocDir = await getApplicationDocumentsDirectory();
  final String appDocPath = appDocDir.path;
  await api.init(cookiePath: "$appDocPath/.cookies/", serverURL: dotenv.env['SERVER_URL']!);
}

Future<void> initAudio() async {
  await JustAudioBackground.init(
    androidNotificationChannelId: 'com.ryanheise.bg_demo.channel.audio',
    androidNotificationChannelName: 'Audio playback',
    androidNotificationOngoing: true,
  );
}
