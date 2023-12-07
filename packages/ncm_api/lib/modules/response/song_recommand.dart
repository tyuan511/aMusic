import 'dart:convert';

class SongRecommandRes {
  final int code;
  final Data data;

  SongRecommandRes({
    required this.code,
    required this.data,
  });

  SongRecommandRes copyWith({
    int? code,
    Data? data,
  }) =>
      SongRecommandRes(
        code: code ?? this.code,
        data: data ?? this.data,
      );

  factory SongRecommandRes.fromRawJson(String str) => SongRecommandRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory SongRecommandRes.fromJson(Map<String, dynamic> json) => SongRecommandRes(
        code: json["code"],
        data: Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "data": data.toJson(),
      };
}

class Data {
  final List<DailySong> dailySongs;
  final List<dynamic> orderSongs;
  final List<RecommendReason> recommendReasons;
  final dynamic mvResourceInfos;

  Data({
    required this.dailySongs,
    required this.orderSongs,
    required this.recommendReasons,
    required this.mvResourceInfos,
  });

  Data copyWith({
    List<DailySong>? dailySongs,
    List<dynamic>? orderSongs,
    List<RecommendReason>? recommendReasons,
    dynamic mvResourceInfos,
  }) =>
      Data(
        dailySongs: dailySongs ?? this.dailySongs,
        orderSongs: orderSongs ?? this.orderSongs,
        recommendReasons: recommendReasons ?? this.recommendReasons,
        mvResourceInfos: mvResourceInfos ?? this.mvResourceInfos,
      );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        dailySongs: List<DailySong>.from(json["dailySongs"].map((x) => DailySong.fromJson(x))),
        orderSongs: List<dynamic>.from(json["orderSongs"].map((x) => x)),
        recommendReasons: List<RecommendReason>.from(json["recommendReasons"].map((x) => RecommendReason.fromJson(x))),
        mvResourceInfos: json["mvResourceInfos"],
      );

  Map<String, dynamic> toJson() => {
        "dailySongs": List<dynamic>.from(dailySongs.map((x) => x.toJson())),
        "orderSongs": List<dynamic>.from(orderSongs.map((x) => x)),
        "recommendReasons": List<dynamic>.from(recommendReasons.map((x) => x.toJson())),
        "mvResourceInfos": mvResourceInfos,
      };
}

class DailySong {
  final String name;
  final int id;
  final int pst;
  final int t;
  final List<Ar> ar;
  final List<String> alia;
  final int pop;
  final int st;
  final Rt? rt;
  final int fee;
  final int v;
  final dynamic crbt;
  final String cf;
  final Al al;
  final int dt;
  final L? h;
  final L m;
  final L l;
  final L? sq;
  final L? hr;
  final dynamic a;
  final String cd;
  final int no;
  final dynamic rtUrl;
  final int ftype;
  final List<dynamic> rtUrls;
  final int djId;
  final int copyright;
  final int sId;
  final int mark;
  final int originCoverType;
  final OriginSongSimpleData? originSongSimpleData;
  final dynamic tagPicList;
  final bool resourceState;
  final int version;
  final dynamic songJumpInfo;
  final dynamic entertainmentTags;
  final int single;
  final dynamic noCopyrightRcmd;
  final int rtype;
  final dynamic rurl;
  final int mst;
  final int cp;
  final int mv;
  final int publishTime;
  final String? reason;
  final String? recommendReason;
  final Privilege privilege;
  final Alg alg;
  final String? sCtrp;

  DailySong({
    required this.name,
    required this.id,
    required this.pst,
    required this.t,
    required this.ar,
    required this.alia,
    required this.pop,
    required this.st,
    required this.rt,
    required this.fee,
    required this.v,
    required this.crbt,
    required this.cf,
    required this.al,
    required this.dt,
    required this.h,
    required this.m,
    required this.l,
    required this.sq,
    required this.hr,
    required this.a,
    required this.cd,
    required this.no,
    required this.rtUrl,
    required this.ftype,
    required this.rtUrls,
    required this.djId,
    required this.copyright,
    required this.sId,
    required this.mark,
    required this.originCoverType,
    required this.originSongSimpleData,
    required this.tagPicList,
    required this.resourceState,
    required this.version,
    required this.songJumpInfo,
    required this.entertainmentTags,
    required this.single,
    required this.noCopyrightRcmd,
    required this.rtype,
    required this.rurl,
    required this.mst,
    required this.cp,
    required this.mv,
    required this.publishTime,
    required this.reason,
    required this.recommendReason,
    required this.privilege,
    required this.alg,
    this.sCtrp,
  });

