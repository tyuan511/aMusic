import 'dart:async';

import 'package:flutter/material.dart';
import 'ffi.dart' if (dart.library.html) 'ffi_web.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({Key? key}) : super(key: key);

  // This widget is the root of your application.
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Flutter Demo',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: const MyHomePage(title: 'Flutter Demo Home Page'),
    );
  }
}

class MyHomePage extends StatefulWidget {
  const MyHomePage({Key? key, required this.title}) : super(key: key);

  final String title;

  @override
  State<MyHomePage> createState() => _MyHomePageState();
}

extension<L, R> on (FutureOr<L>, FutureOr<R>) {
  // A convenience method enabled by Dart 3, which will be useful later.
  Future<(L, R)> join() async {
    final fut =
        await Future.wait([Future.value(this.$1), Future.value(this.$2)]);
    return (fut[0] as L, fut[1] as R);
  }
}

class _MyHomePageState extends State<MyHomePage> {
  // These futures belong to the state and are only initialized once,
  // in the initState method.
  late Future<Platform> platform;
  late Future<bool> isRelease;

  @override
  void initState() {
    super.initState();
    platform = api.platform();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            const Text("You're running on"),
            FutureBuilder(
              future: platform,
              builder: (context, snap) {
                final style = Theme.of(context).textTheme.headlineMedium;
                if (snap.error != null) {
                  debugPrint(snap.error.toString());
                  return Tooltip(
                    message: snap.error.toString(),
                    child: Text('Unknown OS', style: style),
                  );
                }

                final data = snap.data;
                if (data == null) return const CircularProgressIndicator();

                final text = data.when(
                  android: () => 'Android',
                  ios: () => 'iOS',
                  macOs: (arch) => 'MacOS on $arch',
                  windows: () => 'Windows',
                  unix: () => 'Unix',
                  wasm: () => 'the Web',
                  unknown: () => 'Unknown OS',
                );

                return Text(text, style: style);
              },
            )
          ],
        ),
      ),
    );
  }
}
