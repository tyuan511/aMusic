import 'dart:convert';

class SongLyricRes {
  final bool sgc;
  final bool sfy;
  final bool qfy;
  final Klyric lrc;
  final Klyric klyric;
  final Klyric tlyric;
  final Klyric romalrc;
  final int code;

  SongLyricRes({
    required this.sgc,
    required this.sfy,
    required this.qfy,
    required this.lrc,
    required this.klyric,
    required this.tlyric,
    required this.romalrc,
    required this.code,
  });

  SongLyricRes copyWith({
    bool? sgc,
    bool? sfy,
    bool? qfy,
    Klyric? lrc,
    Klyric? klyric,
    Klyric? tlyric,
    Klyric? romalrc,
    int? code,
  }) =>
      SongLyricRes(
        sgc: sgc ?? this.sgc,
        sfy: sfy ?? this.sfy,
        qfy: qfy ?? this.qfy,
        lrc: lrc ?? this.lrc,
        klyric: klyric ?? this.klyric,
        tlyric: tlyric ?? this.tlyric,
        romalrc: romalrc ?? this.romalrc,
        code: code ?? this.code,
      );

  factory SongLyricRes.fromRawJson(String str) => SongLyricRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SongLyricRes.fromJson(Map<String, dynamic> json) => SongLyricRes(
        sgc: json["sgc"],
        sfy: json["sfy"],
        qfy: json["qfy"],
        lrc: Klyric.fromJson(json["lrc"]),
        klyric: Klyric.fromJson(json["klyric"]),
        tlyric: Klyric.fromJson(json["tlyric"]),
        romalrc: Klyric.fromJson(json["romalrc"]),
        code: json["code"],
      );

  Map<String, dynamic> toJson() => {
        "sgc": sgc,
        "sfy": sfy,
        "qfy": qfy,
        "lrc": lrc.toJson(),
        "klyric": klyric.toJson(),
        "tlyric": tlyric.toJson(),
        "romalrc": romalrc.toJson(),
        "code": code,
      };
}

class Klyric {
  final int version;
  final String lyric;

  Klyric({
    required this.version,
    required this.lyric,
  });

  Klyric copyWith({
    int? version,
    String? lyric,
  }) =>
      Klyric(
        version: version ?? this.version,
        lyric: lyric ?? this.lyric,
      );

  factory Klyric.fromRawJson(String str) => Klyric.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Klyric.fromJson(Map<String, dynamic> json) => Klyric(
        version: json["version"],
        lyric: json["lyric"],
      );

  Map<String, dynamic> toJson() => {
        "version": version,
        "lyric": lyric,
      };
}