  DailySong copyWith({
    String? name,
    int? id,
    int? pst,
    int? t,
    List<Ar>? ar,
    List<String>? alia,
    int? pop,
    int? st,
    Rt? rt,
    int? fee,
    int? v,
    dynamic crbt,
    String? cf,
    Al? al,
    int? dt,
    L? h,
    L? m,
    L? l,
    L? sq,
    L? hr,
    dynamic a,
    String? cd,
    int? no,
    dynamic rtUrl,
    int? ftype,
    List<dynamic>? rtUrls,
    int? djId,
    int? copyright,
    int? sId,
    int? mark,
    int? originCoverType,
    OriginSongSimpleData? originSongSimpleData,
    dynamic tagPicList,
    bool? resourceState,
    int? version,
    dynamic songJumpInfo,
    dynamic entertainmentTags,
    int? single,
    dynamic noCopyrightRcmd,
    int? rtype,
    dynamic rurl,
    int? mst,
    int? cp,
    int? mv,
    int? publishTime,
    String? reason,
    String? recommendReason,
    Privilege? privilege,
    Alg? alg,
    String? sCtrp,
  }) =>
      DailySong(
        name: name ?? this.name,
        id: id ?? this.id,
        pst: pst ?? this.pst,
        t: t ?? this.t,
        ar: ar ?? this.ar,
        alia: alia ?? this.alia,
        pop: pop ?? this.pop,
        st: st ?? this.st,
        rt: rt ?? this.rt,
        fee: fee ?? this.fee,
        v: v ?? this.v,
        crbt: crbt ?? this.crbt,
        cf: cf ?? this.cf,
        al: al ?? this.al,
        dt: dt ?? this.dt,
        h: h ?? this.h,
        m: m ?? this.m,
        l: l ?? this.l,
        sq: sq ?? this.sq,
        hr: hr ?? this.hr,
        a: a ?? this.a,
        cd: cd ?? this.cd,
        no: no ?? this.no,
        rtUrl: rtUrl ?? this.rtUrl,
        ftype: ftype ?? this.ftype,
        rtUrls: rtUrls ?? this.rtUrls,
        djId: djId ?? this.djId,
        copyright: copyright ?? this.copyright,
        sId: sId ?? this.sId,
        mark: mark ?? this.mark,
        originCoverType: originCoverType ?? this.originCoverType,
        originSongSimpleData: originSongSimpleData ?? this.originSongSimpleData,
        tagPicList: tagPicList ?? this.tagPicList,
        resourceState: resourceState ?? this.resourceState,
        version: version ?? this.version,
        songJumpInfo: songJumpInfo ?? this.songJumpInfo,
        entertainmentTags: entertainmentTags ?? this.entertainmentTags,
        single: single ?? this.single,
        noCopyrightRcmd: noCopyrightRcmd ?? this.noCopyrightRcmd,
        rtype: rtype ?? this.rtype,
        rurl: rurl ?? this.rurl,
        mst: mst ?? this.mst,
        cp: cp ?? this.cp,
        mv: mv ?? this.mv,
        publishTime: publishTime ?? this.publishTime,
        reason: reason ?? this.reason,
        recommendReason: recommendReason ?? this.recommendReason,
        privilege: privilege ?? this.privilege,
        alg: alg ?? this.alg,
        sCtrp: sCtrp ?? this.sCtrp,
      );

