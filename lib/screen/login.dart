import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:hooks_riverpod/hooks_riverpod.dart';
import 'package:laji_music/providers/user.dart';
import 'package:laji_music/utils/repo.dart';
import 'package:qr_flutter/qr_flutter.dart';

class LoginScreen extends StatefulHookConsumerWidget {
  const LoginScreen({Key? key}) : super(key: key);

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

enum QRState {
  invalid,
  expired,
  waiting,
  confirming,
  success;

  static QRState fromValue(int v) {
    switch (v) {
      case 800:
        return QRState.expired;
      case 801:
        return QRState.waiting;
      case 802:
        return QRState.confirming;
      case 803:
        return QRState.success;
      default:
        return QRState.invalid;
    }
  }
}

class _LoginScreenState extends ConsumerState<LoginScreen> {
  String? qrKey;
  QRState qrState = QRState.waiting;

  @override
  void initState() {
    super.initState();
    createQR();
  }

  get qrURL => qrKey == null ? null : 'https://music.163.com/login?codekey=$qrKey';

  createQR() async {
    final res = await (await repo.loginQrKey()).asFuture;
    setState(() {
      qrKey = res['unikey'];
    });
    checkQRStete();
  }

  checkQRStete() async {
    if (qrKey == null) return;
    final res = await repo.loginQrCheck(qrKey!);

    setState(() {
      qrState = QRState.fromValue(res);
    });

    if (qrState == QRState.waiting || qrState == QRState.confirming) {
      await Future.delayed(const Duration(seconds: 2));
      checkQRStete();
      return;
    }

    if (qrState == QRState.expired) {
      createQR();
      return;
    }

    if (qrState == QRState.success) {
      await ref.read(userProvider.notifier).getInfo();
      if (mounted) {
        context.go('/user_playlist');
      }
      return;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Theme.of(context).colorScheme.primary,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            qrURL != null
                ? QrImageView(
                    data: qrURL,
                    version: QrVersions.auto,
                    size: 300,
                    backgroundColor: Colors.white,
                  )
                : Container(
                    width: 300,
                    height: 300,
                    color: Colors.white,
                    child: SizedBox(
                      width: 32,
                      height: 32,
                      child: Center(
                        child: CircularProgressIndicator(
                          color: Theme.of(context).colorScheme.primary,
                        ),
                      ),
                    ),
                  ),
            const SizedBox(height: 16),
            Text(qrState == QRState.confirming ? '等待确认中' : '请使用App扫码登录',
                style:
                    Theme.of(context).textTheme.titleLarge!.copyWith(color: Theme.of(context).colorScheme.onPrimary)),
          ],
        ),
      ),
    );
  }
}
