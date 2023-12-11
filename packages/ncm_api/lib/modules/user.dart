part of '../ncm_api.dart';

Future<LoginGetQrKeyRes> getLoginQRKey() async {
  final res = await request.get('/login/qr/key', params: {"timestamp": DateTime.now().millisecond});
  return LoginGetQrKeyRes.fromJson(res.data);
}

Future<LoginStatusResponse> checkLoginStatus() async {
  final res = await request.get('/login/status', params: {"timestamp": DateTime.now().millisecond});
  return LoginStatusResponse.fromJson(res.data);
}

Future<LoginCreateQrRes> createLoginQRCode(String key) async {
  final res = await request.get('/login/qr/create', params: {
    "timestamp": DateTime.now().millisecond,
    "key": key,
    "qrimage": true,
  });
  return LoginCreateQrRes.fromJson(res.data);
}

Future<LoginCheckQrRes> checkLoginQRCode(String key) async {
  final res = await request.get('/login/qr/check', params: {
    "timestamp": DateTime.now().millisecond,
    "key": key,
  });
  return LoginCheckQrRes.fromJson(res.data);
}

Future<GetLikeListRes> getLikeList(int uid) async {
  final res = await request.get('/likelist', params: {'uid': uid});
  return GetLikeListRes.fromJson(res.data);
}
