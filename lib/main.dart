import 'package:flutter/material.dart';
import 'package:laji_music/init.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initApi();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.deepPurple),
        useMaterial3: true,
      ),
      home: const Main(),
    );
  }
}

class Main extends StatelessWidget {
  const Main({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('NCM API'),
      ),
      body: Center(child: ElevatedButton(onPressed: () async {}, child: const Text('Click'))),
    );
  }
}
