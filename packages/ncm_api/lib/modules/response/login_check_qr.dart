import 'dart:convert';

class LoginCheckQrRes {
  final String? nickname;
  final String? avatarUrl;
  final int code;
  final String message;
  final String cookie;

  LoginCheckQrRes({
    required this.nickname,
    required this.avatarUrl,
    required this.code,
    required this.message,
    required this.cookie,
  });

  LoginCheckQrRes copyWith({
    String? nickname,
    String? avatarUrl,
    int? code,
    String? message,
    String? cookie,
  }) =>
      LoginCheckQrRes(
        nickname: nickname ?? this.nickname,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        code: code ?? this.code,
        message: message ?? this.message,
        cookie: cookie ?? this.cookie,
      );

  factory LoginCheckQrRes.fromRawJson(String str) => LoginCheckQrRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LoginCheckQrRes.fromJson(Map<String, dynamic> json) => LoginCheckQrRes(
        nickname: json["nickname"],
        avatarUrl: json["avatarUrl"],
        code: json["code"],
        message: json["message"],
        cookie: json["cookie"],
      );

  Map<String, dynamic> toJson() => {
        "nickname": nickname,
        "avatarUrl": avatarUrl,
        "code": code,
        "message": message,
        "cookie": cookie,
      };
}
