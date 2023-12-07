import 'dart:convert';

class SongUrlRes {
  final int code;
  final List<Datum> data;

  SongUrlRes({
    required this.code,
    required this.data,
  });

  SongUrlRes copyWith({
    int? code,
    List<Datum>? data,
  }) =>
      SongUrlRes(
        code: code ?? this.code,
        data: data ?? this.data,
      );

  factory SongUrlRes.fromRawJson(String str) => SongUrlRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SongUrlRes.fromJson(Map<String, dynamic> json) => SongUrlRes(
        code: json["code"],
        data: List<Datum>.from(json["data"].map((x) => Datum.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "data": List<dynamic>.from(data.map((x) => x.toJson())),
      };
}

class Datum {
  final int id;
  final String url;
  final int br;
  final int size;
  final String md5;
  final int code;
  final int expi;
  final String type;
  final double gain;
  final int peak;
  final int fee;
  final dynamic uf;
  final int payed;
  final int flag;
  final bool canExtend;
  final dynamic freeTrialInfo;
  final String level;
  final String encodeType;
  final dynamic channelLayout;
  final FreeTrialPrivilege freeTrialPrivilege;
  final FreeTimeTrialPrivilege freeTimeTrialPrivilege;
  final int urlSource;
  final int rightSource;
  final dynamic podcastCtrp;
  final dynamic effectTypes;
  final int time;

  Datum({
    required this.id,
    required this.url,
    required this.br,
    required this.size,
    required this.md5,
    required this.code,
    required this.expi,
    required this.type,
    required this.gain,
    required this.peak,
    required this.fee,
    required this.uf,
    required this.payed,
    required this.flag,
    required this.canExtend,
    required this.freeTrialInfo,
    required this.level,
    required this.encodeType,
    required this.channelLayout,
    required this.freeTrialPrivilege,
    required this.freeTimeTrialPrivilege,
    required this.urlSource,
    required this.rightSource,
    required this.podcastCtrp,
    required this.effectTypes,
    required this.time,
  });

  Datum copyWith({
    int? id,
    String? url,
    int? br,
    int? size,
    String? md5,
    int? code,
    int? expi,
    String? type,
    double? gain,
    int? peak,
    int? fee,
    dynamic uf,
    int? payed,
    int? flag,
    bool? canExtend,
    dynamic freeTrialInfo,
    String? level,
    String? encodeType,
    dynamic channelLayout,
    FreeTrialPrivilege? freeTrialPrivilege,
    FreeTimeTrialPrivilege? freeTimeTrialPrivilege,
    int? urlSource,
    int? rightSource,
    dynamic podcastCtrp,
    dynamic effectTypes,
    int? time,
  }) =>
      Datum(
        id: id ?? this.id,
        url: url ?? this.url,
        br: br ?? this.br,
        size: size ?? this.size,
        md5: md5 ?? this.md5,
        code: code ?? this.code,
        expi: expi ?? this.expi,
        type: type ?? this.type,
        gain: gain ?? this.gain,
        peak: peak ?? this.peak,
        fee: fee ?? this.fee,
        uf: uf ?? this.uf,
        payed: payed ?? this.payed,
        flag: flag ?? this.flag,
        canExtend: canExtend ?? this.canExtend,
        freeTrialInfo: freeTrialInfo ?? this.freeTrialInfo,
        level: level ?? this.level,
        encodeType: encodeType ?? this.encodeType,
        channelLayout: channelLayout ?? this.channelLayout,
        freeTrialPrivilege: freeTrialPrivilege ?? this.freeTrialPrivilege,
        freeTimeTrialPrivilege: freeTimeTrialPrivilege ?? this.freeTimeTrialPrivilege,
        urlSource: urlSource ?? this.urlSource,
        rightSource: rightSource ?? this.rightSource,
        podcastCtrp: podcastCtrp ?? this.podcastCtrp,
        effectTypes: effectTypes ?? this.effectTypes,
        time: time ?? this.time,
      );

  factory Datum.fromRawJson(String str) => Datum.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Datum.fromJson(Map<String, dynamic> json) => Datum(
        id: json["id"],
        url: json["url"],
        br: json["br"],
        size: json["size"],
        md5: json["md5"],
        code: json["code"],
        expi: json["expi"],
        type: json["type"],
        gain: json["gain"]?.toDouble(),
        peak: json["peak"],
        fee: json["fee"],
        uf: json["uf"],
        payed: json["payed"],
        flag: json["flag"],
        canExtend: json["canExtend"],
        freeTrialInfo: json["freeTrialInfo"],
        level: json["level"],
        encodeType: json["encodeType"],
        channelLayout: json["channelLayout"],
        freeTrialPrivilege: FreeTrialPrivilege.fromJson(json["freeTrialPrivilege"]),
        freeTimeTrialPrivilege: FreeTimeTrialPrivilege.fromJson(json["freeTimeTrialPrivilege"]),
        urlSource: json["urlSource"],
        rightSource: json["rightSource"],
        podcastCtrp: json["podcastCtrp"],
        effectTypes: json["effectTypes"],
        time: json["time"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "url": url,
        "br": br,
        "size": size,
        "md5": md5,
        "code": code,
        "expi": expi,
        "type": type,
        "gain": gain,
        "peak": peak,
        "fee": fee,
        "uf": uf,
        "payed": payed,
        "flag": flag,
        "canExtend": canExtend,
        "freeTrialInfo": freeTrialInfo,
        "level": level,
        "encodeType": encodeType,
        "channelLayout": channelLayout,
        "freeTrialPrivilege": freeTrialPrivilege.toJson(),
        "freeTimeTrialPrivilege": freeTimeTrialPrivilege.toJson(),
        "urlSource": urlSource,
        "rightSource": rightSource,
        "podcastCtrp": podcastCtrp,
        "effectTypes": effectTypes,
        "time": time,
      };
}

class FreeTimeTrialPrivilege {
  final bool resConsumable;
  final bool userConsumable;
  final int type;
  final int remainTime;

  FreeTimeTrialPrivilege({
    required this.resConsumable,
    required this.userConsumable,
    required this.type,
    required this.remainTime,
  });

  FreeTimeTrialPrivilege copyWith({
    bool? resConsumable,
    bool? userConsumable,
    int? type,
    int? remainTime,
  }) =>
      FreeTimeTrialPrivilege(
        resConsumable: resConsumable ?? this.resConsumable,
        userConsumable: userConsumable ?? this.userConsumable,
        type: type ?? this.type,
        remainTime: remainTime ?? this.remainTime,
      );

  factory FreeTimeTrialPrivilege.fromRawJson(String str) => FreeTimeTrialPrivilege.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory FreeTimeTrialPrivilege.fromJson(Map<String, dynamic> json) => FreeTimeTrialPrivilege(
        resConsumable: json["resConsumable"],
        userConsumable: json["userConsumable"],
        type: json["type"],
        remainTime: json["remainTime"],
      );

  Map<String, dynamic> toJson() => {
        "resConsumable": resConsumable,
        "userConsumable": userConsumable,
        "type": type,
        "remainTime": remainTime,
      };
}

class FreeTrialPrivilege {
  final bool resConsumable;
  final bool userConsumable;
  final dynamic listenType;
  final dynamic cannotListenReason;
  final dynamic playReason;

  FreeTrialPrivilege({
    required this.resConsumable,
    required this.userConsumable,
    required this.listenType,
    required this.cannotListenReason,
    required this.playReason,
  });

  FreeTrialPrivilege copyWith({
    bool? resConsumable,
    bool? userConsumable,
    dynamic listenType,
    dynamic cannotListenReason,
    dynamic playReason,
  }) =>
      FreeTrialPrivilege(
        resConsumable: resConsumable ?? this.resConsumable,
        userConsumable: userConsumable ?? this.userConsumable,
        listenType: listenType ?? this.listenType,
        cannotListenReason: cannotListenReason ?? this.cannotListenReason,
        playReason: playReason ?? this.playReason,
      );

  factory FreeTrialPrivilege.fromRawJson(String str) => FreeTrialPrivilege.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory FreeTrialPrivilege.fromJson(Map<String, dynamic> json) => FreeTrialPrivilege(
        resConsumable: json["resConsumable"],
        userConsumable: json["userConsumable"],
        listenType: json["listenType"],
        cannotListenReason: json["cannotListenReason"],
        playReason: json["playReason"],
      );

  Map<String, dynamic> toJson() => {
        "resConsumable": resConsumable,
        "userConsumable": userConsumable,
        "listenType": listenType,
        "cannotListenReason": cannotListenReason,
        "playReason": playReason,
      };
}
