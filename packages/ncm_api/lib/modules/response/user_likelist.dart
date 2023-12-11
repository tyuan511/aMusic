import 'dart:convert';

class GetLikeListRes {
  final List<int> ids;
  final int checkPoint;
  final int code;

  GetLikeListRes({
    required this.ids,
    required this.checkPoint,
    required this.code,
  });

  GetLikeListRes copyWith({
    List<int>? ids,
    int? checkPoint,
    int? code,
  }) =>
      GetLikeListRes(
        ids: ids ?? this.ids,
        checkPoint: checkPoint ?? this.checkPoint,
        code: code ?? this.code,
      );

  factory GetLikeListRes.fromRawJson(String str) => GetLikeListRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory GetLikeListRes.fromJson(Map<String, dynamic> json) => GetLikeListRes(
        ids: List<int>.from(json["ids"].map((x) => x)),
        checkPoint: json["checkPoint"],
        code: json["code"],
      );

  Map<String, dynamic> toJson() => {
        "ids": List<dynamic>.from(ids.map((x) => x)),
        "checkPoint": checkPoint,
        "code": code,
      };
}
