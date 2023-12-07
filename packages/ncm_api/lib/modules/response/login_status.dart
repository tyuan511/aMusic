import 'dart:convert';

class LoginStatusResponse {
  final Data data;

  LoginStatusResponse({
    required this.data,
  });

  LoginStatusResponse copyWith({
    Data? data,
  }) =>
      LoginStatusResponse(
        data: data ?? this.data,
      );

  factory LoginStatusResponse.fromRawJson(String str) => LoginStatusResponse.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory LoginStatusResponse.fromJson(Map<String, dynamic> json) => LoginStatusResponse(
        data: Data.fromJson(json["data"]),
      );

  Map<String, dynamic> toJson() => {
        "data": data.toJson(),
      };
}

class Data {
  final int code;
  final Account? account;
  final Profile? profile;

  Data({
    required this.code,
    required this.account,
    required this.profile,
  });

  Data copyWith({
    int? code,
    Account? account,
    Profile? profile,
  }) =>
      Data(
        code: code ?? this.code,
        account: account ?? this.account,
        profile: profile ?? this.profile,
      );

  factory Data.fromRawJson(String str) => Data.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Data.fromJson(Map<String, dynamic> json) => Data(
        code: json["code"],
        account: json["account"] == null ? null : Account.fromJson(json["account"]),
        profile: json["account"] == null ? null : Profile.fromJson(json["profile"]),
      );

  Map<String, dynamic> toJson() => {
        "code": code,
        "account": account?.toJson(),
        "profile": profile?.toJson(),
      };
}

class Account {
  final int id;
  final String userName;
  final int type;
  final int status;
  final int whitelistAuthority;
  final int createTime;
  final int tokenVersion;
  final int ban;
  final int baoyueVersion;
  final int donateVersion;
  final int vipType;
  final bool anonimousUser;
  final bool paidFee;

  Account({
    required this.id,
    required this.userName,
    required this.type,
    required this.status,
    required this.whitelistAuthority,
    required this.createTime,
    required this.tokenVersion,
    required this.ban,
    required this.baoyueVersion,
    required this.donateVersion,
    required this.vipType,
    required this.anonimousUser,
    required this.paidFee,
  });

  Account copyWith({
    int? id,
    String? userName,
    int? type,
    int? status,
    int? whitelistAuthority,
    int? createTime,
    int? tokenVersion,
    int? ban,
    int? baoyueVersion,
    int? donateVersion,
    int? vipType,
    bool? anonimousUser,
    bool? paidFee,
  }) =>
      Account(
        id: id ?? this.id,
        userName: userName ?? this.userName,
        type: type ?? this.type,
        status: status ?? this.status,
        whitelistAuthority: whitelistAuthority ?? this.whitelistAuthority,
        createTime: createTime ?? this.createTime,
        tokenVersion: tokenVersion ?? this.tokenVersion,
        ban: ban ?? this.ban,
        baoyueVersion: baoyueVersion ?? this.baoyueVersion,
        donateVersion: donateVersion ?? this.donateVersion,
        vipType: vipType ?? this.vipType,
        anonimousUser: anonimousUser ?? this.anonimousUser,
        paidFee: paidFee ?? this.paidFee,
      );

  factory Account.fromRawJson(String str) => Account.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Account.fromJson(Map<String, dynamic> json) => Account(
        id: json["id"],
        userName: json["userName"],
        type: json["type"],
        status: json["status"],
        whitelistAuthority: json["whitelistAuthority"],
        createTime: json["createTime"],
        tokenVersion: json["tokenVersion"],
        ban: json["ban"],
        baoyueVersion: json["baoyueVersion"],
        donateVersion: json["donateVersion"],
        vipType: json["vipType"],
        anonimousUser: json["anonimousUser"],
        paidFee: json["paidFee"],
      );

