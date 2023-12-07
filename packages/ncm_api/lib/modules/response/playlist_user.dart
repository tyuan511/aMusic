import 'dart:convert';

class PlaylistUserRes {
  final String version;
  final bool more;
  final List<Playlist> playlist;
  final int code;

  PlaylistUserRes({
    required this.version,
    required this.more,
    required this.playlist,
    required this.code,
  });

  PlaylistUserRes copyWith({
    String? version,
    bool? more,
    List<Playlist>? playlist,
    int? code,
  }) =>
      PlaylistUserRes(
        version: version ?? this.version,
        more: more ?? this.more,
        playlist: playlist ?? this.playlist,
        code: code ?? this.code,
      );

  factory PlaylistUserRes.fromRawJson(String str) => PlaylistUserRes.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory PlaylistUserRes.fromJson(Map<String, dynamic> json) => PlaylistUserRes(
        version: json["version"],
        more: json["more"],
        playlist: List<Playlist>.from(json["playlist"].map((x) => Playlist.fromJson(x))),
        code: json["code"],
      );

  Map<String, dynamic> toJson() => {
        "version": version,
        "more": more,
        "playlist": List<dynamic>.from(playlist.map((x) => x.toJson())),
        "code": code,
      };
}

class Playlist {
  final List<dynamic> subscribers;
  final bool subscribed;
  final Creator creator;
  final dynamic artists;
  final dynamic tracks;
  final bool top;
  final dynamic updateFrequency;
  final int backgroundCoverId;
  final dynamic backgroundCoverUrl;
  final int titleImage;
  final dynamic titleImageUrl;
  final dynamic englishTitle;
  final bool opRecommend;
  final dynamic recommendInfo;
  final int subscribedCount;
  final int cloudTrackCount;
  final int userId;
  final int totalDuration;
  final double coverImgId;
  final int privacy;
  final int trackUpdateTime;
  final int trackCount;
  final int updateTime;
  final String commentThreadId;
  final String coverImgUrl;
  final int specialType;
  final bool anonimous;
  final int createTime;
  final bool highQuality;
  final bool newImported;
  final int trackNumberUpdateTime;
  final int playCount;
  final int adType;
  final String? description;
  final List<dynamic> tags;
  final bool ordered;
  final int status;
  final String name;
  final int id;
  final String coverImgIdStr;
  final dynamic sharedUsers;
  final dynamic shareStatus;
  final bool copied;

  Playlist({
    required this.subscribers,
    required this.subscribed,
    required this.creator,
    required this.artists,
    required this.tracks,
    required this.top,
    required this.updateFrequency,
    required this.backgroundCoverId,
    required this.backgroundCoverUrl,
    required this.titleImage,
    required this.titleImageUrl,
    required this.englishTitle,
    required this.opRecommend,
    required this.recommendInfo,
    required this.subscribedCount,
    required this.cloudTrackCount,
    required this.userId,
    required this.totalDuration,
    required this.coverImgId,
    required this.privacy,
    required this.trackUpdateTime,
    required this.trackCount,
    required this.updateTime,
    required this.commentThreadId,
    required this.coverImgUrl,
    required this.specialType,
    required this.anonimous,
    required this.createTime,
    required this.highQuality,
    required this.newImported,
    required this.trackNumberUpdateTime,
    required this.playCount,
    required this.adType,
    required this.description,
    required this.tags,
    required this.ordered,
    required this.status,
    required this.name,
    required this.id,
    required this.coverImgIdStr,
    required this.sharedUsers,
    required this.shareStatus,
    required this.copied,
  });