  factory DailySong.fromRawJson(String str) => DailySong.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory DailySong.fromJson(Map<String, dynamic> json) => DailySong(
        name: json["name"],
        id: json["id"],
        pst: json["pst"],
        t: json["t"],
        ar: List<Ar>.from(json["ar"].map((x) => Ar.fromJson(x))),
        alia: List<String>.from(json["alia"].map((x) => x)),
        pop: json["pop"],
        st: json["st"],
        rt: rtValues.map[json["rt"]]!,
        fee: json["fee"],
        v: json["v"],
        crbt: json["crbt"],
        cf: json["cf"],
        al: Al.fromJson(json["al"]),
        dt: json["dt"],
        h: json["h"] == null ? null : L.fromJson(json["h"]),
        m: L.fromJson(json["m"]),
        l: L.fromJson(json["l"]),
        sq: json["sq"] == null ? null : L.fromJson(json["sq"]),
        hr: json["hr"] == null ? null : L.fromJson(json["hr"]),
        a: json["a"],
        cd: json["cd"],
        no: json["no"],
        rtUrl: json["rtUrl"],
        ftype: json["ftype"],
        rtUrls: List<dynamic>.from(json["rtUrls"].map((x) => x)),
        djId: json["djId"],
        copyright: json["copyright"],
        sId: json["s_id"],
        mark: json["mark"],
        originCoverType: json["originCoverType"],
        originSongSimpleData:
            json["originSongSimpleData"] == null ? null : OriginSongSimpleData.fromJson(json["originSongSimpleData"]),
        tagPicList: json["tagPicList"],
        resourceState: json["resourceState"],
        version: json["version"],
        songJumpInfo: json["songJumpInfo"],
        entertainmentTags: json["entertainmentTags"],
        single: json["single"],
        noCopyrightRcmd: json["noCopyrightRcmd"],
        rtype: json["rtype"],
        rurl: json["rurl"],
        mst: json["mst"],
        cp: json["cp"],
        mv: json["mv"],
        publishTime: json["publishTime"],
        reason: json["reason"],
        recommendReason: json["recommendReason"],
        privilege: Privilege.fromJson(json["privilege"]),
        alg: algValues.map[json["alg"]]!,
        sCtrp: json["s_ctrp"],
      );

  Map<String, dynamic> toJson() => {
        "name": name,
        "id": id,
        "pst": pst,
        "t": t,
        "ar": List<dynamic>.from(ar.map((x) => x.toJson())),
        "alia": List<dynamic>.from(alia.map((x) => x)),
        "pop": pop,
        "st": st,
        "rt": rtValues.reverse[rt],
        "fee": fee,
        "v": v,
        "crbt": crbt,
        "cf": cf,
        "al": al.toJson(),
        "dt": dt,
        "h": h?.toJson(),
        "m": m.toJson(),
        "l": l.toJson(),
        "sq": sq?.toJson(),
        "hr": hr?.toJson(),
        "a": a,
        "cd": cd,
        "no": no,
        "rtUrl": rtUrl,
        "ftype": ftype,
        "rtUrls": List<dynamic>.from(rtUrls.map((x) => x)),
        "djId": djId,
        "copyright": copyright,
        "s_id": sId,
        "mark": mark,
        "originCoverType": originCoverType,
        "originSongSimpleData": originSongSimpleData?.toJson(),
        "tagPicList": tagPicList,
        "resourceState": resourceState,
        "version": version,
        "songJumpInfo": songJumpInfo,
        "entertainmentTags": entertainmentTags,
        "single": single,
        "noCopyrightRcmd": noCopyrightRcmd,
        "rtype": rtype,
        "rurl": rurl,
        "mst": mst,
        "cp": cp,
        "mv": mv,
        "publishTime": publishTime,
        "reason": reason,
        "recommendReason": recommendReason,
        "privilege": privilege.toJson(),
        "alg": algValues.reverse[alg],
        "s_ctrp": sCtrp,
      };
}

class Al {
  final int id;
  final String name;
  final String picUrl;
  final List<dynamic> tns;
  final String? picStr;
  final double pic;

  Al({
    required this.id,
    required this.name,
    required this.picUrl,
    required this.tns,
    this.picStr,
    required this.pic,
  });

  Al copyWith({
    int? id,
    String? name,
    String? picUrl,
    List<dynamic>? tns,
    String? picStr,
    double? pic,
  }) =>
      Al(
        id: id ?? this.id,
        name: name ?? this.name,
        picUrl: picUrl ?? this.picUrl,
        tns: tns ?? this.tns,
        picStr: picStr ?? this.picStr,
        pic: pic ?? this.pic,
      );

