import 'dart:convert';

class SongUrlRes {
  final List<Datum>? data;
  final int? code;

  SongUrlRes({
    this.data,
    this.code,
  });

  SongUrlRes copyWith({
    List<Datum>? data,
    int? code,
  }) =>
      SongUrlRes(
        data: data ?? this.data,
        code: code ?? this.code,
      );

  factory SongUrlRes.fromRawJson(String str) => SongUrlRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SongUrlRes.fromJson(Map<String, dynamic> json) => SongUrlRes(
        data: json["data"] == null ? [] : List<Datum>.from(json["data"]!.map((x) => Datum.fromJson(x))),
        code: json["code"],
      );

  Map<String, dynamic> toJson() => {
        "data": data == null ? [] : List<dynamic>.from(data!.map((x) => x.toJson())),
        "code": code,
      };
}

class Datum {
  final int? id;
  final String? url;
  final int? br;
  final int? size;
  final String? md5;
  final int? code;
  final int? expi;
  final String? type;
  final double? gain;
  final double? peak;
  final int? fee;
  final dynamic uf;
  final int? payed;
  final int? flag;
  final bool? canExtend;
  final dynamic freeTrialInfo;
  final String? level;
  final String? encodeType;
  final dynamic channelLayout;
  final FreeTrialPrivilege? freeTrialPrivilege;
  final FreeTimeTrialPrivilege? freeTimeTrialPrivilege;
  final int? urlSource;
  final int? rightSource;
  final dynamic podcastCtrp;
  final dynamic effectTypes;
  final int? time;

  Datum({
    this.id,
    this.url,
    this.br,
    this.size,
    this.md5,
    this.code,
    this.expi,
    this.type,
    this.gain,
    this.peak,
    this.fee,
    this.uf,
    this.payed,
    this.flag,
    this.canExtend,
    this.freeTrialInfo,
    this.level,
    this.encodeType,
    this.channelLayout,
    this.freeTrialPrivilege,
    this.freeTimeTrialPrivilege,
    this.urlSource,
    this.rightSource,
    this.podcastCtrp,
    this.effectTypes,
    this.time,
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
    double? peak,
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
        peak: json["peak"]?.toDouble(),
        fee: json["fee"],
        uf: json["uf"],
        payed: json["payed"],
        flag: json["flag"],
        canExtend: json["canExtend"],
        freeTrialInfo: json["freeTrialInfo"],
        level: json["level"],
        encodeType: json["encodeType"],
        channelLayout: json["channelLayout"],
        freeTrialPrivilege:
            json["freeTrialPrivilege"] == null ? null : FreeTrialPrivilege.fromJson(json["freeTrialPrivilege"]),
        freeTimeTrialPrivilege: json["freeTimeTrialPrivilege"] == null
            ? null
            : FreeTimeTrialPrivilege.fromJson(json["freeTimeTrialPrivilege"]),
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
        "freeTrialPrivilege": freeTrialPrivilege?.toJson(),
        "freeTimeTrialPrivilege": freeTimeTrialPrivilege?.toJson(),
        "urlSource": urlSource,
        "rightSource": rightSource,
        "podcastCtrp": podcastCtrp,
        "effectTypes": effectTypes,
        "time": time,
      };
}

class FreeTimeTrialPrivilege {
  final bool? resConsumable;
  final bool? userConsumable;
  final int? type;
  final int? remainTime;

  FreeTimeTrialPrivilege({
    this.resConsumable,
    this.userConsumable,
    this.type,
    this.remainTime,
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
  final bool? resConsumable;
  final bool? userConsumable;
  final dynamic listenType;
  final dynamic cannotListenReason;
  final dynamic playReason;

  FreeTrialPrivilege({
    this.resConsumable,
    this.userConsumable,
    this.listenType,
    this.cannotListenReason,
    this.playReason,
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
