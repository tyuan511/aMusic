import 'dart:convert';

class PlaylistRecommend {
  final int code;
  final bool featureFirst;
  final bool haveRcmdSongs;
  final List<Recommend> recommend;

  PlaylistRecommend({
    required this.code,
    required this.featureFirst,
    required this.haveRcmdSongs,
    required this.recommend,
  });

  PlaylistRecommend copyWith({
    int? code,
    bool? featureFirst,
    bool? haveRcmdSongs,
    List<Recommend>? recommend,
  }) =>
      PlaylistRecommend(
        code: code ?? this.code,
        featureFirst: featureFirst ?? this.featureFirst,
        haveRcmdSongs: haveRcmdSongs ?? this.haveRcmdSongs,
        recommend: recommend ?? this.recommend,
      );

  factory PlaylistRecommend.fromRawJson(String str) => PlaylistRecommend.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PlaylistRecommend.fromJson(Map<String, dynamic> json) => PlaylistRecommend(
        code: json["code"],
        featureFirst: json["featureFirst"],
        haveRcmdSongs: json["haveRcmdSongs"],
        recommend: List<Recommend>.from(json["recommend"].map((x) => Recommend.fromJson(x))),
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "featureFirst": featureFirst,
        "haveRcmdSongs": haveRcmdSongs,
        "recommend": List<dynamic>.from(recommend.map((x) => x.toJson())),
      };
}

class Recommend {
  final int id;
  final int type;
  final String name;
  final String copywriter;
  final String picUrl;
  final int playcount;
  final int createTime;
  final Creator creator;
  final int trackCount;
  final int userId;
  final String alg;

  Recommend({
    required this.id,
    required this.type,
    required this.name,
    required this.copywriter,
    required this.picUrl,
    required this.playcount,
    required this.createTime,
    required this.creator,
    required this.trackCount,
    required this.userId,
    required this.alg,
  });

  Recommend copyWith({
    int? id,
    int? type,
    String? name,
    String? copywriter,
    String? picUrl,
    int? playcount,
    int? createTime,
    Creator? creator,
    int? trackCount,
    int? userId,
    String? alg,
  }) =>
      Recommend(
        id: id ?? this.id,
        type: type ?? this.type,
        name: name ?? this.name,
        copywriter: copywriter ?? this.copywriter,
        picUrl: picUrl ?? this.picUrl,
        playcount: playcount ?? this.playcount,
        createTime: createTime ?? this.createTime,
        creator: creator ?? this.creator,
        trackCount: trackCount ?? this.trackCount,
        userId: userId ?? this.userId,
        alg: alg ?? this.alg,
      );

  factory Recommend.fromRawJson(String str) => Recommend.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Recommend.fromJson(Map<String, dynamic> json) => Recommend(
        id: json["id"],
        type: json["type"],
        name: json["name"],
        copywriter: json["copywriter"],
        picUrl: json["picUrl"],
        playcount: json["playcount"],
        createTime: json["createTime"],
        creator: Creator.fromJson(json["creator"]),
        trackCount: json["trackCount"],
        userId: json["userId"],
        alg: json["alg"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "type": type,
        "name": name,
        "copywriter": copywriter,
        "picUrl": picUrl,
        "playcount": playcount,
        "createTime": createTime,
        "creator": creator.toJson(),
        "trackCount": trackCount,
        "userId": userId,
        "alg": alg,
      };
}

class Creator {
  final bool mutual;
  final dynamic remarkName;
  final double avatarImgId;
  final double backgroundImgId;
  final int accountStatus;
  final int vipType;
  final int province;
  final String avatarUrl;
  final int authStatus;
  final int userType;
  final String nickname;
  final int gender;
  final int birthday;
  final int city;
  final String backgroundUrl;
  final String avatarImgIdStr;
  final String backgroundImgIdStr;
  final String detailDescription;
  final bool defaultAvatar;
  final dynamic expertTags;
  final int djStatus;
  final bool followed;
  final String description;
  final int userId;
  final String signature;
  final int authority;