  factory Al.fromRawJson(String str) => Al.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Al.fromJson(Map<String, dynamic> json) => Al(
        id: json["id"],
        name: json["name"],
        picUrl: json["picUrl"],
        tns: List<dynamic>.from(json["tns"].map((x) => x)),
        picStr: json["pic_str"],
        pic: json["pic"]?.toDouble(),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "picUrl": picUrl,
        "tns": List<dynamic>.from(tns.map((x) => x)),
        "pic_str": picStr,
        "pic": pic,
      };
}

enum Alg {
  ALG_MUSIC_REC_HP_COVER_SUB_PROFILE_UNRESTRICTED,
  ALG_MUSIC_REC_UNITE_DAILY_DSSM_V1,
  DAILY_AUDITION_ITEM_BASE,
  DAILY_AUDITION_PROMOTED,
  ITEMBASED_ON
}

final algValues = EnumValues({
  "alg-music-rec-hpCover-sub_profile-unrestricted": Alg.ALG_MUSIC_REC_HP_COVER_SUB_PROFILE_UNRESTRICTED,
  "alg-music-rec-unite-daily-dssm_v1": Alg.ALG_MUSIC_REC_UNITE_DAILY_DSSM_V1,
  "daily_audition_itemBase": Alg.DAILY_AUDITION_ITEM_BASE,
  "daily_audition_promoted": Alg.DAILY_AUDITION_PROMOTED,
  "itembased_on": Alg.ITEMBASED_ON
});

class Ar {
  final int id;
  final String name;
  final List<dynamic> tns;
  final List<dynamic> alias;

  Ar({
    required this.id,
    required this.name,
    required this.tns,
    required this.alias,
  });

  Ar copyWith({
    int? id,
    String? name,
    List<dynamic>? tns,
    List<dynamic>? alias,
  }) =>
      Ar(
        id: id ?? this.id,
        name: name ?? this.name,
        tns: tns ?? this.tns,
        alias: alias ?? this.alias,
      );

  factory Ar.fromRawJson(String str) => Ar.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Ar.fromJson(Map<String, dynamic> json) => Ar(
        id: json["id"],
        name: json["name"],
        tns: List<dynamic>.from(json["tns"].map((x) => x)),
        alias: List<dynamic>.from(json["alias"].map((x) => x)),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
        "tns": List<dynamic>.from(tns.map((x) => x)),
        "alias": List<dynamic>.from(alias.map((x) => x)),
      };
}

class L {
  final int br;
  final int fid;
  final int size;
  final int vd;
  final int sr;

  L({
    required this.br,
    required this.fid,
    required this.size,
    required this.vd,
    required this.sr,
  });

  L copyWith({
    int? br,
    int? fid,
    int? size,
    int? vd,
    int? sr,
  }) =>
      L(
        br: br ?? this.br,
        fid: fid ?? this.fid,
        size: size ?? this.size,
        vd: vd ?? this.vd,
        sr: sr ?? this.sr,
      );

  factory L.fromRawJson(String str) => L.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory L.fromJson(Map<String, dynamic> json) => L(
        br: json["br"],
        fid: json["fid"],
        size: json["size"],
        vd: json["vd"],
        sr: json["sr"],
      );

  Map<String, dynamic> toJson() => {
        "br": br,
        "fid": fid,
        "size": size,
        "vd": vd,
        "sr": sr,
      };
}

class OriginSongSimpleData {
  final int songId;
  final String name;
  final List<AlbumMeta> artists;
  final AlbumMeta albumMeta;

  OriginSongSimpleData({
    required this.songId,
    required this.name,
    required this.artists,
    required this.albumMeta,
  });

  OriginSongSimpleData copyWith({
    int? songId,
    String? name,
    List<AlbumMeta>? artists,
    AlbumMeta? albumMeta,
  }) =>
      OriginSongSimpleData(
        songId: songId ?? this.songId,
        name: name ?? this.name,
        artists: artists ?? this.artists,
        albumMeta: albumMeta ?? this.albumMeta,
      );