  Playlist copyWith({
    List<dynamic>? subscribers,
    bool? subscribed,
    Creator? creator,
    dynamic artists,
    dynamic tracks,
    bool? top,
    dynamic updateFrequency,
    int? backgroundCoverId,
    dynamic backgroundCoverUrl,
    int? titleImage,
    dynamic titleImageUrl,
    dynamic englishTitle,
    bool? opRecommend,
    dynamic recommendInfo,
    int? subscribedCount,
    int? cloudTrackCount,
    int? userId,
    int? totalDuration,
    double? coverImgId,
    int? privacy,
    int? trackUpdateTime,
    int? trackCount,
    int? updateTime,
    String? commentThreadId,
    String? coverImgUrl,
    int? specialType,
    bool? anonimous,
    int? createTime,
    bool? highQuality,
    bool? newImported,
    int? trackNumberUpdateTime,
    int? playCount,
    int? adType,
    String? description,
    List<dynamic>? tags,
    bool? ordered,
    int? status,
    String? name,
    int? id,
    String? coverImgIdStr,
    dynamic sharedUsers,
    dynamic shareStatus,
    bool? copied,
  }) =>
      Playlist(
        subscribers: subscribers ?? this.subscribers,
        subscribed: subscribed ?? this.subscribed,
        creator: creator ?? this.creator,
        artists: artists ?? this.artists,
        tracks: tracks ?? this.tracks,
        top: top ?? this.top,
        updateFrequency: updateFrequency ?? this.updateFrequency,
        backgroundCoverId: backgroundCoverId ?? this.backgroundCoverId,
        backgroundCoverUrl: backgroundCoverUrl ?? this.backgroundCoverUrl,
        titleImage: titleImage ?? this.titleImage,
        titleImageUrl: titleImageUrl ?? this.titleImageUrl,
        englishTitle: englishTitle ?? this.englishTitle,
        opRecommend: opRecommend ?? this.opRecommend,
        recommendInfo: recommendInfo ?? this.recommendInfo,
        subscribedCount: subscribedCount ?? this.subscribedCount,
        cloudTrackCount: cloudTrackCount ?? this.cloudTrackCount,
        userId: userId ?? this.userId,
        totalDuration: totalDuration ?? this.totalDuration,
        coverImgId: coverImgId ?? this.coverImgId,
        privacy: privacy ?? this.privacy,
        trackUpdateTime: trackUpdateTime ?? this.trackUpdateTime,
        trackCount: trackCount ?? this.trackCount,
        updateTime: updateTime ?? this.updateTime,
        commentThreadId: commentThreadId ?? this.commentThreadId,
        coverImgUrl: coverImgUrl ?? this.coverImgUrl,
        specialType: specialType ?? this.specialType,
        anonimous: anonimous ?? this.anonimous,
        createTime: createTime ?? this.createTime,
        highQuality: highQuality ?? this.highQuality,
        newImported: newImported ?? this.newImported,
        trackNumberUpdateTime: trackNumberUpdateTime ?? this.trackNumberUpdateTime,
        playCount: playCount ?? this.playCount,
        adType: adType ?? this.adType,
        description: description ?? this.description,
        tags: tags ?? this.tags,
        ordered: ordered ?? this.ordered,
        status: status ?? this.status,
        name: name ?? this.name,
        id: id ?? this.id,
        coverImgIdStr: coverImgIdStr ?? this.coverImgIdStr,
        sharedUsers: sharedUsers ?? this.sharedUsers,
        shareStatus: shareStatus ?? this.shareStatus,
        copied: copied ?? this.copied,
      );

  factory Playlist.fromRawJson(String str) => Playlist.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Playlist.fromJson(Map<String, dynamic> json) => Playlist(
        subscribers: List<dynamic>.from(json["subscribers"].map((x) => x)),
        subscribed: json["subscribed"],
        creator: Creator.fromJson(json["creator"]),
        artists: json["artists"],
        tracks: json["tracks"],
        top: json["top"],
        updateFrequency: json["updateFrequency"],
        backgroundCoverId: json["backgroundCoverId"],
        backgroundCoverUrl: json["backgroundCoverUrl"],
        titleImage: json["titleImage"],
        titleImageUrl: json["titleImageUrl"],
        englishTitle: json["englishTitle"],
        opRecommend: json["opRecommend"],
        recommendInfo: json["recommendInfo"],
        subscribedCount: json["subscribedCount"],
        cloudTrackCount: json["cloudTrackCount"],
        userId: json["userId"],
        totalDuration: json["totalDuration"],
        coverImgId: json["coverImgId"]?.toDouble(),
        privacy: json["privacy"],
        trackUpdateTime: json["trackUpdateTime"],
        trackCount: json["trackCount"],
        updateTime: json["updateTime"],
        commentThreadId: json["commentThreadId"],
        coverImgUrl: json["coverImgUrl"],
        specialType: json["specialType"],
        anonimous: json["anonimous"],
        createTime: json["createTime"],
        highQuality: json["highQuality"],
        newImported: json["newImported"],
        trackNumberUpdateTime: json["trackNumberUpdateTime"],
        playCount: json["playCount"],
        adType: json["adType"],
        description: json["description"],
        tags: List<dynamic>.from(json["tags"].map((x) => x)),
        ordered: json["ordered"],
        status: json["status"],
        name: json["name"],
        id: json["id"],
        coverImgIdStr: json["coverImgId_str"],
        sharedUsers: json["sharedUsers"],
        shareStatus: json["shareStatus"],
        copied: json["copied"],
      );