  Creator({
    required this.mutual,
    required this.remarkName,
    required this.avatarImgId,
    required this.backgroundImgId,
    required this.accountStatus,
    required this.vipType,
    required this.province,
    required this.avatarUrl,
    required this.authStatus,
    required this.userType,
    required this.nickname,
    required this.gender,
    required this.birthday,
    required this.city,
    required this.backgroundUrl,
    required this.avatarImgIdStr,
    required this.backgroundImgIdStr,
    required this.detailDescription,
    required this.defaultAvatar,
    required this.expertTags,
    required this.djStatus,
    required this.followed,
    required this.description,
    required this.userId,
    required this.signature,
    required this.authority,
  });

  Creator copyWith({
    bool? mutual,
    dynamic remarkName,
    double? avatarImgId,
    double? backgroundImgId,
    int? accountStatus,
    int? vipType,
    int? province,
    String? avatarUrl,
    int? authStatus,
    int? userType,
    String? nickname,
    int? gender,
    int? birthday,
    int? city,
    String? backgroundUrl,
    String? avatarImgIdStr,
    String? backgroundImgIdStr,
    String? detailDescription,
    bool? defaultAvatar,
    dynamic expertTags,
    int? djStatus,
    bool? followed,
    String? description,
    int? userId,
    String? signature,
    int? authority,
  }) =>
      Creator(
        mutual: mutual ?? this.mutual,
        remarkName: remarkName ?? this.remarkName,
        avatarImgId: avatarImgId ?? this.avatarImgId,
        backgroundImgId: backgroundImgId ?? this.backgroundImgId,
        accountStatus: accountStatus ?? this.accountStatus,
        vipType: vipType ?? this.vipType,
        province: province ?? this.province,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        authStatus: authStatus ?? this.authStatus,
        userType: userType ?? this.userType,
        nickname: nickname ?? this.nickname,
        gender: gender ?? this.gender,
        birthday: birthday ?? this.birthday,
        city: city ?? this.city,
        backgroundUrl: backgroundUrl ?? this.backgroundUrl,
        avatarImgIdStr: avatarImgIdStr ?? this.avatarImgIdStr,
        backgroundImgIdStr: backgroundImgIdStr ?? this.backgroundImgIdStr,
        detailDescription: detailDescription ?? this.detailDescription,
        defaultAvatar: defaultAvatar ?? this.defaultAvatar,
        expertTags: expertTags ?? this.expertTags,
        djStatus: djStatus ?? this.djStatus,
        followed: followed ?? this.followed,
        description: description ?? this.description,
        userId: userId ?? this.userId,
        signature: signature ?? this.signature,
        authority: authority ?? this.authority,
      );

  factory Creator.fromRawJson(String str) => Creator.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
        mutual: json["mutual"],
        remarkName: json["remarkName"],
        avatarImgId: json["avatarImgId"]?.toDouble(),
        backgroundImgId: json["backgroundImgId"]?.toDouble(),
        accountStatus: json["accountStatus"],
        vipType: json["vipType"],
        province: json["province"],
        avatarUrl: json["avatarUrl"],
        authStatus: json["authStatus"],
        userType: json["userType"],
        nickname: json["nickname"],
        gender: json["gender"],
        birthday: json["birthday"],
        city: json["city"],
        backgroundUrl: json["backgroundUrl"],
        avatarImgIdStr: json["avatarImgIdStr"],
        backgroundImgIdStr: json["backgroundImgIdStr"],
        detailDescription: json["detailDescription"],
        defaultAvatar: json["defaultAvatar"],
        expertTags: json["expertTags"],
        djStatus: json["djStatus"],
        followed: json["followed"],
        description: json["description"],
        userId: json["userId"],
        signature: json["signature"],
        authority: json["authority"],
      );

  Map<String, dynamic> toJson() => {
        "mutual": mutual,
        "remarkName": remarkName,
        "avatarImgId": avatarImgId,
        "backgroundImgId": backgroundImgId,
        "accountStatus": accountStatus,
        "vipType": vipType,
        "province": province,
        "avatarUrl": avatarUrl,
        "authStatus": authStatus,
        "userType": userType,
        "nickname": nickname,
        "gender": gender,
        "birthday": birthday,
        "city": city,
        "backgroundUrl": backgroundUrl,
        "avatarImgIdStr": avatarImgIdStr,
        "backgroundImgIdStr": backgroundImgIdStr,
        "detailDescription": detailDescription,
        "defaultAvatar": defaultAvatar,
        "expertTags": expertTags,
        "djStatus": djStatus,
        "followed": followed,
        "description": description,
        "userId": userId,
        "signature": signature,
        "authority": authority,
      };
}