  factory OriginSongSimpleData.fromRawJson(String str) => OriginSongSimpleData.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory OriginSongSimpleData.fromJson(Map<String, dynamic> json) => OriginSongSimpleData(
        songId: json["songId"],
        name: json["name"],
        artists: List<AlbumMeta>.from(json["artists"].map((x) => AlbumMeta.fromJson(x))),
        albumMeta: AlbumMeta.fromJson(json["albumMeta"]),
      );

  Map<String, dynamic> toJson() => {
        "songId": songId,
        "name": name,
        "artists": List<dynamic>.from(artists.map((x) => x.toJson())),
        "albumMeta": albumMeta.toJson(),
      };
}

class AlbumMeta {
  final int id;
  final String name;

  AlbumMeta({
    required this.id,
    required this.name,
  });

  AlbumMeta copyWith({
    int? id,
    String? name,
  }) =>
      AlbumMeta(
        id: id ?? this.id,
        name: name ?? this.name,
      );

  factory AlbumMeta.fromRawJson(String str) => AlbumMeta.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory AlbumMeta.fromJson(Map<String, dynamic> json) => AlbumMeta(
        id: json["id"],
        name: json["name"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "name": name,
      };
}

class Privilege {
  final int id;
  final int fee;
  final int payed;
  final int realPayed;
  final int st;
  final int pl;
  final int dl;
  final int sp;
  final int cp;
  final int subp;
  final bool cs;
  final int maxbr;
  final int fl;
  final dynamic pc;
  final bool toast;
  final int flag;
  final bool paidBigBang;
  final bool preSell;
  final int playMaxbr;
  final int downloadMaxbr;
  final Level maxBrLevel;
  final Level playMaxBrLevel;
  final Level downloadMaxBrLevel;
  final Level plLevel;
  final Level dlLevel;
  final FlLevel flLevel;
  final dynamic rscl;
  final FreeTrialPrivilege freeTrialPrivilege;
  final int rightSource;
  final List<ChargeInfoList> chargeInfoList;

  Privilege({
    required this.id,
    required this.fee,
    required this.payed,
    required this.realPayed,
    required this.st,
    required this.pl,
    required this.dl,
    required this.sp,
    required this.cp,
    required this.subp,
    required this.cs,
    required this.maxbr,
    required this.fl,
    required this.pc,
    required this.toast,
    required this.flag,
    required this.paidBigBang,
    required this.preSell,
    required this.playMaxbr,
    required this.downloadMaxbr,
    required this.maxBrLevel,
    required this.playMaxBrLevel,
    required this.downloadMaxBrLevel,
    required this.plLevel,
    required this.dlLevel,
    required this.flLevel,
    required this.rscl,
    required this.freeTrialPrivilege,
    required this.rightSource,
    required this.chargeInfoList,
  });

  Privilege copyWith({
    int? id,
    int? fee,
    int? payed,
    int? realPayed,
    int? st,
    int? pl,
    int? dl,
    int? sp,
    int? cp,
    int? subp,
    bool? cs,
    int? maxbr,
    int? fl,
    dynamic pc,
    bool? toast,
    int? flag,
    bool? paidBigBang,
    bool? preSell,
    int? playMaxbr,
    int? downloadMaxbr,
    Level? maxBrLevel,
    Level? playMaxBrLevel,
    Level? downloadMaxBrLevel,
    Level? plLevel,
    Level? dlLevel,
    FlLevel? flLevel,
    dynamic rscl,
    FreeTrialPrivilege? freeTrialPrivilege,
    int? rightSource,
    List<ChargeInfoList>? chargeInfoList,
  }) =>
      Privilege(
        id: id ?? this.id,
        fee: fee ?? this.fee,
        payed: payed ?? this.payed,
        realPayed: realPayed ?? this.realPayed,
        st: st ?? this.st,
        pl: pl ?? this.pl,
        dl: dl ?? this.dl,
        sp: sp ?? this.sp,
        cp: cp ?? this.cp,
        subp: subp ?? this.subp,
        cs: cs ?? this.cs,
        maxbr: maxbr ?? this.maxbr,
        fl: fl ?? this.fl,
        pc: pc ?? this.pc,
        toast: toast ?? this.toast,
        flag: flag ?? this.flag,
        paidBigBang: paidBigBang ?? this.paidBigBang,
        preSell: preSell ?? this.preSell,
        playMaxbr: playMaxbr ?? this.playMaxbr,
        downloadMaxbr: downloadMaxbr ?? this.downloadMaxbr,
        maxBrLevel: maxBrLevel ?? this.maxBrLevel,
        playMaxBrLevel: playMaxBrLevel ?? this.playMaxBrLevel,
        downloadMaxBrLevel: downloadMaxBrLevel ?? this.downloadMaxBrLevel,
        plLevel: plLevel ?? this.plLevel,
        dlLevel: dlLevel ?? this.dlLevel,
        flLevel: flLevel ?? this.flLevel,
        rscl: rscl ?? this.rscl,
        freeTrialPrivilege: freeTrialPrivilege ?? this.freeTrialPrivilege,
        rightSource: rightSource ?? this.rightSource,
        chargeInfoList: chargeInfoList ?? this.chargeInfoList,
      );

