import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:amusic/init.dart';
import 'package:amusic/providers/config.dart';
import 'package:amusic/providers/router.dart';
import 'package:amusic/theme.dart';
import 'package:amusic/utils/repo.dart';
import 'package:amusic/utils/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);

  await Future.wait([initAudio(), initApi(), initStorage()]);
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final config = ref.watch(configProvider);
    final themeMode = ref.watch(configProvider.select((data) => data.themeMode));

    useEffect(() {
      if (config.fullscreen) {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
      } else {
        SystemChrome.setEnabledSystemUIMode(SystemUiMode.manual,
            overlays: [SystemUiOverlay.top, SystemUiOverlay.bottom]);
      }

      return null;
    }, []);

    return MaterialApp.router(
      title: 'aMusic',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: theme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
