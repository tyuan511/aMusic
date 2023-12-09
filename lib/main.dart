import 'package:flutter/material.dart';
import 'package:laji_music/init.dart';
import 'package:laji_music/no_transition.dart';
import 'package:laji_music/router.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApi();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: '辣鸡音乐',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        pageTransitionsTheme: pageTransitionsTheme,
        useMaterial3: true,
      ),
      routerConfig: router,
    );
  }
}