  Map<String, dynamic> toJson() => {
        "subscribers": List<dynamic>.from(subscribers.map((x) => x)),
        "subscribed": subscribed,
        "creator": creator.toJson(),
        "artists": artists,
        "tracks": tracks,
        "top": top,
        "updateFrequency": updateFrequency,
        "backgroundCoverId": backgroundCoverId,
        "backgroundCoverUrl": backgroundCoverUrl,
        "titleImage": titleImage,
        "titleImageUrl": titleImageUrl,
        "englishTitle": englishTitle,
        "opRecommend": opRecommend,
        "recommendInfo": recommendInfo,
        "subscribedCount": subscribedCount,
        "cloudTrackCount": cloudTrackCount,
        "userId": userId,
        "totalDuration": totalDuration,
        "coverImgId": coverImgId,
        "privacy": privacy,
        "trackUpdateTime": trackUpdateTime,
        "trackCount": trackCount,
        "updateTime": updateTime,
        "commentThreadId": commentThreadId,
        "coverImgUrl": coverImgUrl,
        "specialType": specialType,
        "anonimous": anonimous,
        "createTime": createTime,
        "highQuality": highQuality,
        "newImported": newImported,
        "trackNumberUpdateTime": trackNumberUpdateTime,
        "playCount": playCount,
        "adType": adType,
        "description": description,
        "tags": List<dynamic>.from(tags.map((x) => x)),
        "ordered": ordered,
        "status": status,
        "name": name,
        "id": id,
        "coverImgId_str": coverImgIdStr,
        "sharedUsers": sharedUsers,
        "shareStatus": shareStatus,
        "copied": copied,
      };
}

class Creator {
  final bool defaultAvatar;
  final int province;
  final int authStatus;
  final bool followed;
  final String avatarUrl;
  final int accountStatus;
  final int gender;
  final int city;
  final int birthday;
  final int userId;
  final int userType;
  final String nickname;
  final String signature;
  final String description;
  final String detailDescription;
  final double avatarImgId;
  final int backgroundImgId;
  final String backgroundUrl;
  final int authority;
  final bool mutual;
  final dynamic expertTags;
  final dynamic experts;
  final int djStatus;
  final int vipType;
  final dynamic remarkName;
  final int authenticationTypes;
  final dynamic avatarDetail;
  final String avatarImgIdStr;
  final String backgroundImgIdStr;
  final bool anchor;
  final String creatorAvatarImgIdStr;

  Creator({
    required this.defaultAvatar,
    required this.province,
    required this.authStatus,
    required this.followed,
    required this.avatarUrl,
    required this.accountStatus,
    required this.gender,
    required this.city,
    required this.birthday,
    required this.userId,
    required this.userType,
    required this.nickname,
    required this.signature,
    required this.description,
    required this.detailDescription,
    required this.avatarImgId,
    required this.backgroundImgId,
    required this.backgroundUrl,
    required this.authority,
    required this.mutual,
    required this.expertTags,
    required this.experts,
    required this.djStatus,
    required this.vipType,
    required this.remarkName,
    required this.authenticationTypes,
    required this.avatarDetail,
    required this.avatarImgIdStr,
    required this.backgroundImgIdStr,
    required this.anchor,
    required this.creatorAvatarImgIdStr,
  });