  factory Privilege.fromRawJson(String str) => Privilege.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Privilege.fromJson(Map<String, dynamic> json) => Privilege(
        id: json["id"],
        fee: json["fee"],
        payed: json["payed"],
        realPayed: json["realPayed"],
        st: json["st"],
        pl: json["pl"],
        dl: json["dl"],
        sp: json["sp"],
        cp: json["cp"],
        subp: json["subp"],
        cs: json["cs"],
        maxbr: json["maxbr"],
        fl: json["fl"],
        pc: json["pc"],
        toast: json["toast"],
        flag: json["flag"],
        paidBigBang: json["paidBigBang"],
        preSell: json["preSell"],
        playMaxbr: json["playMaxbr"],
        downloadMaxbr: json["downloadMaxbr"],
        maxBrLevel: levelValues.map[json["maxBrLevel"]]!,
        playMaxBrLevel: levelValues.map[json["playMaxBrLevel"]]!,
        downloadMaxBrLevel: levelValues.map[json["downloadMaxBrLevel"]]!,
        plLevel: levelValues.map[json["plLevel"]]!,
        dlLevel: levelValues.map[json["dlLevel"]]!,
        flLevel: flLevelValues.map[json["flLevel"]]!,
        rscl: json["rscl"],
        freeTrialPrivilege: FreeTrialPrivilege.fromJson(json["freeTrialPrivilege"]),
        rightSource: json["rightSource"],
        chargeInfoList: List<ChargeInfoList>.from(json["chargeInfoList"].map((x) => ChargeInfoList.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "fee": fee,
        "payed": payed,
        "realPayed": realPayed,
        "st": st,
        "pl": pl,
        "dl": dl,
        "sp": sp,
        "cp": cp,
        "subp": subp,
        "cs": cs,
        "maxbr": maxbr,
        "fl": fl,
        "pc": pc,
        "toast": toast,
        "flag": flag,
        "paidBigBang": paidBigBang,
        "preSell": preSell,
        "playMaxbr": playMaxbr,
        "downloadMaxbr": downloadMaxbr,
        "maxBrLevel": levelValues.reverse[maxBrLevel],
        "playMaxBrLevel": levelValues.reverse[playMaxBrLevel],
        "downloadMaxBrLevel": levelValues.reverse[downloadMaxBrLevel],
        "plLevel": levelValues.reverse[plLevel],
        "dlLevel": levelValues.reverse[dlLevel],
        "flLevel": flLevelValues.reverse[flLevel],
        "rscl": rscl,
        "freeTrialPrivilege": freeTrialPrivilege.toJson(),
        "rightSource": rightSource,
        "chargeInfoList": List<dynamic>.from(chargeInfoList.map((x) => x.toJson())),
      };
}

class ChargeInfoList {
  final int rate;
  final dynamic chargeUrl;
  final dynamic chargeMessage;
  final int chargeType;

  ChargeInfoList({
    required this.rate,
    required this.chargeUrl,
    required this.chargeMessage,
    required this.chargeType,
  });

  ChargeInfoList copyWith({
    int? rate,
    dynamic chargeUrl,
    dynamic chargeMessage,
    int? chargeType,
  }) =>
      ChargeInfoList(
        rate: rate ?? this.rate,
        chargeUrl: chargeUrl ?? this.chargeUrl,
        chargeMessage: chargeMessage ?? this.chargeMessage,
        chargeType: chargeType ?? this.chargeType,
      );

  factory ChargeInfoList.fromRawJson(String str) => ChargeInfoList.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory ChargeInfoList.fromJson(Map<String, dynamic> json) => ChargeInfoList(
        rate: json["rate"],
        chargeUrl: json["chargeUrl"],
        chargeMessage: json["chargeMessage"],
        chargeType: json["chargeType"],
      );

  Map<String, dynamic> toJson() => {
        "rate": rate,
        "chargeUrl": chargeUrl,
        "chargeMessage": chargeMessage,
        "chargeType": chargeType,
      };
}

enum Level { EXHIGH, HIGHER, HIRES, LOSSLESS }

final levelValues =
    EnumValues({"exhigh": Level.EXHIGH, "higher": Level.HIGHER, "hires": Level.HIRES, "lossless": Level.LOSSLESS});

enum FlLevel { EXHIGH, HIGHER, NONE }

final flLevelValues = EnumValues({"exhigh": FlLevel.EXHIGH, "higher": FlLevel.HIGHER, "none": FlLevel.NONE});

class FreeTrialPrivilege {
  final bool resConsumable;
  final bool userConsumable;
  final dynamic listenType;
  final dynamic cannotListenReason;

  FreeTrialPrivilege({
    required this.resConsumable,
    required this.userConsumable,
    required this.listenType,
    required this.cannotListenReason,
  });

  FreeTrialPrivilege copyWith({
    bool? resConsumable,
    bool? userConsumable,
    dynamic listenType,
    dynamic cannotListenReason,
  }) =>
      FreeTrialPrivilege(
        resConsumable: resConsumable ?? this.resConsumable,
        userConsumable: userConsumable ?? this.userConsumable,
        listenType: listenType ?? this.listenType,
        cannotListenReason: cannotListenReason ?? this.cannotListenReason,
      );

  factory FreeTrialPrivilege.fromRawJson(String str) => FreeTrialPrivilege.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory FreeTrialPrivilege.fromJson(Map<String, dynamic> json) => FreeTrialPrivilege(
        resConsumable: json["resConsumable"],
        userConsumable: json["userConsumable"],
        listenType: json["listenType"],
        cannotListenReason: json["cannotListenReason"],
      );

  Map<String, dynamic> toJson() => {
        "resConsumable": resConsumable,
        "userConsumable": userConsumable,
        "listenType": listenType,
        "cannotListenReason": cannotListenReason,
      };
}

enum Rt { EMPTY, THE_600902000009223871 }

final rtValues = EnumValues({"": Rt.EMPTY, "600902000009223871": Rt.THE_600902000009223871});

class RecommendReason {
  final int songId;
  final String reason;
  final String reasonId;
  final dynamic targetUrl;

  RecommendReason({
    required this.songId,
    required this.reason,
    required this.reasonId,
    required this.targetUrl,
  });

  RecommendReason copyWith({
    int? songId,
    String? reason,
    String? reasonId,
    dynamic targetUrl,
  }) =>
      RecommendReason(
        songId: songId ?? this.songId,
        reason: reason ?? this.reason,
        reasonId: reasonId ?? this.reasonId,
        targetUrl: targetUrl ?? this.targetUrl,
      );

  factory RecommendReason.fromRawJson(String str) => RecommendReason.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory RecommendReason.fromJson(Map<String, dynamic> json) => RecommendReason(
        songId: json["songId"],
        reason: json["reason"],
        reasonId: json["reasonId"],
        targetUrl: json["targetUrl"],
      );

  Map<String, dynamic> toJson() => {
        "songId": songId,
        "reason": reason,
        "reasonId": reasonId,
        "targetUrl": targetUrl,
      };
}

class EnumValues<T> {
  Map<String, T> map;
  late Map<T, String> reverseMap;

  EnumValues(this.map);

  Map<T, String> get reverse {
    reverseMap = map.map((k, v) => MapEntry(v, k));
    return reverseMap;
  }
}
