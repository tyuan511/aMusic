import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LoginScreen extends StatelessWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            QrImageView(
              data: 'https://music.163.com/login?codekey=123123132131',
              version: QrVersions.auto,
              size: 240,
            ),
            const SizedBox(height: 8),
            Text("使用App扫码登录", style: Theme.of(context).textTheme.bodyLarge!)
          ],
        ),
      ),
    );
  }
}