  Map<String, dynamic> toJson() => {
        "id": id,
        "userName": userName,
        "type": type,
        "status": status,
        "whitelistAuthority": whitelistAuthority,
        "createTime": createTime,
        "tokenVersion": tokenVersion,
        "ban": ban,
        "baoyueVersion": baoyueVersion,
        "donateVersion": donateVersion,
        "vipType": vipType,
        "anonimousUser": anonimousUser,
        "paidFee": paidFee,
      };
}

class Profile {
  final int userId;
  final int userType;
  final String nickname;
  final double avatarImgId;
  final String avatarUrl;
  final int backgroundImgId;
  final String backgroundUrl;
  final dynamic signature;
  final int createTime;
  final String userName;
  final int accountType;
  final String shortUserName;
  final int birthday;
  final int authority;
  final int gender;
  final int accountStatus;
  final int province;
  final int city;
  final int authStatus;
  final dynamic description;
  final dynamic detailDescription;
  final bool defaultAvatar;
  final dynamic expertTags;
  final dynamic experts;
  final int djStatus;
  final int locationStatus;
  final int vipType;
  final bool followed;
  final bool mutual;
  final bool authenticated;
  final int lastLoginTime;
  final String lastLoginIp;
  final dynamic remarkName;
  final int viptypeVersion;
  final int authenticationTypes;
  final dynamic avatarDetail;
  final bool anchor;

  Profile({
    required this.userId,
    required this.userType,
    required this.nickname,
    required this.avatarImgId,
    required this.avatarUrl,
    required this.backgroundImgId,
    required this.backgroundUrl,
    required this.signature,
    required this.createTime,
    required this.userName,
    required this.accountType,
    required this.shortUserName,
    required this.birthday,
    required this.authority,
    required this.gender,
    required this.accountStatus,
    required this.province,
    required this.city,
    required this.authStatus,
    required this.description,
    required this.detailDescription,
    required this.defaultAvatar,
    required this.expertTags,
    required this.experts,
    required this.djStatus,
    required this.locationStatus,
    required this.vipType,
    required this.followed,
    required this.mutual,
    required this.authenticated,
    required this.lastLoginTime,
    required this.lastLoginIp,
    required this.remarkName,
    required this.viptypeVersion,
    required this.authenticationTypes,
    required this.avatarDetail,
    required this.anchor,
  });

  Profile copyWith({
    int? userId,
    int? userType,
    String? nickname,
    double? avatarImgId,
    String? avatarUrl,
    int? backgroundImgId,
    String? backgroundUrl,
    dynamic signature,
    int? createTime,
    String? userName,
    int? accountType,
    String? shortUserName,
    int? birthday,
    int? authority,
    int? gender,
    int? accountStatus,
    int? province,
    int? city,
    int? authStatus,
    dynamic description,
    dynamic detailDescription,
    bool? defaultAvatar,
    dynamic expertTags,
    dynamic experts,
    int? djStatus,
    int? locationStatus,
    int? vipType,
    bool? followed,
    bool? mutual,
    bool? authenticated,
    int? lastLoginTime,
    String? lastLoginIp,
    dynamic remarkName,
    int? viptypeVersion,
    int? authenticationTypes,
    dynamic avatarDetail,
    bool? anchor,
  }) =>
      Profile(
        userId: userId ?? this.userId,
        userType: userType ?? this.userType,
        nickname: nickname ?? this.nickname,
        avatarImgId: avatarImgId ?? this.avatarImgId,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        backgroundImgId: backgroundImgId ?? this.backgroundImgId,
        backgroundUrl: backgroundUrl ?? this.backgroundUrl,
        signature: signature ?? this.signature,
        createTime: createTime ?? this.createTime,
        userName: userName ?? this.userName,
        accountType: accountType ?? this.accountType,
        shortUserName: shortUserName ?? this.shortUserName,
        birthday: birthday ?? this.birthday,
        authority: authority ?? this.authority,
        gender: gender ?? this.gender,
        accountStatus: accountStatus ?? this.accountStatus,
        province: province ?? this.province,
        city: city ?? this.city,
        authStatus: authStatus ?? this.authStatus,
        description: description ?? this.description,
        detailDescription: detailDescription ?? this.detailDescription,
        defaultAvatar: defaultAvatar ?? this.defaultAvatar,
        expertTags: expertTags ?? this.expertTags,
        experts: experts ?? this.experts,
        djStatus: djStatus ?? this.djStatus,
        locationStatus: locationStatus ?? this.locationStatus,
        vipType: vipType ?? this.vipType,
        followed: followed ?? this.followed,
        mutual: mutual ?? this.mutual,
        authenticated: authenticated ?? this.authenticated,
        lastLoginTime: lastLoginTime ?? this.lastLoginTime,
        lastLoginIp: lastLoginIp ?? this.lastLoginIp,
        remarkName: remarkName ?? this.remarkName,
        viptypeVersion: viptypeVersion ?? this.viptypeVersion,
        authenticationTypes: authenticationTypes ?? this.authenticationTypes,
        avatarDetail: avatarDetail ?? this.avatarDetail,
        anchor: anchor ?? this.anchor,
      );

