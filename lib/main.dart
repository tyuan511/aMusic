import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_hooks/flutter_hooks.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/init.dart';
import 'package:laji_music/providers/config.dart';
import 'package:laji_music/providers/router.dart';
import 'package:laji_music/theme.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:laji_music/utils/storage.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setPreferredOrientations([DeviceOrientation.landscapeLeft, DeviceOrientation.landscapeRight]);
  await dotenv.load();
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
      title: '辣鸡音乐',
      debugShowCheckedModeBanner: false,
      themeMode: themeMode,
      theme: theme,
      darkTheme: darkTheme,
      routerConfig: router,
    );
  }
}
