import 'dart:convert';

class LoginCreateQrRes {
  final int code;
  final Data data;

  LoginCreateQrRes({
    required this.code,
    required this.data,
  });

  LoginCreateQrRes copyWith({
    int? code,
    Data? data,
  }) =>
      LoginCreateQrRes(
        code: code ?? this.code,
        data: data ?? this.data,
      );

  factory LoginCreateQrRes.fromRawJson(String str) => LoginCreateQrRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LoginCreateQrRes.fromJson(Map<String, dynamic> json) => LoginCreateQrRes(
        code: json["code"],
        data: Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "data": data.toJson(),
      };
}

class Data {
  final String qrurl;
  final String qrimg;

  Data({
    required this.qrurl,
    required this.qrimg,
  });

  Data copyWith({
    String? qrurl,
    String? qrimg,
  }) =>
      Data(
        qrurl: qrurl ?? this.qrurl,
        qrimg: qrimg ?? this.qrimg,
      );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        qrurl: json["qrurl"],
        qrimg: json["qrimg"],
      );

  Map<String, dynamic> toJson() => {
        "qrurl": qrurl,
        "qrimg": qrimg,
      };
}
