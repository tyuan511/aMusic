import 'package:flutter/material.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/init.dart';
import 'package:laji_music/providers/config.dart';
import 'package:laji_music/providers/router.dart';
import 'package:laji_music/theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApi();
  runApp(const ProviderScope(child: MyApp()));
}

class MyApp extends HookConsumerWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final router = ref.watch(routerProvider);
    final themeMode = ref.watch(configProvider.select((data) => data.themeMode));

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