  factory Profile.fromRawJson(String str) => Profile.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Profile.fromJson(Map<String, dynamic> json) => Profile(
        userId: json["userId"],
        userType: json["userType"],
        nickname: json["nickname"],
        avatarImgId: json["avatarImgId"]?.toDouble(),
        avatarUrl: json["avatarUrl"],
        backgroundImgId: json["backgroundImgId"],
        backgroundUrl: json["backgroundUrl"],
        signature: json["signature"],
        createTime: json["createTime"],
        userName: json["userName"],
        accountType: json["accountType"],
        shortUserName: json["shortUserName"],
        birthday: json["birthday"],
        authority: json["authority"],
        gender: json["gender"],
        accountStatus: json["accountStatus"],
        province: json["province"],
        city: json["city"],
        authStatus: json["authStatus"],
        description: json["description"],
        detailDescription: json["detailDescription"],
        defaultAvatar: json["defaultAvatar"],
        expertTags: json["expertTags"],
        experts: json["experts"],
        djStatus: json["djStatus"],
        locationStatus: json["locationStatus"],
        vipType: json["vipType"],
        followed: json["followed"],
        mutual: json["mutual"],
        authenticated: json["authenticated"],
        lastLoginTime: json["lastLoginTime"],
        lastLoginIp: json["lastLoginIP"],
        remarkName: json["remarkName"],
        viptypeVersion: json["viptypeVersion"],
        authenticationTypes: json["authenticationTypes"],
        avatarDetail: json["avatarDetail"],
        anchor: json["anchor"],
      );

  Map<String, dynamic> toJson() => {
        "userId": userId,
        "userType": userType,
        "nickname": nickname,
        "avatarImgId": avatarImgId,
        "avatarUrl": avatarUrl,
        "backgroundImgId": backgroundImgId,
        "backgroundUrl": backgroundUrl,
        "signature": signature,
        "createTime": createTime,
        "userName": userName,
        "accountType": accountType,
        "shortUserName": shortUserName,
        "birthday": birthday,
        "authority": authority,
        "gender": gender,
        "accountStatus": accountStatus,
        "province": province,
        "city": city,
        "authStatus": authStatus,
        "description": description,
        "detailDescription": detailDescription,
        "defaultAvatar": defaultAvatar,
        "expertTags": expertTags,
        "experts": experts,
        "djStatus": djStatus,
        "locationStatus": locationStatus,
        "vipType": vipType,
        "followed": followed,
        "mutual": mutual,
        "authenticated": authenticated,
        "lastLoginTime": lastLoginTime,
        "lastLoginIP": lastLoginIp,
        "remarkName": remarkName,
        "viptypeVersion": viptypeVersion,
        "authenticationTypes": authenticationTypes,
        "avatarDetail": avatarDetail,
        "anchor": anchor,
      };
}
