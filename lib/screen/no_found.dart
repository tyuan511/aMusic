import 'package:flutter/material.dart';

class NoFoundScreen extends StatelessWidget {
  const NoFoundScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Text('NoFound'),
      ),
    );
  }
}
