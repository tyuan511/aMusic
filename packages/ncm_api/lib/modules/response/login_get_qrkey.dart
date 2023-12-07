import 'dart:convert';

class LoginGetQrKeyRes {
  final Data data;
  final int code;

  LoginGetQrKeyRes({
    required this.data,
    required this.code,
  });

  LoginGetQrKeyRes copyWith({
    Data? data,
    int? code,
  }) =>
      LoginGetQrKeyRes(
        data: data ?? this.data,
        code: code ?? this.code,
      );

  factory LoginGetQrKeyRes.fromRawJson(String str) => LoginGetQrKeyRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LoginGetQrKeyRes.fromJson(Map<String, dynamic> json) => LoginGetQrKeyRes(
        data: Data.fromJson(json["data"]),
        code: json["code"],
      );

  Map<String, dynamic> toJson() => {
        "data": data.toJson(),
        "code": code,
      };
}

class Data {
  final int code;
  final String unikey;

  Data({
    required this.code,
    required this.unikey,
  });

  Data copyWith({
    int? code,
    String? unikey,
  }) =>
      Data(
        code: code ?? this.code,
        unikey: unikey ?? this.unikey,
      );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        code: json["code"],
        unikey: json["unikey"],
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "unikey": unikey,
      };
}