  Creator copyWith({
    bool? defaultAvatar,
    int? province,
    int? authStatus,
    bool? followed,
    String? avatarUrl,
    int? accountStatus,
    int? gender,
    int? city,
    int? birthday,
    int? userId,
    int? userType,
    String? nickname,
    String? signature,
    String? description,
    String? detailDescription,
    double? avatarImgId,
    int? backgroundImgId,
    String? backgroundUrl,
    int? authority,
    bool? mutual,
    dynamic expertTags,
    dynamic experts,
    int? djStatus,
    int? vipType,
    dynamic remarkName,
    int? authenticationTypes,
    dynamic avatarDetail,
    String? avatarImgIdStr,
    String? backgroundImgIdStr,
    bool? anchor,
    String? creatorAvatarImgIdStr,
  }) =>
      Creator(
        defaultAvatar: defaultAvatar ?? this.defaultAvatar,
        province: province ?? this.province,
        authStatus: authStatus ?? this.authStatus,
        followed: followed ?? this.followed,
        avatarUrl: avatarUrl ?? this.avatarUrl,
        accountStatus: accountStatus ?? this.accountStatus,
        gender: gender ?? this.gender,
        city: city ?? this.city,
        birthday: birthday ?? this.birthday,
        userId: userId ?? this.userId,
        userType: userType ?? this.userType,
        nickname: nickname ?? this.nickname,
        signature: signature ?? this.signature,
        description: description ?? this.description,
        detailDescription: detailDescription ?? this.detailDescription,
        avatarImgId: avatarImgId ?? this.avatarImgId,
        backgroundImgId: backgroundImgId ?? this.backgroundImgId,
        backgroundUrl: backgroundUrl ?? this.backgroundUrl,
        authority: authority ?? this.authority,
        mutual: mutual ?? this.mutual,
        expertTags: expertTags ?? this.expertTags,
        experts: experts ?? this.experts,
        djStatus: djStatus ?? this.djStatus,
        vipType: vipType ?? this.vipType,
        remarkName: remarkName ?? this.remarkName,
        authenticationTypes: authenticationTypes ?? this.authenticationTypes,
        avatarDetail: avatarDetail ?? this.avatarDetail,
        avatarImgIdStr: avatarImgIdStr ?? this.avatarImgIdStr,
        backgroundImgIdStr: backgroundImgIdStr ?? this.backgroundImgIdStr,
        anchor: anchor ?? this.anchor,
        creatorAvatarImgIdStr: creatorAvatarImgIdStr ?? this.creatorAvatarImgIdStr,
      );

  factory Creator.fromRawJson(String str) => Creator.fromJson(json.decode(str));

  String toRawJson() => json.encode(toJson());

  factory Creator.fromJson(Map<String, dynamic> json) => Creator(
        defaultAvatar: json["defaultAvatar"],
        province: json["province"],
        authStatus: json["authStatus"],
        followed: json["followed"],
        avatarUrl: json["avatarUrl"],
        accountStatus: json["accountStatus"],
        gender: json["gender"],
        city: json["city"],
        birthday: json["birthday"],
        userId: json["userId"],
        userType: json["userType"],
        nickname: json["nickname"],
        signature: json["signature"],
        description: json["description"],
        detailDescription: json["detailDescription"],
        avatarImgId: json["avatarImgId"]?.toDouble(),
        backgroundImgId: json["backgroundImgId"],
        backgroundUrl: json["backgroundUrl"],
        authority: json["authority"],
        mutual: json["mutual"],
        expertTags: json["expertTags"],
        experts: json["experts"],
        djStatus: json["djStatus"],
        vipType: json["vipType"],
        remarkName: json["remarkName"],
        authenticationTypes: json["authenticationTypes"],
        avatarDetail: json["avatarDetail"],
        avatarImgIdStr: json["avatarImgIdStr"],
        backgroundImgIdStr: json["backgroundImgIdStr"],
        anchor: json["anchor"],
        creatorAvatarImgIdStr: json["avatarImgId_str"],
      );

  Map<String, dynamic> toJson() => {
        "defaultAvatar": defaultAvatar,
        "province": province,
        "authStatus": authStatus,
        "followed": followed,
        "avatarUrl": avatarUrl,
        "accountStatus": accountStatus,
        "gender": gender,
        "city": city,
        "birthday": birthday,
        "userId": userId,
        "userType": userType,
        "nickname": nickname,
        "signature": signature,
        "description": description,
        "detailDescription": detailDescription,
        "avatarImgId": avatarImgId,
        "backgroundImgId": backgroundImgId,
        "backgroundUrl": backgroundUrl,
        "authority": authority,
        "mutual": mutual,
        "expertTags": expertTags,
        "experts": experts,
        "djStatus": djStatus,
        "vipType": vipType,
        "remarkName": remarkName,
        "authenticationTypes": authenticationTypes,
        "avatarDetail": avatarDetail,
        "avatarImgIdStr": avatarImgIdStr,
        "backgroundImgIdStr": backgroundImgIdStr,
        "anchor": anchor,
        "avatarImgId_str": creatorAvatarImgIdStr,
      };
}
